defmodule QuestionnaireCopilotWeb.Plugs.DemoSession do
  @moduledoc """
  Plug that assigns a demo session ID when demo mode is enabled.
  Stores the session ID in the Phoenix session cookie so it persists
  across LiveView navigations.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if QuestionnaireCopilot.Demo.enabled?() do
      session_id = get_session(conn, :demo_session_id)

      session_id =
        if session_id do
          session_id
        else
          Ecto.UUID.generate()
        end

      case QuestionnaireCopilot.Demo.SessionSupervisor.ensure_session(session_id) do
        :ok ->
          conn |> put_session(:demo_session_id, session_id)

        {:error, :max_sessions_reached} ->
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(503, "Demo is at capacity. Please try again shortly.")
          |> halt()
      end
    else
      conn
    end
  end
end
