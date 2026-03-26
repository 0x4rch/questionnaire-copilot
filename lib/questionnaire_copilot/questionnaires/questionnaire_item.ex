defmodule QuestionnaireCopilot.Questionnaires.QuestionnaireItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "questionnaire_items" do
    field :original_question, :string
    field :final_answer, :string
    field :status, Ecto.Enum, values: [:unmatched, :matched, :answered, :skipped], default: :unmatched
    field :position, :integer

    belongs_to :questionnaire, QuestionnaireCopilot.Questionnaires.Questionnaire
    belongs_to :matched_qa_pair, QuestionnaireCopilot.Vault.QAPair

    timestamps(type: :utc_datetime)
  end

  def changeset(questionnaire_item, attrs) do
    questionnaire_item
    |> cast(attrs, [:original_question, :final_answer, :status, :position, :matched_qa_pair_id])
    |> validate_required([:original_question, :position])
  end
end
