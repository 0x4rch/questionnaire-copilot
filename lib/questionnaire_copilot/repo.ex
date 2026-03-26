defmodule QuestionnaireCopilot.Repo do
  use Ecto.Repo,
    otp_app: :questionnaire_copilot,
    adapter: Ecto.Adapters.Postgres
end
