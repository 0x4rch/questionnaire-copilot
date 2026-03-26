defmodule QuestionnaireCopilot.Repo.Migrations.CreateQuestionnaireItems do
  use Ecto.Migration

  def change do
    create table(:questionnaire_items) do
      add :original_question, :text, null: false
      add :final_answer, :text
      add :status, :string, null: false, default: "unmatched"
      add :position, :integer, null: false
      add :questionnaire_id, references(:questionnaires, on_delete: :delete_all), null: false
      add :matched_qa_pair_id, references(:qa_pairs, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:questionnaire_items, [:questionnaire_id])
  end
end
