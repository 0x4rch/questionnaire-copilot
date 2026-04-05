defmodule QuestionnaireCopilot.Vault.QAPair do
  use Ecto.Schema
  import Ecto.Changeset

  schema "qa_pairs" do
    field :question, :string
    field :answer, :string
    field :tags, {:array, :string}, default: []
    field :source, :string
    field :embedding, Pgvector.Ecto.Vector

    has_many :matched_items, QuestionnaireCopilot.Questionnaires.QuestionnaireItem,
      foreign_key: :matched_qa_pair_id

    timestamps(type: :utc_datetime)
  end

  def changeset(qa_pair, attrs) do
    qa_pair
    |> cast(attrs, [:question, :answer, :tags, :source])
    |> validate_required([:question, :answer])
  end
end
