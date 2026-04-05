Postgrex.Types.define(
  QuestionnaireCopilot.PostgrexTypes,
  [Pgvector.Extensions.Vector] ++ Ecto.Adapters.Postgres.extensions(),
  []
)
