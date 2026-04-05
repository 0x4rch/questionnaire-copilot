defmodule QuestionnaireCopilot.Repo.Migrations.AddEmbeddings do
  use Ecto.Migration

  def change do
    execute(
      "CREATE EXTENSION IF NOT EXISTS vector",
      "DROP EXTENSION IF EXISTS vector"
    )

    alter table(:qa_pairs) do
      add :embedding, :vector, size: 384
    end

    create index(:qa_pairs, ["embedding vector_cosine_ops"], using: :hnsw)
  end
end
