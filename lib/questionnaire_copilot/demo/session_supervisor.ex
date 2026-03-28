defmodule QuestionnaireCopilot.Demo.SessionSupervisor do
  @moduledoc """
  DynamicSupervisor for demo session GenServers.
  Enforces a maximum concurrent session limit.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_session(session_id) do
    case Registry.lookup(QuestionnaireCopilot.Demo.Registry, session_id) do
      [{_pid, _}] ->
        :ok

      [] ->
        count = Registry.count(QuestionnaireCopilot.Demo.Registry)

        if count >= QuestionnaireCopilot.Demo.max_sessions() do
          {:error, :max_sessions_reached}
        else
          case DynamicSupervisor.start_child(
                 __MODULE__,
                 {QuestionnaireCopilot.Demo.Session, session_id}
               ) do
            {:ok, _pid} -> :ok
            {:error, {:already_started, _pid}} -> :ok
            error -> error
          end
        end
    end
  end
end
