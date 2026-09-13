defmodule LivedataWeb.AuthController do
  use LivedataWeb, :controller

  alias Livedata.Auth

  @doc "Initiates the Cognito OIDC authorization_code flow."
  def new(conn, _params) do
    cognito = cognito_module()

    case cognito.authorize_url() do
      {:ok, url, session_params} ->
        conn
        |> put_session("cognito_session_params", session_params)
        |> redirect(external: url)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Authentication service unavailable. Please try again later.")
        |> redirect(to: ~p"/")
    end
  end

  @doc "Handles the Cognito callback: exchanges the code, stores the session."
  def callback(conn, params) do
    session_params = get_session(conn, "cognito_session_params") || %{}
    cognito = cognito_module()

    case cognito.exchange_code(params, session_params) do
      {:ok, user, _token} ->
        return_to = get_session(conn, "auth_return_to") || ~p"/"

        conn
        |> delete_session("cognito_session_params")
        |> delete_session("auth_return_to")
        |> Auth.put_session_user(user)
        |> redirect(to: return_to)

      {:error, _reason} ->
        conn
        |> delete_session("cognito_session_params")
        |> put_flash(:error, "Authentication failed. Please try signing in again.")
        |> redirect(to: ~p"/auth/cognito")
    end
  end

  @doc "Signs the user out and clears the session."
  def delete(conn, _params) do
    conn
    |> Auth.delete_session()
    |> redirect(to: ~p"/")
  end

  defp cognito_module do
    Application.get_env(:livedata, :cognito_module, Livedata.Auth.Cognito)
  end
end
