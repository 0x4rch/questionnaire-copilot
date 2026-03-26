defmodule QuestionnaireCopilot.Repo.Migrations.CreateQuestionnaires do
  use Ecto.Migration

  def change do
    create table(:questionnaires) do
      add :name, :string, null: false
      add :status, :string, null: false, default: "in_progress"

      timestamps(type: :utc_datetime)
    end
  end
end
