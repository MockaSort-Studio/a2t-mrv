defmodule Livedata.Auth.Cognito do
  @moduledoc """
  Authenticates users against Cognito via USER_PASSWORD_AUTH (InitiateAuth API),
  validates the returned ID token against Cognito's JWKS endpoint, and handles
  REFRESH_TOKEN_AUTH for silent session renewal.

  @req: KR 8.3
  """

  @behaviour Livedata.Auth.CognitoBehaviour

  alias Livedata.Auth.Secrets

  @jwks_cache_key :cognito_jwks_cache
  @ex_aws_client Application.compile_env(:livedata, :ex_aws_client, ExAws)
  @compile {:no_warn_undefined, {Livedata.MockExAws, :request, 1}}

  @impl true
  def authenticate(username, password) do
    with {:ok, creds} <- Secrets.client_credentials(),
         secret_hash = compute_secret_hash(username, creds.client_id, creds.client_secret),
         {:ok, result} <- initiate_auth(creds.client_id, username, password, secret_hash),
         auth_result = result["AuthenticationResult"],
         {:ok, claims} <- validate_id_token(auth_result["IdToken"]) do
      {:ok, build_user(claims, auth_result["RefreshToken"])}
    end
  end

  @impl true
  def refresh_token(username, refresh_token) do
    with {:ok, creds} <- Secrets.client_credentials(),
         secret_hash = compute_secret_hash(username, creds.client_id, creds.client_secret),
         {:ok, result} <- initiate_refresh(creds.client_id, refresh_token, secret_hash),
         auth_result = result["AuthenticationResult"],
         {:ok, claims} <- validate_id_token(auth_result["IdToken"]) do
      new_refresh = auth_result["RefreshToken"] || refresh_token
      {:ok, build_user(claims, new_refresh)}
    end
  end

  defp initiate_auth(client_id, username, password, secret_hash) do
    body = %{
      "AuthFlow" => "USER_PASSWORD_AUTH",
      "ClientId" => client_id,
      "AuthParameters" => %{
        "USERNAME" => username,
        "PASSWORD" => password,
        "SECRET_HASH" => secret_hash
      }
    }

    post_cognito("AmazonCognitoIdentityProvider.InitiateAuth", body)
  end

  defp initiate_refresh(client_id, refresh_token, secret_hash) do
    body = %{
      "AuthFlow" => "REFRESH_TOKEN_AUTH",
      "ClientId" => client_id,
      "AuthParameters" => %{
        "REFRESH_TOKEN" => refresh_token,
        "SECRET_HASH" => secret_hash
      }
    }

    post_cognito("AmazonCognitoIdentityProvider.InitiateAuth", body)
  end

  defp post_cognito(target, body) do
    operation = %ExAws.Operation.JSON{
      http_method: :post,
      service: :cognito_idp,
      headers: [
        {"content-type", "application/x-amz-json-1.1"},
        {"x-amz-target", target}
      ],
      data: body,
      path: "/"
    }

    case @ex_aws_client.request(operation) do
      {:ok, result} ->
        {:ok, result}

      {:error, {:http_error, _status, %{"__type" => type, "message" => msg}}} ->
        {:error, {type, msg}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compute_secret_hash(username, client_id, client_secret) do
    :crypto.mac(:hmac, :sha256, client_secret, username <> client_id)
    |> Base.encode64()
  end

  defp validate_id_token(token) do
    with {:ok, %{"kid" => kid, "alg" => alg}} <- Joken.peek_header(token),
         {:ok, jwks} <- fetch_jwks(),
         {:ok, jwk} <- find_jwk(jwks, kid),
         signer = Joken.Signer.create(alg, %{"pem" => jwk_to_pem(jwk)}),
         {:ok, claims} <- Joken.verify_and_validate(%{}, token, signer) do
      {:ok, claims}
    else
      {:error, reason} -> {:error, {:jwt_invalid, reason}}
      :error -> {:error, :jwt_invalid}
    end
  end

  defp fetch_jwks do
    case Application.get_env(:livedata, @jwks_cache_key) do
      nil -> fetch_and_cache_jwks()
      cached -> {:ok, cached}
    end
  end

  defp fetch_and_cache_jwks do
    with {:ok, issuer_url} <- Application.fetch_env(:livedata, :cognito_issuer_url),
         jwks_url = "#{issuer_url}/.well-known/jwks.json",
         {:ok, %{status: 200, body: %{"keys" => keys}}} <- Req.get(jwks_url) do
      Application.put_env(:livedata, @jwks_cache_key, keys)
      {:ok, keys}
    else
      :error -> {:error, :cognito_not_configured}
      {:ok, %{status: status}} -> {:error, {:jwks_fetch_failed, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_jwk(keys, kid) do
    case Enum.find(keys, fn k -> k["kid"] == kid end) do
      nil -> {:error, {:unknown_kid, kid}}
      jwk -> {:ok, jwk}
    end
  end

  defp jwk_to_pem(jwk_map) do
    {_type, pem} =
      jwk_map
      |> JOSE.JWK.from_map()
      |> JOSE.JWK.to_pem()

    pem
  end

  defp build_user(claims, refresh_token) do
    %{
      "sub" => claims["sub"],
      "email" => claims["email"],
      "name" => claims["name"] || claims["cognito:username"] || claims["email"],
      "cognito_username" => claims["cognito:username"] || claims["sub"],
      "exp" => claims["exp"],
      "refresh_token" => refresh_token
    }
  end
end
