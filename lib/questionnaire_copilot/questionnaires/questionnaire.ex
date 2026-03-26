defmodule QuestionnaireCopilot.Questionnaires.Questionnaire do
  use Ecto.Schema
  import Ecto.Changeset

  schema "questionnaires" do
    field :name, :string
    field :status, Ecto.Enum, values: [:in_progress, :completed], default: :in_progress

    has_many :items, QuestionnaireCopilot.Questionnaires.QuestionnaireItem

    timestamps(type: :utc_datetime)
  end

  def changeset(questionnaire, attrs) do
    questionnaire
    |> cast(attrs, [:name, :status])
    |> validate_required([:name])
  end
end
