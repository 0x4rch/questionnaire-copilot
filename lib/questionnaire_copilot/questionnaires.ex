defmodule QuestionnaireCopilot.Questionnaires do
  @moduledoc """
  Context for managing questionnaires and their items.
  """

  import Ecto.Query
  alias QuestionnaireCopilot.Repo
  alias QuestionnaireCopilot.Questionnaires.{Questionnaire, QuestionnaireItem}

  # Questionnaires

  def list_questionnaires do
    Repo.all(from q in Questionnaire, order_by: [desc: q.inserted_at])
  end

  def get_questionnaire!(id) do
    Questionnaire
    |> Repo.get!(id)
    |> Repo.preload(items: from(i in QuestionnaireItem, order_by: i.position))
  end

  def create_questionnaire(attrs \\ %{}) do
    %Questionnaire{}
    |> Questionnaire.changeset(attrs)
    |> Repo.insert()
  end

  def delete_questionnaire(%Questionnaire{} = questionnaire) do
    Repo.delete(questionnaire)
  end

  def change_questionnaire(%Questionnaire{} = questionnaire, attrs \\ %{}) do
    Questionnaire.changeset(questionnaire, attrs)
  end

  # Questionnaire Items

  def create_items_from_text(questionnaire, text) when is_binary(text) do
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    items =
      lines
      |> Enum.with_index(1)
      |> Enum.map(fn {question, position} ->
        %{
          original_question: question,
          position: position,
          status: :unmatched,
          questionnaire_id: questionnaire.id,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(QuestionnaireItem, items)
  end

  def get_item!(id) do
    QuestionnaireItem
    |> Repo.get!(id)
    |> Repo.preload(:matched_qa_pair)
  end

  def update_item(%QuestionnaireItem{} = item, attrs) do
    item
    |> QuestionnaireItem.changeset(attrs)
    |> Repo.update()
  end

  def to_csv(questionnaire) do
    header = "original_question,final_answer,status\r\n"

    rows =
      questionnaire.items
      |> Enum.map(fn item ->
        [item.original_question, item.final_answer || "", to_string(item.status)]
        |> Enum.map(&csv_escape/1)
        |> Enum.join(",")
      end)
      |> Enum.join("\r\n")

    header <> rows
  end

  defp csv_escape(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  def progress(questionnaire) do
    items = questionnaire.items || []
    total = length(items)
    done = Enum.count(items, &(&1.status in [:answered, :skipped]))
    {done, total}
  end

  def maybe_mark_completed(questionnaire) do
    {done, total} = progress(questionnaire)

    if total > 0 and done == total and questionnaire.status != :completed do
      questionnaire
      |> Questionnaire.changeset(%{status: :completed})
      |> Repo.update()
    else
      {:ok, questionnaire}
    end
  end
end
