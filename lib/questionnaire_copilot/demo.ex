defmodule QuestionnaireCopilot.Demo do
  @moduledoc """
  Demo mode configuration helpers.
  Demo mode runs the app entirely in-memory with no database access.
  Enable via DEMO_MODE=true environment variable.
  """

  def enabled?, do: Application.get_env(:questionnaire_copilot, :demo_mode, false)
  def max_sessions, do: Application.get_env(:questionnaire_copilot, :demo_max_sessions, 50)
end
