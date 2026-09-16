defmodule Livedata.Auth.UserManagementProvider do
  @moduledoc """
  Entry point for user pool management operations.

  Delegates to the configured backend (`:user_management_provider` application
  config key). In production this is `CognitoUserManagement`; in dev/test it
  is `CognitoMockUserManagement`.
  """

  @spec list_users() :: {:ok, [map()]} | {:error, term()}
  def list_users, do: backend().list_users()

  @spec add_user(String.t(), String.t()) :: :ok | {:error, term()}
  def add_user(email, temporary_password), do: backend().add_user(email, temporary_password)

  @spec delete_user(String.t()) :: :ok | {:error, term()}
  def delete_user(username), do: backend().delete_user(username)

  @spec confirm_user(String.t()) :: :ok | {:error, term()}
  def confirm_user(username), do: backend().confirm_user(username)

  @spec revoke_user(String.t()) :: :ok | {:error, term()}
  def revoke_user(username), do: backend().revoke_user(username)

  @spec reinstate_user(String.t()) :: :ok | {:error, term()}
  def reinstate_user(username), do: backend().reinstate_user(username)

  @spec force_password_change(String.t(), String.t()) :: :ok | {:error, term()}
  def force_password_change(username, temporary_password),
    do: backend().force_password_change(username, temporary_password)

  @spec set_admin(String.t(), boolean()) :: :ok | {:error, term()}
  def set_admin(username, is_admin), do: backend().set_admin(username, is_admin)

  defp backend do
    Application.get_env(:livedata, :user_management_provider, Livedata.Auth.CognitoUserManagement)
  end
end
