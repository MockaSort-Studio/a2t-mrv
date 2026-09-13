defmodule LivedataWeb.Router do
  use LivedataWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LivedataWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # ── Auth routes (unauthenticated) ─────────────────────────────────────────
  scope "/auth", LivedataWeb do
    pipe_through :browser

    get "/cognito", AuthController, :new
    get "/cognito/callback", AuthController, :callback
    delete "/cognito", AuthController, :delete
  end

  # ── Authenticated routes ───────────────────────────────────────────────────
  scope "/", LivedataWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: {LivedataWeb.UserAuth, :ensure_authenticated} do
      live "/", DashboardLive
      live "/projects/new", ProjectRegistrationLive
      live "/projects/:id", ProjectShowLive
      # @req: CRCF-34 — a project accumulates activities beyond the first
      live "/projects/:project_id/activities/new", ActivityNewLive
      live "/activities/:id", ActivityShowLive
      live "/measurements/new", MeasurementEntryLive
      live "/measurements/upload", MeasurementUploadLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:livedata, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LivedataWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
