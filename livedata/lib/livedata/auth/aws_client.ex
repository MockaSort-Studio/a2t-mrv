defmodule Livedata.Auth.AwsClient do
  @moduledoc """
  Builds an AWS.Client with resolved credentials and region.

  Credential chain: env vars (Render, CI) → EC2 IMDSv2 instance role.
  Region chain: AWS_DEFAULT_REGION / AWS_REGION env var → EC2 placement metadata.
  Both are cached in Application env with TTL so IMDSv2 is called at most once
  per credential rotation window.
  """

  @cred_cache_key :aws_credentials
  @region_cache_key :aws_region

  @spec build(String.t()) :: {:ok, AWS.Client.t()} | {:error, term()}
  def build(region) do
    with {:ok, creds} <- credentials() do
      {:ok,
       AWS.Client.create(
         creds.access_key_id,
         creds.secret_access_key,
         creds.session_token,
         region
       )}
    end
  end

  @spec default_region() :: {:ok, String.t()} | {:error, term()}
  def default_region do
    case Application.get_env(:livedata, @region_cache_key) do
      nil ->
        case System.get_env("AWS_DEFAULT_REGION") || System.get_env("AWS_REGION") do
          region when is_binary(region) ->
            Application.put_env(:livedata, @region_cache_key, region)
            {:ok, region}

          nil ->
            fetch_instance_region()
        end

      cached ->
        {:ok, cached}
    end
  end

  defp credentials do
    case Application.get_env(:livedata, @cred_cache_key) do
      %{expires_at: nil} = c ->
        {:ok, c}

      %{expires_at: exp} = c ->
        if DateTime.compare(DateTime.utc_now(), DateTime.add(exp, -300)) == :lt,
          do: {:ok, c},
          else: resolve_and_cache_credentials()

      _ ->
        resolve_and_cache_credentials()
    end
  end

  defp resolve_and_cache_credentials do
    case {System.get_env("AWS_ACCESS_KEY_ID"), System.get_env("AWS_SECRET_ACCESS_KEY")} do
      {key, secret} when is_binary(key) and is_binary(secret) ->
        {:ok,
         %{
           access_key_id: key,
           secret_access_key: secret,
           session_token: System.get_env("AWS_SESSION_TOKEN"),
           expires_at: nil
         }}

      _ ->
        fetch_instance_credentials()
    end
  end

  # IMDSv2: PUT /latest/api/token, then GET /iam/security-credentials/{role}
  defp fetch_instance_credentials do
    base = "http://169.254.169.254"

    with {:ok, %{body: token}} <-
           Req.put(base <> "/latest/api/token",
             headers: [{"x-aws-ec2-metadata-token-ttl-seconds", "21600"}],
             receive_timeout: 2000
           ),
         {:ok, %{body: role}} <-
           Req.get(base <> "/latest/meta-data/iam/security-credentials/",
             headers: [{"x-aws-ec2-metadata-token", String.trim(token)}],
             receive_timeout: 2000
           ),
         {:ok, %{body: raw}} <-
           Req.get(
             base <> "/latest/meta-data/iam/security-credentials/#{String.trim(role)}",
             headers: [{"x-aws-ec2-metadata-token", String.trim(token)}],
             receive_timeout: 2000
           ),
         {:ok, creds} <- if(is_map(raw), do: {:ok, raw}, else: Jason.decode(raw)),
         {:ok, expires_at, _} <- DateTime.from_iso8601(creds["Expiration"]) do
      result = %{
        access_key_id: creds["AccessKeyId"],
        secret_access_key: creds["SecretAccessKey"],
        session_token: creds["Token"],
        expires_at: expires_at
      }

      Application.put_env(:livedata, @cred_cache_key, result)
      {:ok, result}
    else
      err ->
        require Logger
        Logger.error("IMDSv2 credential fetch failed: #{inspect(err)}")
        {:error, :aws_credentials_unavailable}
    end
  end

  defp fetch_instance_region do
    base = "http://169.254.169.254"

    with {:ok, %{body: token}} <-
           Req.put(base <> "/latest/api/token",
             headers: [{"x-aws-ec2-metadata-token-ttl-seconds", "21600"}],
             receive_timeout: 2000
           ),
         {:ok, %{body: region}} <-
           Req.get(base <> "/latest/meta-data/placement/region",
             headers: [{"x-aws-ec2-metadata-token", String.trim(token)}],
             receive_timeout: 2000
           ) do
      region = String.trim(region)
      Application.put_env(:livedata, @region_cache_key, region)
      {:ok, region}
    else
      err ->
        require Logger
        Logger.error("IMDSv2 region fetch failed: #{inspect(err)}")
        {:error, :aws_region_unavailable}
    end
  end
end
