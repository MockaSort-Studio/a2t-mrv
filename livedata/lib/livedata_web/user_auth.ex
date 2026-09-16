defmodule LivedataWeb.UserAuth do
  @moduledoc """
  LiveView on_mount guard and router plugs for session authentication.

  Protects live routes under the :authenticated live_session: unauthenticated
  mounts redirect to /login. Expired tokens trigger a silent REFRESH_TOKEN_AUTH
  attempt before forcing re-login.

  @req: KR 8.3
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Livedata.Auth
  alias Livedata.Auth.Provider
  alias Livedata.Auth.SessionBridge

  @doc """
  LiveView on_mount guards for route protection.

  - `:redirect_if_authenticated` — redirects already-authenticated users away from /login.
  - `:require_authenticated_user` — redirects unauthenticated or expired mounts to /login.
  - `:require_admin_user` — requires authenticated user AND admin role; redirects to / otherwise.
  """
  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    case Auth.get_session_user_from_session(session) do
      nil ->
        {:cont, socket}

      user ->
        if Auth.token_expired?(user),
          do: {:cont, socket},
          else: {:halt, Phoenix.LiveView.push_navigate(socket, to: "/")}
    end
  end

  def on_mount(:require_admin_user, params, session, socket) do
    case on_mount(:require_authenticated_user, params, session, socket) do
      {:cont, authed_socket} ->
        if authed_socket.assigns.current_user["is_admin"] do
          {:cont, authed_socket}
        else
          {:halt, Phoenix.LiveView.push_navigate(authed_socket, to: "/")}
        end

      halt ->
        halt
    end
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    case Auth.get_session_user_from_session(session) do
      nil ->
        {:halt, Phoenix.LiveView.push_navigate(socket, to: "/login")}

      user ->
        if Auth.token_expired?(user) do
          handle_expired(user, socket)
        else
          {:cont, Phoenix.Component.assign(socket, :current_user, user)}
        end
    end
  end

  defp handle_expired(%{"refresh_token" => rt} = user, socket) when is_binary(rt) do
    username = user["cognito_username"] || user["sub"] || ""

    case Provider.refresh_token(username, rt) do
      {:ok, new_user} ->
        token = SessionBridge.store(new_user)
        {:halt, Phoenix.LiveView.push_navigate(socket, to: "/auth/session/#{token}")}

      {:error, _} ->
        {:halt, Phoenix.LiveView.push_navigate(socket, to: "/login")}
    end
  end

  defp handle_expired(_, socket) do
    {:halt, Phoenix.LiveView.push_navigate(socket, to: "/login")}
  end

  @doc "Plug: redirects unauthenticated requests in non-live routes."
  def require_authenticated_user(conn, _opts) do
    if Auth.session_user_authenticated?(conn) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
