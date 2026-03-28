defmodule QuestionnaireCopilotWeb.Hooks.DemoHook do
  @moduledoc """
  LiveView on_mount hook that sets up demo mode assigns.
  Adds :store and :demo_mode to every LiveView in the session.
  """

  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    if QuestionnaireCopilot.Demo.enabled?() do
      session_id = session["demo_session_id"]

      # Ensure session GenServer is running (it may have timed out)
      QuestionnaireCopilot.Demo.SessionSupervisor.ensure_session(session_id)

      {:cont,
       socket
       |> assign(:store, {:demo, session_id})
       |> assign(:demo_mode, true)}
    else
      {:cont,
       socket
       |> assign(:store, :db)
       |> assign(:demo_mode, false)}
    end
  end
end
