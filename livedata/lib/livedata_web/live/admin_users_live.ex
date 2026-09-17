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
    {:ok,
     socket
     |> assign(:page_title, "Admin · Users")
     |> assign(:adding_user, false)
     |> assign(:new_email, "")
     |> assign(:confirming_delete, nil)
     |> assign(:open_menu, nil)
     |> assign(:users_empty?, false)
     |> assign(:users_map, %{})
     |> reload_users()}
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
        {:noreply, socket |> assign(adding_user: false, new_email: "") |> reload_users()}

      {:error, reason} ->
        {:noreply, assign(socket, error: format_error(reason))}
    end
  end

  def handle_event("toggle_menu", %{"key" => key}, socket) do
    prev = socket.assigns.open_menu
    open = if prev == key, do: nil, else: key

    # Stream items don't re-render on assign changes alone — re-insert every
    # affected user so the :if={@open_menu == ...} inside the stream row is
    # re-evaluated with the new open_menu value.
    affected =
      [prev, open]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&(String.split(&1, ":") |> List.last()))
      |> Enum.uniq()

    socket =
      Enum.reduce(affected, assign(socket, :open_menu, open), fn username, acc ->
        case Map.get(acc.assigns.users_map, username) do
          nil -> acc
          user -> stream_insert(acc, :users, user)
        end
      end)

    {:noreply, socket}
  end

  def handle_event("confirm_user", %{"username" => username}, socket) do
    case UserManagementProvider.confirm_user(username) do
      :ok -> {:noreply, socket |> assign(open_menu: nil) |> reload_users()}
      {:error, reason} -> {:noreply, assign(socket, error: format_error(reason))}
    end
  end

  def handle_event("revoke_user", %{"username" => username}, socket) do
    case UserManagementProvider.revoke_user(username) do
      :ok -> {:noreply, socket |> assign(open_menu: nil) |> reload_users()}
      {:error, reason} -> {:noreply, assign(socket, error: format_error(reason))}
    end
  end

  def handle_event("reinstate_user", %{"username" => username}, socket) do
    case UserManagementProvider.reinstate_user(username) do
      :ok -> {:noreply, socket |> assign(open_menu: nil) |> reload_users()}
      {:error, reason} -> {:noreply, assign(socket, error: format_error(reason))}
    end
  end

  def handle_event("force_password_change", %{"username" => username}, socket) do
    case UserManagementProvider.force_password_change(username, @default_temp_password) do
      :ok -> {:noreply, socket |> assign(open_menu: nil) |> reload_users()}
      {:error, reason} -> {:noreply, assign(socket, error: format_error(reason))}
    end
  end

  def handle_event("toggle_admin", %{"username" => username, "is-admin" => is_admin_str}, socket) do
    is_admin = is_admin_str == "true"

    case UserManagementProvider.set_admin(username, !is_admin) do
      :ok -> {:noreply, socket |> assign(open_menu: nil) |> reload_users()}
      {:error, reason} -> {:noreply, assign(socket, error: format_error(reason))}
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
        {:noreply, socket |> assign(confirming_delete: nil) |> reload_users()}

      {:error, reason} ->
        {:noreply, assign(socket, confirming_delete: nil, error: format_error(reason))}
    end
  end

  defp reload_users(socket) do
    case UserManagementProvider.list_users() do
      {:ok, users} ->
        socket
        |> stream(:users, users, reset: true)
        |> assign(:users_map, Map.new(users, &{&1.username, &1}))
        |> assign(:users_empty?, users == [])
        |> assign(:error, nil)

      {:error, reason} ->
        socket
        |> stream(:users, [], reset: true)
        |> assign(:users_map, %{})
        |> assign(:users_empty?, true)
        |> assign(:error, "Could not load users: #{format_error(reason)}")
    end
  end

  defp format_error({type, msg}) when is_binary(type), do: msg
  defp format_error(reason), do: inspect(reason)

  defp effective_status(%{enabled: false}), do: "DISABLED"
  defp effective_status(%{status: status}), do: status

  defp status_class("CONFIRMED"), do: "bg-emerald-100 text-emerald-800"
  defp status_class("UNCONFIRMED"), do: "bg-amber-100 text-amber-800"
  defp status_class("FORCE_CHANGE_PASSWORD"), do: "bg-sky-100 text-sky-800"
  defp status_class("DISABLED"), do: "bg-red-100 text-red-700"
  defp status_class(_), do: "bg-zinc-100 text-zinc-600"

  defp status_label("FORCE_CHANGE_PASSWORD"), do: "Password reset"
  defp status_label("DISABLED"), do: "Disabled"

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

      <%!-- Users table — no overflow-x-auto so dropdowns can escape the container --%>
      <div class="rounded-lg border border-base-300">
        <table class="w-full text-sm select-none">
          <thead>
            <tr class="border-b border-base-300 text-left text-xs text-base-content/40">
              <th class="px-4 py-2 font-normal">Username</th>
              <th class="px-4 py-2 font-normal">Status</th>
              <th class="px-4 py-2 font-normal">Role</th>
              <th class="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody :if={@users_empty?}>
            <tr>
              <td colspan="4" class="px-4 py-8 text-center text-base-content/50">
                No users found.
              </td>
            </tr>
          </tbody>
          <tbody id="users-table" phx-update="stream" class="divide-y divide-base-200">
            <tr :for={{id, user} <- @streams.users} id={id} class="hover:bg-base-200/50">
              <%!-- Username --%>
              <td class="px-4 py-3 font-medium cursor-default">{user.email}</td>

              <%!-- Status — always clickable; options depend on current state --%>
              <td class="px-4 py-3">
                <div class="relative">
                  <button
                    id={"status-btn-#{user.username}"}
                    phx-click="toggle_menu"
                    phx-value-key={"status:#{user.username}"}
                    class={[
                      "inline-flex cursor-pointer items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium",
                      status_class(effective_status(user))
                    ]}
                  >
                    {status_label(effective_status(user))}
                    <.icon name="hero-chevron-down-micro" class="size-3" />
                  </button>
                  <div
                    :if={@open_menu == "status:#{user.username}"}
                    id={"status-menu-#{user.username}"}
                    class="absolute z-50 mt-1 w-48 rounded-lg border border-base-300 bg-base-100 py-1 shadow-md"
                  >
                    <%= case effective_status(user) do %>
                      <% "CONFIRMED" -> %>
                        <button
                          id={"force-pw-#{user.username}"}
                          phx-click="force_password_change"
                          phx-value-username={user.username}
                          class="flex w-full items-center gap-2.5 px-3 py-2 text-xs text-base-content/70 hover:bg-base-200 hover:text-base-content"
                        >
                          <span class="flex size-3.5 shrink-0 items-center justify-center rounded border border-base-300 bg-base-100" />
                          Password reset
                        </button>
                        <button
                          id={"revoke-#{user.username}"}
                          phx-click="revoke_user"
                          phx-value-username={user.username}
                          class="flex w-full items-center gap-2.5 px-3 py-2 text-xs text-red-600 hover:bg-red-50"
                        >
                          <span class="flex size-3.5 shrink-0 items-center justify-center rounded border border-red-200 bg-base-100" />
                          Disabled
                        </button>
                      <% "DISABLED" -> %>
                        <button
                          id={"reinstate-#{user.username}"}
                          phx-click="reinstate_user"
                          phx-value-username={user.username}
                          class="flex w-full items-center gap-2.5 px-3 py-2 text-xs text-base-content/70 hover:bg-base-200 hover:text-base-content"
                        >
                          <span class="flex size-3.5 shrink-0 items-center justify-center rounded border border-base-300 bg-base-100" />
                          Confirmed
                        </button>
                      <% "UNCONFIRMED" -> %>
                        <%!-- AdminConfirmSignUp is only valid for UNCONFIRMED --%>
                        <button
                          id={"confirm-#{user.username}"}
                          phx-click="confirm_user"
                          phx-value-username={user.username}
                          class="flex w-full items-center gap-2.5 px-3 py-2 text-xs text-base-content/70 hover:bg-base-200 hover:text-base-content"
                        >
                          <span class="flex size-3.5 shrink-0 items-center justify-center rounded border border-base-300 bg-base-100" />
                          Confirmed
                        </button>
                      <% "FORCE_CHANGE_PASSWORD" -> %>
                        <%!-- User must complete first login themselves; admin can only disable --%>
                        <button
                          id={"revoke-#{user.username}"}
                          phx-click="revoke_user"
                          phx-value-username={user.username}
                          class="flex w-full items-center gap-2.5 px-3 py-2 text-xs text-red-600 hover:bg-red-50"
                        >
                          <span class="flex size-3.5 shrink-0 items-center justify-center rounded border border-red-200 bg-base-100" />
                          Disabled
                        </button>
                      <% _ -> %>
                        <p class="px-3 py-2 text-xs text-base-content/40">No actions</p>
                    <% end %>
                  </div>
                </div>
              </td>

              <%!-- Role — always a clickable badge dropdown --%>
              <td class="px-4 py-3">
                <div class="relative">
                  <button
                    id={"role-btn-#{user.username}"}
                    phx-click="toggle_menu"
                    phx-value-key={"role:#{user.username}"}
                    class={[
                      "inline-flex cursor-pointer items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium",
                      if(user.is_admin,
                        do: "bg-violet-100 text-violet-800 hover:bg-violet-200",
                        else: "text-base-content/40 hover:bg-base-200 hover:text-base-content/70"
                      )
                    ]}
                  >
                    {if(user.is_admin, do: "Admin", else: "—")}
                    <.icon name="hero-chevron-down-micro" class="size-3" />
                  </button>
                  <div
                    :if={@open_menu == "role:#{user.username}"}
                    id={"role-menu-#{user.username}"}
                    class="absolute z-50 mt-1 w-40 rounded-lg border border-base-300 bg-base-100 py-1 shadow-md"
                  >
                    <button
                      id={"toggle-admin-#{user.username}"}
                      phx-click="toggle_admin"
                      phx-value-username={user.username}
                      phx-value-is-admin={if(user.is_admin, do: "true", else: "false")}
                      class="flex w-full items-center gap-2.5 px-3 py-2 text-xs text-base-content/70 hover:bg-base-200 hover:text-base-content"
                    >
                      <span class={[
                        "flex size-3.5 shrink-0 items-center justify-center rounded border",
                        if(user.is_admin,
                          do: "border-violet-600 bg-violet-600",
                          else: "border-base-300 bg-base-100"
                        )
                      ]}>
                        <.icon :if={user.is_admin} name="hero-check-micro" class="size-3 text-white" />
                      </span>
                      Admin
                    </button>
                  </div>
                </div>
              </td>

              <%!-- Actions — delete only --%>
              <td class="px-4 py-3">
                <div class="flex items-center justify-end gap-2">
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
