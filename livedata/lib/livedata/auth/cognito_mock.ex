defmodule Livedata.Auth.CognitoMock do
  @moduledoc """
  Offline Cognito implementation for dev, test, and Render preview environments.

  The bypass password authenticates any user as admin, skipping all challenges.

  For users in FORCE_CHANGE_PASSWORD state any non-bypass password triggers the
  NEW_PASSWORD_REQUIRED challenge — mirroring real Cognito where the user's
  current password is accepted and the challenge is returned.

  For users created via CognitoMockUserManagement with a temp password, only
  the stored temp password triggers the challenge (new-invite flow).

  @req: KR 8.3
  """

  @behaviour Livedata.Auth.ProviderBehaviour

  alias Livedata.Auth.CognitoMockUserManagement

  @impl true
  def authenticate(username, password) do
    expected = Application.get_env(:livedata, :auth_bypass_password)

    with :ok <- check_enabled(username) do
      cond do
        is_nil(expected) ->
          {:error, :bypass_password_not_configured}

        password == expected ->
          # Bypass: fast dev path, but still honour FORCE_CHANGE_PASSWORD so the
          # reset flow can be tested without needing a second "real" password.
          case CognitoMockUserManagement.get_user_status(username) do
            {:ok, "FORCE_CHANGE_PASSWORD"} ->
              {:challenge, :new_password_required, %{username: username}}

            _ ->
              {:ok, synthetic_user(username, true)}
          end

        true ->
          check_temp_password(username, password)
      end
    end
  end

  defp check_enabled(username) do
    case CognitoMockUserManagement.get_enabled_status(username) do
      {:ok, false} -> {:error, :user_disabled}
      _ -> :ok
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
        # Invite flow: user presenting the exact stored temp password.
        {:challenge, :new_password_required, %{username: username}}

      {:ok, _other} ->
        # Temp password exists but doesn't match — wrong credentials.
        {:error, :invalid_credentials}

      {:error, :not_found} ->
        # No stored temp password — check if an admin forced a reset.
        # Accept any non-empty password to simulate Cognito accepting the
        # user's current (unknown to the mock) password.
        case CognitoMockUserManagement.get_user_status(username) do
          {:ok, "FORCE_CHANGE_PASSWORD"} when byte_size(password) > 0 ->
            {:challenge, :new_password_required, %{username: username}}

          _ ->
            {:error, :invalid_credentials}
        end
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
