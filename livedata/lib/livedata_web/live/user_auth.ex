defmodule LivedataWeb.UserAuth do
  @moduledoc """
  LiveView on_mount hooks for Cognito-based authentication.

  Used in the router's `live_session :authenticated` block to gate all
  protected routes. Unauthenticated or expired sessions are redirected to
  the Cognito login initiation path.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]

  @user_key "cognito_user"

  @doc "Mounts hook: requires a valid, unexpired Cognito session to continue."
  def on_mount(:ensure_authenticated, _params, session, socket) do
    case Map.get(session, @user_key) do
      nil ->
        {:halt, redirect(socket, to: "/auth/cognito")}

      user when is_map(user) ->
        if token_expired?(user) do
          {:halt, redirect(socket, to: "/auth/cognito")}
        else
          {:cont, assign(socket, :current_user, user)}
        end
    end
  end

  defp token_expired?(%{"exp" => exp}) when is_integer(exp) do
    DateTime.utc_now() |> DateTime.to_unix() >= exp
  end

  defp token_expired?(_), do: true
end
