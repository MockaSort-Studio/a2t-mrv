defmodule Livedata.Auth.CognitoUserManagement do
  @moduledoc """
  Manages Cognito user pool users via the admin API (IAM/SigV4 authenticated).

  Uses ExAws for request signing. Requires AWS credentials with
  `cognito-idp:InitiateAuth`, `RespondToAuthChallenge`, `ListUsers`,
  `AdminCreateUser`, `AdminDeleteUser`, `AdminConfirmSignUp`, `AdminDisableUser`,
  `AdminEnableUser`, `AdminUserGlobalSignOut`, `AdminSetUserPassword`,
  `AdminAddUserToGroup`, `AdminRemoveUserFromGroup`, and `ListUsersInGroup`
  permissions on the pool.
  """

  @behaviour Livedata.Auth.UserManagementBehaviour

  alias Livedata.Auth.Secrets

  @admin_group "admins"
  @user_group "users"

  @impl true
  def list_users do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config(),
         {:ok, users} <- fetch_users(pool_id),
         {:ok, admins} <- fetch_admin_usernames(pool_id) do
      admin_set = MapSet.new(admins)

      result =
        Enum.map(users, fn u ->
          %{
            username: u["Username"],
            email: attr(u, "email"),
            status: u["UserStatus"],
            enabled: u["Enabled"],
            is_admin: MapSet.member?(admin_set, u["Username"])
          }
        end)

      {:ok, result}
    end
  end

  @impl true
  def add_user(email, temporary_password) do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config(),
         :ok <-
           call("AdminCreateUser", %{
             "UserPoolId" => pool_id,
             "Username" => email,
             "TemporaryPassword" => temporary_password,
             "UserAttributes" => [%{"Name" => "email", "Value" => email}],
             "MessageAction" => "SUPPRESS"
           })
           |> to_ok() do
      call("AdminAddUserToGroup", %{
        "UserPoolId" => pool_id,
        "Username" => email,
        "GroupName" => @user_group
      })

      :ok
    end
  end

  @impl true
  def delete_user(username) do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config() do
      # Sign out before deleting — AdminUserGlobalSignOut fails on a non-existent user.
      call("AdminUserGlobalSignOut", %{"UserPoolId" => pool_id, "Username" => username})

      call("AdminDeleteUser", %{"UserPoolId" => pool_id, "Username" => username})
      |> to_ok()
    end
  end

  @impl true
  def confirm_user(username) do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config() do
      call("AdminConfirmSignUp", %{"UserPoolId" => pool_id, "Username" => username})
      |> to_ok()
    end
  end

  @impl true
  def revoke_user(username) do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config(),
         :ok <-
           call("AdminDisableUser", %{"UserPoolId" => pool_id, "Username" => username})
           |> to_ok() do
      # Best-effort — invalidates all refresh tokens so existing sessions cannot renew.
      # Ignore failure: the user is already disabled.
      call("AdminUserGlobalSignOut", %{"UserPoolId" => pool_id, "Username" => username})
      :ok
    end
  end

  @impl true
  def reinstate_user(username) do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config() do
      call("AdminEnableUser", %{"UserPoolId" => pool_id, "Username" => username})
      |> to_ok()
    end
  end

  @impl true
  def force_password_change(username, temporary_password) do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config() do
      call("AdminSetUserPassword", %{
        "UserPoolId" => pool_id,
        "Username" => username,
        "Password" => temporary_password,
        "Permanent" => false
      })
      |> to_ok()
    end
  end

  @impl true
  def set_admin(username, true) do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config() do
      call("AdminAddUserToGroup", %{
        "UserPoolId" => pool_id,
        "Username" => username,
        "GroupName" => @admin_group
      })
      |> to_ok()
    end
  end

  def set_admin(username, false) do
    with {:ok, %{user_pool_id: pool_id}} <- Secrets.cognito_pool_config() do
      call("AdminRemoveUserFromGroup", %{
        "UserPoolId" => pool_id,
        "Username" => username,
        "GroupName" => @admin_group
      })
      |> to_ok()
    end
  end

  defp fetch_users(pool_id) do
    case call("ListUsers", %{"UserPoolId" => pool_id, "Limit" => 60}) do
      {:ok, %{"Users" => users}} -> {:ok, users}
      {:ok, _} -> {:ok, []}
      err -> err
    end
  end

  defp fetch_admin_usernames(pool_id) do
    case call("ListUsersInGroup", %{
           "UserPoolId" => pool_id,
           "GroupName" => @admin_group,
           "Limit" => 60
         }) do
      {:ok, %{"Users" => users}} -> {:ok, Enum.map(users, & &1["Username"])}
      {:ok, _} -> {:ok, []}
      # Group may not exist yet — treat as empty
      {:error, {"ResourceNotFoundException", _}} -> {:ok, []}
      err -> err
    end
  end

  defp call(operation, data) do
    %ExAws.Operation.JSON{
      http_method: :post,
      service: :"cognito-idp",
      headers: [
        {"content-type", "application/x-amz-json-1.1"},
        {"x-amz-target", "AWSCognitoIdentityProviderService.#{operation}"}
      ],
      data: data,
      path: "/"
    }
    |> ExAws.request()
  end

  defp to_ok({:ok, _}), do: :ok
  defp to_ok({:error, _} = err), do: err

  defp attr(user, name) do
    user
    |> Map.get("Attributes", [])
    |> Enum.find_value("", fn %{"Name" => n, "Value" => v} -> n == name && v end)
  end
end
