defmodule QuestionnaireCopilot.Vault do
  @moduledoc """
  Context for managing Q&A pairs in the vault.
  """

  import Ecto.Query
  alias QuestionnaireCopilot.Repo
  alias QuestionnaireCopilot.Vault.QAPair

  def list_qa_pairs do
    Repo.all(from q in QAPair, order_by: [desc: q.updated_at])
  end

  def get_qa_pair!(id), do: Repo.get!(QAPair, id)

  def create_qa_pair(attrs \\ %{}) do
    %QAPair{}
    |> QAPair.changeset(attrs)
    |> Repo.insert()
  end

  def update_qa_pair(%QAPair{} = qa_pair, attrs) do
    qa_pair
    |> QAPair.changeset(attrs)
    |> Repo.update()
  end

  def delete_qa_pair(%QAPair{} = qa_pair) do
    Repo.delete(qa_pair)
  end

  def change_qa_pair(%QAPair{} = qa_pair, attrs \\ %{}) do
    QAPair.changeset(qa_pair, attrs)
  end

  @doc """
  Search using trigram similarity — good for fuzzy matching incoming questions
  against the vault. Returns results ranked by similarity score.
  """
  def search_qa_pairs(query) when is_binary(query) and query != "" do
    from(q in QAPair,
      where: fragment("similarity(?, ?) > 0.1", q.question, ^query),
      order_by: [desc: fragment("similarity(?, ?)", q.question, ^query)]
    )
    |> Repo.all()
  end

  def search_qa_pairs(_), do: list_qa_pairs()

  @doc """
  Import Q&A pairs from CSV content. Expects columns: question, answer, tags, source.
  Tags should be semicolon-separated within the field.
  Returns {:ok, count} or {:error, reason}.
  """
  def import_csv(csv_string) when is_binary(csv_string) do
    lines =
      csv_string
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [] ->
        {:error, "CSV is empty"}

      [_header | rows] ->
        results =
          Enum.map(rows, fn row ->
            fields = parse_csv_row(row)

            case fields do
              [question, answer | rest] ->
                tags =
                  case Enum.at(rest, 0) do
                    nil -> []
                    "" -> []
                    t -> t |> String.split(";") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
                  end

                source = Enum.at(rest, 1)

                if question_exists?(question) do
                  {:skip, :duplicate}
                else
                  create_qa_pair(%{
                    question: question,
                    answer: answer,
                    tags: tags,
                    source: source
                  })
                end

              _ ->
                {:error, "Invalid row: #{row}"}
            end
          end)

        imported = Enum.count(results, &match?({:ok, _}, &1))
        skipped = Enum.count(results, &match?({:skip, _}, &1))
        {:ok, %{imported: imported, skipped: skipped}}
    end
  end

  defp question_exists?(question) do
    Repo.exists?(from q in QAPair, where: q.question == ^question)
  end

  # Simple CSV row parser that handles quoted fields
  defp parse_csv_row(row) do
    # Regex splits on commas not inside quotes
    ~r/,(?=(?:[^"]*"[^"]*")*[^"]*$)/
    |> Regex.split(row)
    |> Enum.map(fn field ->
      field
      |> String.trim()
      |> String.trim("\"")
      |> String.replace("\"\"", "\"")
    end)
  end

  def filter_by_tag(tag) when is_binary(tag) and tag != "" do
    from(q in QAPair,
      where: ^tag in q.tags,
      order_by: [desc: q.updated_at]
    )
    |> Repo.all()
  end

  def search_and_filter(search, tags) when is_list(tags) do
    QAPair
    |> maybe_search(search)
    |> maybe_filter_tags(tags)
    |> Repo.all()
  end

  defp maybe_search(query, ""), do: query |> order_by([q], desc: q.updated_at)
  defp maybe_search(query, nil), do: query |> order_by([q], desc: q.updated_at)

  defp maybe_search(_query, search) do
    from(q in QAPair,
      where: fragment("similarity(?, ?) > 0.1", q.question, ^search),
      order_by: [desc: fragment("similarity(?, ?)", q.question, ^search)]
    )
  end

  defp maybe_filter_tags(query, []), do: query

  defp maybe_filter_tags(query, tags) do
    Enum.reduce(tags, query, fn tag, q ->
      from(qa in q, where: ^tag in qa.tags)
    end)
  end

  def all_tags do
    from(q in QAPair, select: q.tags)
    |> Repo.all()
    |> List.flatten()
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_tag, count} -> -count end)
  end
end
