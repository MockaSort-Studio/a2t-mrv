defmodule Livedata.Auth.UserManagementBehaviour do
  @moduledoc """
  Behaviour for Cognito user pool management operations.

  Backends: `Livedata.Auth.CognitoUserManagement` (production) and
  `Livedata.Auth.CognitoMockUserManagement` (dev/test). Callers use
  `Livedata.Auth.UserManagementProvider` and never reference a backend directly.
  """

  @type user :: %{
          username: String.t(),
          email: String.t(),
          status: String.t(),
          enabled: boolean(),
          is_admin: boolean()
        }

  @callback list_users() :: {:ok, [user()]} | {:error, term()}
  @callback add_user(email :: String.t(), temporary_password :: String.t()) ::
              :ok | {:error, term()}
  @callback delete_user(username :: String.t()) :: :ok | {:error, term()}
  @callback confirm_user(username :: String.t()) :: :ok | {:error, term()}
  @callback revoke_user(username :: String.t()) :: :ok | {:error, term()}
  @callback reinstate_user(username :: String.t()) :: :ok | {:error, term()}
  @callback force_password_change(username :: String.t(), temporary_password :: String.t()) ::
              :ok | {:error, term()}
  @callback set_admin(username :: String.t(), is_admin :: boolean()) :: :ok | {:error, term()}
end
