defmodule QuestionnaireCopilot.Vault do
  @moduledoc """
  Context for managing Q&A pairs in the vault.
  """

  import Ecto.Query
  alias QuestionnaireCopilot.Repo
  alias QuestionnaireCopilot.Embeddings
  alias QuestionnaireCopilot.Vault.QAPair

  def list_qa_pairs do
    Repo.all(from q in QAPair, order_by: [desc: q.updated_at])
  end

  def get_qa_pair!(id), do: Repo.get!(QAPair, id)

  def create_qa_pair(attrs \\ %{}) do
    with {:ok, qa_pair} <-
           %QAPair{}
           |> QAPair.changeset(attrs)
           |> Repo.insert() do
      maybe_generate_embedding(qa_pair)
      {:ok, qa_pair}
    end
  end

  def update_qa_pair(%QAPair{} = qa_pair, attrs) do
    with {:ok, qa_pair} <-
           qa_pair
           |> QAPair.changeset(attrs)
           |> Repo.update() do
      maybe_generate_embedding(qa_pair)
      {:ok, qa_pair}
    end
  end

  def delete_qa_pair(%QAPair{} = qa_pair) do
    Repo.delete(qa_pair)
  end

  def change_qa_pair(%QAPair{} = qa_pair, attrs \\ %{}) do
    QAPair.changeset(qa_pair, attrs)
  end

  defp maybe_generate_embedding(%QAPair{} = qa_pair) do
    if Embeddings.serving_available?() do
      Task.start(fn -> Embeddings.generate_and_store(qa_pair) end)
    end
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  defp search_backend do
    Application.get_env(:questionnaire_copilot, :search_backend, :trigram)
  end

  @doc """
  Search Q&A pairs using the configured search backend.
  Returns results ranked by relevance.
  """
  def search_qa_pairs(query) when is_binary(query) and query != "" do
    do_search(query, search_backend())
  end

  def search_qa_pairs(_), do: list_qa_pairs()

  @doc """
  Combined search + tag filtering using the configured backend.
  """
  def search_and_filter(search, tags) when is_list(tags) do
    QAPair
    |> maybe_search(search)
    |> maybe_filter_tags(tags)
    |> Repo.all()
  end

  @doc """
  Check if a close match exists in the vault for the given question.
  """
  def has_close_match?(question) when is_binary(question) do
    do_close_match?(question, search_backend())
  end

  # ---------------------------------------------------------------------------
  # Search dispatch
  # ---------------------------------------------------------------------------

  defp do_search(query, :semantic) do
    with true <- Embeddings.serving_available?(),
         embedding when is_list(embedding) <- Embeddings.generate(query) do
      semantic_search(query, embedding)
    else
      _ -> trigram_search(query)
    end
  end

  defp do_search(query, _backend), do: trigram_search(query)

  defp do_close_match?(question, :semantic) do
    with true <- Embeddings.serving_available?(),
         embedding when is_list(embedding) <- Embeddings.generate(question) do
      semantic_close_match?(embedding)
    else
      _ -> trigram_close_match?(question)
    end
  end

  defp do_close_match?(question, _backend), do: trigram_close_match?(question)

  defp maybe_search(query, search) when search in ["", nil] do
    order_by(query, [q], desc: q.updated_at)
  end

  defp maybe_search(query, search) do
    do_maybe_search(query, search, search_backend())
  end

  defp do_maybe_search(query, search, :semantic) do
    with true <- Embeddings.serving_available?(),
         embedding when is_list(embedding) <- Embeddings.generate(search) do
      from(q in query,
        where: not is_nil(q.embedding),
        order_by: fragment("? <=> ?::vector", q.embedding, ^Pgvector.new(embedding))
      )
    else
      _ -> do_maybe_search(query, search, :trigram)
    end
  end

  defp do_maybe_search(_query, search, _backend) do
    from(q in QAPair,
      where:
        fragment("similarity(?, ?) > 0.08", q.question, ^search) or
          fragment("similarity(?, ?) > 0.08", q.answer, ^search),
      order_by: [
        desc:
          fragment(
            "greatest(similarity(?, ?), similarity(?, ?))",
            q.question,
            ^search,
            q.answer,
            ^search
          )
      ]
    )
  end

  # ---------------------------------------------------------------------------
  # Semantic search (Bumblebee/Nx + pgvector)
  # ---------------------------------------------------------------------------

  defp semantic_search(_query, embedding) do
    from(q in QAPair,
      where: not is_nil(q.embedding),
      order_by: fragment("? <=> ?::vector", q.embedding, ^Pgvector.new(embedding)),
      limit: 20
    )
    |> Repo.all()
  end

  defp semantic_close_match?(embedding) do
    from(q in QAPair,
      where:
        not is_nil(q.embedding) and
          fragment("? <=> ?::vector < 0.5", q.embedding, ^Pgvector.new(embedding)),
      limit: 1
    )
    |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # Trigram search (pg_trgm) — kept for fallback and future configuration
  # ---------------------------------------------------------------------------

  defp trigram_search(query) do
    from(q in QAPair,
      where:
        fragment("similarity(?, ?) > 0.08", q.question, ^query) or
          fragment("similarity(?, ?) > 0.08", q.answer, ^query),
      order_by: [
        desc:
          fragment(
            "greatest(similarity(?, ?), similarity(?, ?)) + (similarity(?, ?) * 0.5)",
            q.question,
            ^query,
            q.answer,
            ^query,
            q.question,
            ^query
          )
      ]
    )
    |> Repo.all()
    |> Enum.uniq_by(& &1.id)
  end

  defp trigram_close_match?(question) do
    from(q in QAPair,
      where: fragment("similarity(?, ?) > 0.3", q.question, ^question),
      limit: 1
    )
    |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # Tag filtering
  # ---------------------------------------------------------------------------

  defp maybe_filter_tags(query, []), do: query

  defp maybe_filter_tags(query, tags) do
    Enum.reduce(tags, query, fn tag, q ->
      from(qa in q, where: ^tag in qa.tags)
    end)
  end

  # ---------------------------------------------------------------------------
  # CSV Import/Export
  # ---------------------------------------------------------------------------

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
                    nil ->
                      []

                    "" ->
                      []

                    t ->
                      t
                      |> String.split(";")
                      |> Enum.map(&String.trim/1)
                      |> Enum.reject(&(&1 == ""))
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

  # CSV row parser using a simple state machine (no regex, no ReDoS risk)
  defp parse_csv_row(row) do
    row
    |> String.graphemes()
    |> parse_fields([], "", false)
    |> Enum.reverse()
  end

  defp parse_fields([], acc, current, _in_quotes) do
    [String.trim(current) | acc]
  end

  defp parse_fields(["\"" | rest], acc, current, false) do
    parse_fields(rest, acc, current, true)
  end

  defp parse_fields(["\"", "\"" | rest], acc, current, true) do
    parse_fields(rest, acc, current <> "\"", true)
  end

  defp parse_fields(["\"" | rest], acc, current, true) do
    parse_fields(rest, acc, current, false)
  end

  defp parse_fields(["," | rest], acc, current, false) do
    parse_fields(rest, [String.trim(current) | acc], "", false)
  end

  defp parse_fields([char | rest], acc, current, in_quotes) do
    parse_fields(rest, acc, current <> char, in_quotes)
  end

  def filter_by_tag(tag) when is_binary(tag) and tag != "" do
    from(q in QAPair,
      where: ^tag in q.tags,
      order_by: [desc: q.updated_at]
    )
    |> Repo.all()
  end

  def to_csv do
    header = "question,answer,tags,source\r\n"

    rows =
      list_qa_pairs()
      |> Enum.map(fn qa ->
        [qa.question, qa.answer, Enum.join(qa.tags, ";"), qa.source || ""]
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

  def all_tags do
    from(q in QAPair, select: q.tags)
    |> Repo.all()
    |> List.flatten()
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_tag, count} -> -count end)
  end
end
