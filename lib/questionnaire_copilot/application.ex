defmodule QuestionnaireCopilot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    demo_children =
      if QuestionnaireCopilot.Demo.enabled?() do
        [
          {Registry, keys: :unique, name: QuestionnaireCopilot.Demo.Registry},
          QuestionnaireCopilot.Demo.SessionSupervisor
        ]
      else
        []
      end

    children =
      [
        QuestionnaireCopilotWeb.Telemetry,
        QuestionnaireCopilot.Repo,
        {DNSCluster,
         query: Application.get_env(:questionnaire_copilot, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: QuestionnaireCopilot.PubSub}
      ] ++ demo_children ++ [QuestionnaireCopilotWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: QuestionnaireCopilot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QuestionnaireCopilotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
