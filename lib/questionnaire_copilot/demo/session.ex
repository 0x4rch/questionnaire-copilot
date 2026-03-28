defmodule QuestionnaireCopilot.Demo.Session do
  @moduledoc """
  GenServer holding all demo state in memory for a single user session.
  Automatically terminates after 5 minutes of inactivity.
  """

  use GenServer

  alias QuestionnaireCopilot.Demo.SeedData
  alias QuestionnaireCopilot.Vault.QAPair
  alias QuestionnaireCopilot.Questionnaires.{Questionnaire, QuestionnaireItem}

  @timeout :timer.minutes(5)

  # Client

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via(session_id))
  end

  def call(session_id, message) do
    case GenServer.call(via(session_id), message) do
      {:__demo_error__, exception, stacktrace} ->
        reraise exception, stacktrace

      result ->
        result
    end
  end

  @max_qa_pairs 200
  @max_questionnaires 10

  defp via(session_id) do
    {:via, Registry, {QuestionnaireCopilot.Demo.Registry, session_id}}
  end

  defp to_int(id) when is_integer(id), do: id

  defp to_int(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> raise KeyError, key: id, term: %{}
    end
  end

  # Server

  @impl true
  def init(_session_id) do
    state = seed_state()
    {:ok, state, @timeout}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(message, _from, state) do
    try do
      {reply, new_state} = handle_message(message, state)
      {:reply, reply, new_state, @timeout}
    rescue
      e -> {:reply, {:__demo_error__, e, __STACKTRACE__}, state, @timeout}
    end
  end

  # Message handlers

  defp handle_message(:list_qa_pairs, state) do
    pairs =
      state.qa_pairs
      |> Map.values()
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})

    {pairs, state}
  end

  defp handle_message({:get_qa_pair, id}, state) do
    {Map.fetch!(state.qa_pairs, to_int(id)), state}
  end

  defp handle_message({:create_qa_pair, attrs}, state) do
    if map_size(state.qa_pairs) >= @max_qa_pairs do
      {{:error, :limit_reached}, state}
    else
      changeset = QAPair.changeset(%QAPair{}, attrs)

      case Ecto.Changeset.apply_action(changeset, :insert) do
        {:ok, pair} ->
          {id, state} = next_id(state)
          now = DateTime.utc_now() |> DateTime.truncate(:second)
          pair = %{pair | id: id, inserted_at: now, updated_at: now}
          state = put_in(state.qa_pairs[id], pair)
          {{:ok, pair}, state}

        {:error, changeset} ->
          {{:error, changeset}, state}
      end
    end
  end

  defp handle_message({:update_qa_pair, id, attrs}, state) do
    pair = Map.fetch!(state.qa_pairs, to_int(id))
    changeset = QAPair.changeset(pair, attrs)

    case Ecto.Changeset.apply_action(changeset, :update) do
      {:ok, updated} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        updated = %{updated | updated_at: now}
        state = put_in(state.qa_pairs[to_int(id)], updated)
        {{:ok, updated}, state}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  defp handle_message({:delete_qa_pair, id}, state) do
    id = to_int(id)
    pair = Map.fetch!(state.qa_pairs, id)
    state = update_in(state.qa_pairs, &Map.delete(&1, id))

    # Nilify matched references
    state =
      update_in(state.items, fn items ->
        Map.new(items, fn {k, item} ->
          if item.matched_qa_pair_id == id do
            {k, %{item | matched_qa_pair_id: nil}}
          else
            {k, item}
          end
        end)
      end)

    {{:ok, pair}, state}
  end

  defp handle_message({:change_qa_pair, pair, attrs}, state) do
    {QAPair.changeset(pair, attrs), state}
  end

  defp handle_message({:search_qa_pairs, query}, state) when query in ["", nil] do
    handle_message(:list_qa_pairs, state)
  end

  defp handle_message({:search_qa_pairs, query}, state) do
    results = fuzzy_search(Map.values(state.qa_pairs), query)
    {results, state}
  end

  defp handle_message({:search_and_filter, search, tags}, state) do
    results =
      state.qa_pairs
      |> Map.values()
      |> maybe_fuzzy_search(search)
      |> maybe_filter_tags(tags)

    {results, state}
  end

  defp handle_message(:all_tags, state) do
    tags =
      state.qa_pairs
      |> Map.values()
      |> Enum.flat_map(& &1.tags)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_tag, count} -> -count end)

    {tags, state}
  end

  defp handle_message({:has_close_match?, question}, state) do
    has_match =
      state.qa_pairs
      |> Map.values()
      |> Enum.any?(fn pair ->
        String.jaro_distance(String.downcase(pair.question), String.downcase(question)) > 0.7
      end)

    {has_match, state}
  end

  defp handle_message({:import_csv, csv_string}, state) do
    lines =
      csv_string
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [] ->
        {{:error, "CSV is empty"}, state}

      [_header | rows] ->
        {imported, skipped, state} =
          Enum.reduce(rows, {0, 0, state}, fn row, {imp, skip, st} ->
            fields = parse_csv_row(row)

            case fields do
              [question, answer | rest] ->
                tags = parse_csv_tags(Enum.at(rest, 0))
                source = Enum.at(rest, 1)

                cond do
                  question_exists?(st, question) ->
                    {imp, skip + 1, st}

                  map_size(st.qa_pairs) >= @max_qa_pairs ->
                    {imp, skip + 1, st}

                  true ->
                    {id, st} = next_id(st)
                    now = DateTime.utc_now() |> DateTime.truncate(:second)

                    pair = %QAPair{
                      id: id,
                      question: question,
                      answer: answer,
                      tags: tags,
                      source: source,
                      inserted_at: now,
                      updated_at: now
                    }

                    st = put_in(st.qa_pairs[id], pair)
                    {imp + 1, skip, st}
                end

              _ ->
                {imp, skip, st}
            end
          end)

        {{:ok, %{imported: imported, skipped: skipped}}, state}
    end
  end

  defp handle_message(:vault_to_csv, state) do
    header = "question,answer,tags,source\r\n"

    rows =
      state.qa_pairs
      |> Map.values()
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
      |> Enum.map(fn qa ->
        [qa.question, qa.answer, Enum.join(qa.tags, ";"), qa.source || ""]
        |> Enum.map(&csv_escape/1)
        |> Enum.join(",")
      end)
      |> Enum.join("\r\n")

    {header <> rows, state}
  end

  # Questionnaire operations

  defp handle_message(:list_questionnaires, state) do
    questionnaires =
      state.questionnaires
      |> Map.values()
      |> Enum.map(fn q ->
        count =
          state.items
          |> Map.values()
          |> Enum.count(&(&1.questionnaire_id == q.id))

        %{q | item_count: count}
      end)
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    {questionnaires, state}
  end

  defp handle_message({:get_questionnaire, id}, state) do
    id = to_int(id)
    q = Map.fetch!(state.questionnaires, id)

    items =
      state.items
      |> Map.values()
      |> Enum.filter(&(&1.questionnaire_id == id))
      |> Enum.sort_by(& &1.position)

    {%{q | items: items}, state}
  end

  defp handle_message({:create_questionnaire, attrs}, state) do
    if map_size(state.questionnaires) >= @max_questionnaires do
      changeset =
        %Questionnaire{}
        |> Questionnaire.changeset(attrs)
        |> Ecto.Changeset.add_error(:name, "demo limit reached (max #{@max_questionnaires})")

      {{:error, changeset}, state}
    else
      changeset = Questionnaire.changeset(%Questionnaire{}, attrs)

      case Ecto.Changeset.apply_action(changeset, :insert) do
        {:ok, q} ->
          {id, state} = next_id(state)
          now = DateTime.utc_now() |> DateTime.truncate(:second)
          q = %{q | id: id, inserted_at: now, updated_at: now, items: []}
          state = put_in(state.questionnaires[id], q)
          {{:ok, q}, state}

        {:error, changeset} ->
          {{:error, changeset}, state}
      end
    end
  end

  defp handle_message({:delete_questionnaire, id}, state) do
    id = to_int(id)
    q = Map.fetch!(state.questionnaires, id)
    state = update_in(state.questionnaires, &Map.delete(&1, id))

    state =
      update_in(state.items, fn items ->
        items |> Enum.reject(fn {_k, item} -> item.questionnaire_id == id end) |> Map.new()
      end)

    {{:ok, q}, state}
  end

  defp handle_message({:change_questionnaire, q, attrs}, state) do
    {Questionnaire.changeset(q, attrs), state}
  end

  defp handle_message({:create_items_from_text, q_id, text}, state) do
    questions =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {count, state} = insert_items(state, q_id, questions)
    {{count, nil}, state}
  end

  defp handle_message({:create_items_from_list, q_id, questions}, state) do
    {count, state} = insert_items(state, q_id, questions)
    {{count, nil}, state}
  end

  defp handle_message({:get_item, id}, state) do
    item = Map.fetch!(state.items, to_int(id))

    item =
      if item.matched_qa_pair_id do
        %{item | matched_qa_pair: Map.get(state.qa_pairs, item.matched_qa_pair_id)}
      else
        item
      end

    {item, state}
  end

  defp handle_message({:update_item, id, attrs}, state) do
    id = to_int(id)
    item = Map.fetch!(state.items, id)
    changeset = QuestionnaireItem.changeset(item, attrs)

    case Ecto.Changeset.apply_action(changeset, :update) do
      {:ok, updated} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        updated = %{updated | updated_at: now}
        state = put_in(state.items[id], updated)
        {{:ok, updated}, state}

      {:error, changeset} ->
        {{:error, changeset}, state}
    end
  end

  defp handle_message({:questionnaire_to_csv, id}, state) do
    {q, _state} = handle_message({:get_questionnaire, id}, state)

    header = "original_question,final_answer,status\r\n"

    rows =
      q.items
      |> Enum.map(fn item ->
        [item.original_question, item.final_answer || "", to_string(item.status)]
        |> Enum.map(&csv_escape/1)
        |> Enum.join(",")
      end)
      |> Enum.join("\r\n")

    {header <> rows, state}
  end

  defp handle_message({:progress, q}, state) do
    items = q.items || []
    total = length(items)
    done = Enum.count(items, &(&1.status in [:answered, :skipped]))
    {{done, total}, state}
  end

  defp handle_message({:maybe_mark_completed, q}, state) do
    items =
      state.items
      |> Map.values()
      |> Enum.filter(&(&1.questionnaire_id == q.id))

    total = length(items)
    done = Enum.count(items, &(&1.status in [:answered, :skipped]))

    if total > 0 and done == total and q.status != :completed do
      updated = %{
        q
        | status: :completed,
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      state = put_in(state.questionnaires[q.id], updated)
      {{:ok, updated}, state}
    else
      {{:ok, q}, state}
    end
  end

  # Helpers

  defp seed_state do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    state = %{qa_pairs: %{}, questionnaires: %{}, items: %{}, next_id: 1}

    # Seed QA pairs
    {state, _} =
      Enum.reduce(SeedData.qa_pairs(), {state, 1}, fn attrs, {st, _} ->
        {id, st} = next_id(st)

        pair = %QAPair{
          id: id,
          question: attrs.question,
          answer: attrs.answer,
          tags: attrs.tags,
          source: attrs.source,
          inserted_at: now,
          updated_at: now
        }

        {put_in(st.qa_pairs[id], pair), id}
      end)

    # Seed questionnaire
    {q_id, state} = next_id(state)

    q = %Questionnaire{
      id: q_id,
      name: SeedData.questionnaire().name,
      status: :in_progress,
      item_count: 0,
      items: [],
      inserted_at: now,
      updated_at: now
    }

    state = put_in(state.questionnaires[q_id], q)

    # Seed questionnaire items
    {_count, state} = insert_items(state, q_id, SeedData.questions())

    state
  end

  @max_items 200

  defp insert_items(state, q_id, questions) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {state, count} =
      questions
      |> Enum.take(@max_items)
      |> Enum.with_index(1)
      |> Enum.reduce({state, 0}, fn {question, position}, {st, count} ->
        {id, st} = next_id(st)

        item = %QuestionnaireItem{
          id: id,
          original_question: question,
          position: position,
          status: :unmatched,
          questionnaire_id: q_id,
          inserted_at: now,
          updated_at: now
        }

        st = put_in(st.items[id], item)
        {st, count + 1}
      end)

    {count, state}
  end

  defp next_id(state) do
    {state.next_id, %{state | next_id: state.next_id + 1}}
  end

  defp fuzzy_search(pairs, query) do
    query_down = String.downcase(query)

    pairs
    |> Enum.map(fn pair ->
      q_score = String.jaro_distance(String.downcase(pair.question), query_down)
      a_score = String.jaro_distance(String.downcase(pair.answer), query_down)
      {pair, max(q_score, a_score)}
    end)
    |> Enum.filter(fn {_, score} -> score > 0.4 end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.map(fn {pair, _} -> pair end)
  end

  defp maybe_fuzzy_search(pairs, query) when query in ["", nil] do
    Enum.sort_by(pairs, & &1.updated_at, {:desc, DateTime})
  end

  defp maybe_fuzzy_search(pairs, query), do: fuzzy_search(pairs, query)

  defp maybe_filter_tags(pairs, []), do: pairs

  defp maybe_filter_tags(pairs, tags) do
    Enum.filter(pairs, fn pair ->
      Enum.all?(tags, &(&1 in pair.tags))
    end)
  end

  defp question_exists?(state, question) do
    state.qa_pairs
    |> Map.values()
    |> Enum.any?(&(&1.question == question))
  end

  defp parse_csv_row(row) do
    row
    |> String.graphemes()
    |> do_parse_fields([], "", false)
    |> Enum.reverse()
  end

  defp do_parse_fields([], acc, current, _), do: [String.trim(current) | acc]

  defp do_parse_fields(["\"" | rest], acc, current, false),
    do: do_parse_fields(rest, acc, current, true)

  defp do_parse_fields(["\"", "\"" | rest], acc, current, true),
    do: do_parse_fields(rest, acc, current <> "\"", true)

  defp do_parse_fields(["\"" | rest], acc, current, true),
    do: do_parse_fields(rest, acc, current, false)

  defp do_parse_fields(["," | rest], acc, current, false),
    do: do_parse_fields(rest, [String.trim(current) | acc], "", false)

  defp do_parse_fields([char | rest], acc, current, in_q),
    do: do_parse_fields(rest, acc, current <> char, in_q)

  defp parse_csv_tags(nil), do: []
  defp parse_csv_tags(""), do: []

  defp parse_csv_tags(t) do
    t |> String.split(";") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp csv_escape(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
end
