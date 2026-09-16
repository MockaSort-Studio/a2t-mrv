defmodule Livedata.Auth.CognitoMock do
  @moduledoc """
  Offline Cognito implementation for dev, test, and Render preview environments.

  The bypass password authenticates any user as admin. When a user was created
  via `CognitoMockUserManagement` with a temporary password, presenting that
  password returns a `NEW_PASSWORD_REQUIRED` challenge and the resulting session
  reflects the user's actual admin status from the agent.

  @req: KR 8.3
  """

  @behaviour Livedata.Auth.ProviderBehaviour

  alias Livedata.Auth.CognitoMockUserManagement

  @impl true
  def authenticate(username, password) do
    expected = Application.get_env(:livedata, :auth_bypass_password)

    cond do
      is_nil(expected) ->
        {:error, :bypass_password_not_configured}

      password == expected ->
        {:ok, synthetic_user(username, true)}

      true ->
        check_temp_password(username, password)
    end
  end

  @impl true
  def respond_new_password(username, _new_password, %{username: username}) do
    CognitoMockUserManagement.confirm_user(username)
    is_admin = agent_admin_status(username)
    {:ok, synthetic_user(username, is_admin)}
  end

  @impl true
  def refresh_token(_username, _refresh_token) do
    {:ok, synthetic_user("dev", true)}
  end

  defp check_temp_password(username, password) do
    case CognitoMockUserManagement.get_temp_password(username) do
      {:ok, ^password} ->
        {:challenge, :new_password_required, %{username: username}}

      _ ->
        {:error, :invalid_credentials}
    end
  end

  defp agent_admin_status(username) do
    case CognitoMockUserManagement.get_admin_status(username) do
      {:ok, val} -> val
      _ -> false
    end
  end

  defp synthetic_user(username, is_admin) do
    email = if String.contains?(username, "@"), do: username, else: "#{username}@mock.local"

    %{
      "sub" => "mock-sub-#{username}",
      "email" => email,
      "name" => username,
      "cognito_username" => username,
      "exp" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix(),
      "refresh_token" => "mock_refresh_token",
      "is_admin" => is_admin
    }
  end
end
