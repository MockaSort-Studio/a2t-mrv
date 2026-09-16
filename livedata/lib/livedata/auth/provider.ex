defmodule Livedata.Auth.Provider do
  @moduledoc """
  Entry point for all authentication operations.

  Delegates to the configured backend module (`:auth_provider` application
  config key). In production this is `Livedata.Auth.Cognito`; in dev/test
  it is `Livedata.Auth.CognitoMock`. Callers never reference Cognito directly.
  """

  def authenticate(username, password), do: backend().authenticate(username, password)

  def respond_new_password(username, new_password, challenge_data),
    do: backend().respond_new_password(username, new_password, challenge_data)

  def refresh_token(username, refresh_token), do: backend().refresh_token(username, refresh_token)

  defp backend do
    Application.get_env(:livedata, :auth_provider, Livedata.Auth.Cognito)
  end
end
