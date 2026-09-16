defmodule Livedata.Auth.CognitoMockUserManagement do
  @moduledoc """
  In-memory user management backend for dev and test.

  Backed by an Agent so mutations (add, delete, confirm, set_admin) are visible
  within the same runtime session. The Agent is started in the application
  supervision tree when this module is the configured backend.
  """

  @behaviour Livedata.Auth.UserManagementBehaviour

  use Agent

  @initial_users [
    %{
      username: "admin@example.com",
      email: "admin@example.com",
      status: "CONFIRMED",
      enabled: true,
      is_admin: true,
      temp_password: nil
    },
    %{
      username: "user@example.com",
      email: "user@example.com",
      status: "CONFIRMED",
      enabled: true,
      is_admin: false,
      temp_password: nil
    },
    %{
      username: "pending@example.com",
      email: "pending@example.com",
      status: "UNCONFIRMED",
      enabled: true,
      is_admin: false,
      temp_password: nil
    }
  ]

  def start_link(_opts) do
    Agent.start_link(fn -> @initial_users end, name: __MODULE__)
  end

  @impl true
  def list_users do
    users =
      __MODULE__
      |> Agent.get(& &1)
      |> Enum.map(&Map.drop(&1, [:temp_password]))

    {:ok, users}
  end

  @impl true
  def add_user(email, temporary_password) do
    user = %{
      username: email,
      email: email,
      status: "FORCE_CHANGE_PASSWORD",
      enabled: true,
      is_admin: false,
      temp_password: temporary_password
    }

    result =
      Agent.get_and_update(__MODULE__, fn users ->
        if Enum.any?(users, &(&1.username == email)),
          do: {:duplicate, users},
          else: {:ok, users ++ [user]}
      end)

    case result do
      :ok -> :ok
      :duplicate -> {:error, {"UsernameExistsException", "User account already exists"}}
    end
  end

  @impl true
  def delete_user(username) do
    Agent.update(__MODULE__, fn users -> Enum.reject(users, &(&1.username == username)) end)
    :ok
  end

  @impl true
  def confirm_user(username) do
    Agent.update(__MODULE__, fn users ->
      Enum.map(users, fn u ->
        if u.username == username,
          do: %{u | status: "CONFIRMED", enabled: true, temp_password: nil},
          else: u
      end)
    end)

    :ok
  end

  @impl true
  def revoke_user(username) do
    Agent.update(__MODULE__, fn users ->
      Enum.map(users, fn u ->
        if u.username == username, do: %{u | enabled: false}, else: u
      end)
    end)

    :ok
  end

  @impl true
  def reinstate_user(username) do
    Agent.update(__MODULE__, fn users ->
      Enum.map(users, fn u ->
        if u.username == username, do: %{u | enabled: true}, else: u
      end)
    end)

    :ok
  end

  @impl true
  def force_password_change(username, temporary_password) do
    Agent.update(__MODULE__, fn users ->
      Enum.map(users, fn u ->
        if u.username == username,
          do: %{u | status: "FORCE_CHANGE_PASSWORD", temp_password: temporary_password},
          else: u
      end)
    end)

    :ok
  end

  @impl true
  def set_admin(username, is_admin) do
    Agent.update(__MODULE__, fn users ->
      Enum.map(users, fn u ->
        if u.username == username, do: %{u | is_admin: is_admin}, else: u
      end)
    end)

    :ok
  end

  @doc "Returns the stored temporary password for a FORCE_CHANGE_PASSWORD user."
  @spec get_temp_password(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_temp_password(username) do
    case Agent.get(__MODULE__, fn users -> Enum.find(users, &(&1.username == username)) end) do
      %{temp_password: pw} when is_binary(pw) -> {:ok, pw}
      _ -> {:error, :not_found}
    end
  end

  @doc "Returns whether the user account is enabled."
  @spec get_enabled_status(String.t()) :: {:ok, boolean()} | {:error, :not_found}
  def get_enabled_status(username) do
    case Agent.get(__MODULE__, fn users -> Enum.find(users, &(&1.username == username)) end) do
      %{enabled: enabled} -> {:ok, enabled}
      _ -> {:error, :not_found}
    end
  end

  @doc "Returns the user's Cognito status string."
  @spec get_user_status(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_user_status(username) do
    case Agent.get(__MODULE__, fn users -> Enum.find(users, &(&1.username == username)) end) do
      %{status: status} -> {:ok, status}
      _ -> {:error, :not_found}
    end
  end

  @doc "Returns whether the user is in the admin group."
  @spec get_admin_status(String.t()) :: {:ok, boolean()} | {:error, :not_found}
  def get_admin_status(username) do
    case Agent.get(__MODULE__, fn users -> Enum.find(users, &(&1.username == username)) end) do
      %{is_admin: is_admin} -> {:ok, is_admin}
      _ -> {:error, :not_found}
    end
  end
end
