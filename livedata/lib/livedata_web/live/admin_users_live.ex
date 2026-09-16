defmodule LivedataWeb.AdminUsersLive do
  @moduledoc """
  Admin users management page.

  Lists Cognito user pool users with their confirmation status and admin role.
  Supports adding (invite by email), confirming, deleting, and toggling the
  admin role for each user.
  """
  use LivedataWeb, :live_view

  alias Livedata.Auth.UserManagementProvider

  @impl true
  def mount(_params, _session, socket) do
    {:ok, users} = UserManagementProvider.list_users()

    {:ok,
     socket
     |> assign(:page_title, "Admin · Users")
     |> assign(:users, users)
     |> assign(:adding_user, false)
     |> assign(:new_email, "")
     |> assign(:confirming_delete, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("show_add_form", _params, socket) do
    {:noreply, assign(socket, adding_user: true, new_email: "", error: nil)}
  end

  def handle_event("cancel_add", _params, socket) do
    {:noreply, assign(socket, adding_user: false, error: nil)}
  end

  # Temporary password until email delivery is wired up — communicated out of band.
  @default_temp_password "Changeme1234!"

  def handle_event("add_user", %{"email" => email}, socket) do
    email = String.trim(email)

    case UserManagementProvider.add_user(email, @default_temp_password) do
      :ok ->
        {:ok, users} = UserManagementProvider.list_users()
        {:noreply, assign(socket, users: users, adding_user: false, new_email: "", error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: format_error(reason))}
    end
  end

  def handle_event("confirm_user", %{"username" => username}, socket) do
    case UserManagementProvider.confirm_user(username) do
      :ok ->
        {:ok, users} = UserManagementProvider.list_users()
        {:noreply, assign(socket, users: users, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: format_error(reason))}
    end
  end

  def handle_event("toggle_admin", %{"username" => username, "is-admin" => is_admin_str}, socket) do
    is_admin = is_admin_str == "true"

    case UserManagementProvider.set_admin(username, !is_admin) do
      :ok ->
        {:ok, users} = UserManagementProvider.list_users()
        {:noreply, assign(socket, users: users, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: format_error(reason))}
    end
  end

  def handle_event("confirm_delete", %{"username" => username}, socket) do
    {:noreply, assign(socket, confirming_delete: username)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirming_delete: nil)}
  end

  def handle_event("delete_user", %{"username" => username}, socket) do
    case UserManagementProvider.delete_user(username) do
      :ok ->
        {:ok, users} = UserManagementProvider.list_users()
        {:noreply, assign(socket, users: users, confirming_delete: nil, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, confirming_delete: nil, error: format_error(reason))}
    end
  end

  defp format_error({type, msg}) when is_binary(type), do: msg
  defp format_error(reason), do: inspect(reason)

  defp status_class("CONFIRMED"), do: "bg-emerald-100 text-emerald-800"
  defp status_class("UNCONFIRMED"), do: "bg-amber-100 text-amber-800"
  defp status_class("FORCE_CHANGE_PASSWORD"), do: "bg-sky-100 text-sky-800"
  defp status_class(_), do: "bg-zinc-100 text-zinc-600"

  defp status_label("FORCE_CHANGE_PASSWORD"), do: "Pending password"

  defp status_label(s),
    do: s |> String.downcase() |> String.replace("_", " ") |> String.capitalize()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-4xl">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-semibold">Users</h1>
        <button
          :if={!@adding_user}
          id="btn-add-user"
          phx-click="show_add_form"
          class="rounded-md bg-zinc-900 px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
        >
          Add user
        </button>
      </div>

      <%!-- Add user form --%>
      <div
        :if={@adding_user}
        id="add-user-form"
        class="rounded-lg border border-base-300 bg-base-200/40 p-4"
      >
        <p class="mb-3 text-sm font-medium text-base-content/70">Add a new user</p>
        <form phx-submit="add_user" class="space-y-2">
          <div class="flex gap-2">
            <input
              id="new-user-email"
              type="email"
              name="email"
              value={@new_email}
              placeholder="user@example.com"
              required
              class="flex-1 rounded-md border border-base-300 bg-base-100 px-3 py-1.5 text-sm focus:border-base-content/40 focus:outline-none"
            />
            <button
              type="submit"
              class="rounded-md bg-base-content px-3 py-1.5 text-sm font-medium text-base-100 transition-opacity hover:opacity-80"
            >
              Add user
            </button>
            <button
              type="button"
              phx-click="cancel_add"
              class="rounded-md border border-base-300 px-3 py-1.5 text-sm text-base-content/70 transition-colors hover:bg-base-200"
            >
              Cancel
            </button>
          </div>
          <p class="text-xs text-base-content/40">
            A temporary password will be communicated out of band. User sets a permanent one on first login.
          </p>
        </form>
      </div>

      <%!-- Error banner --%>
      <div
        :if={@error}
        id="users-error"
        class="rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800"
      >
        {@error}
      </div>

      <%!-- Users table --%>
      <div class="overflow-x-auto rounded-lg border border-base-300">
        <table class="w-full text-sm select-none">
          <thead>
            <tr class="border-b border-base-300 text-left text-xs text-base-content/40">
              <th class="px-4 py-2 font-normal">Username</th>
              <th class="px-4 py-2 font-normal">Status</th>
              <th class="px-4 py-2 font-normal">Role</th>
              <th class="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody id="users-table" class="divide-y divide-base-200">
            <tr :if={@users == []}>
              <td colspan="4" class="px-4 py-8 text-center text-base-content/50">
                No users found.
              </td>
            </tr>
            <tr :for={user <- @users} id={"user-#{user.username}"} class="hover:bg-base-200/50">
              <td class="px-4 py-3 font-medium cursor-default">{user.email}</td>
              <td class="px-4 py-3">
                <span class={[
                  "rounded-full px-2 py-0.5 text-xs font-medium",
                  status_class(user.status)
                ]}>
                  {status_label(user.status)}
                </span>
              </td>
              <td class="px-4 py-3">
                <button
                  id={"toggle-admin-#{user.username}"}
                  phx-click="toggle_admin"
                  phx-value-username={user.username}
                  phx-value-is-admin={user.is_admin}
                  class="rounded-full px-2 py-0.5 text-xs font-medium transition-colors"
                >
                  <span
                    :if={user.is_admin}
                    class="rounded-full bg-violet-100 px-2 py-0.5 text-xs font-medium text-violet-800 hover:bg-violet-200"
                  >
                    Admin
                  </span>
                  <span :if={!user.is_admin} class="text-base-content/30 hover:text-base-content/60">
                    —
                  </span>
                </button>
              </td>
              <td class="px-4 py-3">
                <div class="flex items-center justify-end gap-2">
                  <button
                    :if={user.status == "UNCONFIRMED"}
                    id={"confirm-#{user.username}"}
                    phx-click="confirm_user"
                    phx-value-username={user.username}
                    class="text-xs text-emerald-700 hover:underline"
                  >
                    Confirm
                  </button>

                  <%= if @confirming_delete == user.username do %>
                    <span class="text-xs text-base-content/60">Delete?</span>
                    <button
                      id={"delete-confirm-#{user.username}"}
                      phx-click="delete_user"
                      phx-value-username={user.username}
                      class="text-xs font-medium text-red-600 hover:underline"
                    >
                      Yes
                    </button>
                    <button
                      phx-click="cancel_delete"
                      class="text-xs text-base-content/60 hover:underline"
                    >
                      No
                    </button>
                  <% else %>
                    <button
                      id={"delete-#{user.username}"}
                      phx-click="confirm_delete"
                      phx-value-username={user.username}
                      class="text-xs text-red-500 hover:underline"
                    >
                      Delete
                    </button>
                  <% end %>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
