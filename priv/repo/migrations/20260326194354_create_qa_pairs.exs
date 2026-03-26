defmodule QuestionnaireCopilot.Repo.Migrations.CreateQaPairs do
  use Ecto.Migration

  def change do
    create table(:qa_pairs) do
      add :question, :text, null: false
      add :answer, :text, null: false
      add :tags, {:array, :string}, default: [], null: false
      add :source, :string

      timestamps(type: :utc_datetime)
    end
  end
end
