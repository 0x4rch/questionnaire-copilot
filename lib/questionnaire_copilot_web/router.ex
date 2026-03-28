defmodule QuestionnaireCopilotWeb.Router do
  use QuestionnaireCopilotWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuestionnaireCopilotWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug QuestionnaireCopilotWeb.Plugs.DemoSession
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", QuestionnaireCopilotWeb do
    pipe_through :browser

    get "/questionnaires/:id/export", ExportController, :csv
    get "/vault/export", ExportController, :vault_csv

    live_session :default,
      layout: {QuestionnaireCopilotWeb.Layouts, :app},
      on_mount: [QuestionnaireCopilotWeb.Hooks.DemoHook] do
      live "/", DashboardLive
      live "/vault", VaultLive
      live "/questionnaires", QuestionnaireLive.Index
      live "/questionnaires/:id", QuestionnaireLive.Show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", QuestionnaireCopilotWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:questionnaire_copilot, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QuestionnaireCopilotWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
