defmodule LivedataWeb.LoginLive do
  @moduledoc """
  Username/password login form. Authenticates via the configured auth provider
  and bridges the resulting user identity to the Plug session via the
  AuthController session bridge.

  When Cognito returns a NEW_PASSWORD_REQUIRED challenge (first login after an
  admin-created account), a second step collects and submits the new password.

  @req: KR 8.3
  """

  use LivedataWeb, :live_view

  alias Livedata.Auth.Provider
  alias Livedata.Auth.SessionBridge

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:return_to, Map.get(session, "auth_return_to", "/"))
     |> assign(:step, :login)
     |> assign(:challenge_data, nil)
     |> assign(:pending_username, nil)
     |> assign(:form, login_form())
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event(
        "submit",
        %{"login" => %{"username" => username, "password" => password}},
        socket
      ) do
    case Provider.authenticate(username, password) do
      {:ok, user} ->
        {:noreply, complete_login(socket, user)}

      {:challenge, :new_password_required, challenge_data} ->
        {:noreply,
         socket
         |> assign(:step, :new_password)
         |> assign(:challenge_data, challenge_data)
         |> assign(:pending_username, username)
         |> assign(:form, new_password_form())
         |> assign(:error, nil)}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Invalid username or password.")}
    end
  end

  def handle_event(
        "set_password",
        %{"new_password" => %{"password" => password, "confirm" => confirm}},
        socket
      ) do
    cond do
      String.length(password) < 12 ->
        {:noreply, assign(socket, :error, "Password must be at least 12 characters.")}

      password != confirm ->
        {:noreply, assign(socket, :error, "Passwords do not match.")}

      true ->
        case Provider.respond_new_password(
               socket.assigns.pending_username,
               password,
               socket.assigns.challenge_data
             ) do
          {:ok, user} ->
            {:noreply, complete_login(socket, user)}

          {:error, _} ->
            {:noreply, assign(socket, :error, "Failed to set password. Please try again.")}
        end
    end
  end

  defp complete_login(socket, user) do
    token = SessionBridge.store(user)
    return_to = URI.encode_www_form(socket.assigns.return_to)
    push_navigate(socket, to: "/auth/session/#{token}?return_to=#{return_to}")
  end

  defp login_form, do: to_form(%{"username" => "", "password" => ""}, as: :login)
  defp new_password_form, do: to_form(%{"password" => "", "confirm" => ""}, as: :new_password)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="login-page" class="flex min-h-[60vh] items-center justify-center">
        <div class="w-full max-w-sm space-y-6">
          <%= if @step == :login do %>
            <div class="text-center">
              <h1 class="text-2xl font-semibold tracking-tight">Sign in</h1>
              <p class="mt-1 text-sm text-base-content/60">Air2Tree Measurement Platform</p>
            </div>

            <.form for={@form} id="login-form" phx-submit="submit" class="space-y-4">
              <.input
                field={@form[:username]}
                type="text"
                label="Username"
                id="login-username"
                autocomplete="username"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                id="login-password"
                autocomplete="current-password"
                required
              />

              <p :if={@error} id="login-error" class="text-sm text-error">{@error}</p>

              <button id="login-submit" type="submit" class="btn btn-primary w-full">
                Sign in
              </button>
            </.form>
          <% else %>
            <div class="text-center">
              <h1 class="text-2xl font-semibold tracking-tight">Set your password</h1>
              <p class="mt-1 text-sm text-base-content/60">
                Choose a permanent password to continue.
              </p>
            </div>

            <.form
              for={@form}
              id="new-password-form"
              phx-submit="set_password"
              class="space-y-4"
            >
              <.input
                field={@form[:password]}
                type="password"
                label="New password"
                id="new-password"
                autocomplete="new-password"
                required
              />
              <.input
                field={@form[:confirm]}
                type="password"
                label="Confirm password"
                id="confirm-password"
                autocomplete="new-password"
                required
              />

              <p class="text-xs text-base-content/50">
                Minimum 12 characters with uppercase, lowercase, and numbers.
              </p>

              <p :if={@error} id="new-password-error" class="text-sm text-error">{@error}</p>

              <button id="set-password-submit" type="submit" class="btn btn-primary w-full">
                Set password
              </button>
            </.form>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
