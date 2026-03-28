defmodule QuestionnaireCopilot.Demo.SessionTest do
  use ExUnit.Case, async: true

  alias QuestionnaireCopilot.Demo.Session

  setup do
    session_id = Ecto.UUID.generate()
    start_supervised!({Registry, keys: :unique, name: test_registry(session_id)})

    # Start session with the real registry (needs to be running)
    # We'll test via the GenServer directly
    {:ok, pid} = GenServer.start_link(Session, session_id)
    %{pid: pid}
  end

  defp call(pid, msg), do: GenServer.call(pid, msg)

  # Use the test registry name to avoid conflicts
  defp test_registry(id), do: :"test_registry_#{id}"

  describe "seed data" do
    test "starts with pre-seeded QA pairs", %{pid: pid} do
      pairs = call(pid, :list_qa_pairs)
      assert length(pairs) == 16
    end

    test "starts with pre-seeded questionnaire", %{pid: pid} do
      questionnaires = call(pid, :list_questionnaires)
      assert length(questionnaires) == 1
      assert hd(questionnaires).name == "Acme Corp Security Assessment Q1 2025"
    end

    test "questionnaire has pre-seeded items", %{pid: pid} do
      [q] = call(pid, :list_questionnaires)
      loaded = call(pid, {:get_questionnaire, q.id})
      assert length(loaded.items) == 15
    end
  end

  describe "vault operations" do
    test "create and retrieve QA pair", %{pid: pid} do
      {:ok, pair} = call(pid, {:create_qa_pair, %{question: "Test?", answer: "Yes."}})
      assert pair.id
      assert pair.question == "Test?"

      fetched = call(pid, {:get_qa_pair, pair.id})
      assert fetched.id == pair.id
    end

    test "handles string IDs", %{pid: pid} do
      {:ok, pair} = call(pid, {:create_qa_pair, %{question: "Test?", answer: "Yes."}})
      fetched = call(pid, {:get_qa_pair, to_string(pair.id)})
      assert fetched.id == pair.id
    end

    test "update QA pair", %{pid: pid} do
      {:ok, pair} = call(pid, {:create_qa_pair, %{question: "Q?", answer: "A."}})
      {:ok, updated} = call(pid, {:update_qa_pair, pair.id, %{answer: "Updated."}})
      assert updated.answer == "Updated."
    end

    test "delete QA pair", %{pid: pid} do
      {:ok, pair} = call(pid, {:create_qa_pair, %{question: "Q?", answer: "A."}})
      before_count = length(call(pid, :list_qa_pairs))
      {:ok, _} = call(pid, {:delete_qa_pair, pair.id})
      after_count = length(call(pid, :list_qa_pairs))
      assert after_count == before_count - 1
    end

    test "search QA pairs with fuzzy matching", %{pid: pid} do
      results = call(pid, {:search_qa_pairs, "encrypt data"})
      assert length(results) > 0
      assert hd(results).question =~ "encrypt"
    end

    test "all_tags returns tag frequencies", %{pid: pid} do
      tags = call(pid, :all_tags)
      assert is_list(tags)
      assert {"compliance", _count} = Enum.find(tags, fn {tag, _} -> tag == "compliance" end)
    end

    test "has_close_match? returns true for similar questions", %{pid: pid} do
      assert call(pid, {:has_close_match?, "Do you encrypt data at rest?"})
    end

    test "has_close_match? returns false for unrelated questions", %{pid: pid} do
      refute call(pid, {:has_close_match?, "What color is the sky?"})
    end

    test "enforces QA pair limit", %{pid: pid} do
      # Create pairs up to near the limit (16 seeded + new ones)
      for i <- 1..184 do
        call(pid, {:create_qa_pair, %{question: "Q#{i}?", answer: "A#{i}."}})
      end

      # Should be at the limit now (200)
      assert {:error, :limit_reached} =
               call(pid, {:create_qa_pair, %{question: "Over limit?", answer: "No."}})
    end
  end

  describe "questionnaire operations" do
    test "create questionnaire", %{pid: pid} do
      {:ok, q} = call(pid, {:create_questionnaire, %{name: "Test Q"}})
      assert q.name == "Test Q"
      assert q.status == :in_progress
    end

    test "create items from text", %{pid: pid} do
      {:ok, q} = call(pid, {:create_questionnaire, %{name: "Test"}})
      {3, _} = call(pid, {:create_items_from_text, q.id, "Q1?\nQ2?\nQ3?"})
      loaded = call(pid, {:get_questionnaire, q.id})
      assert length(loaded.items) == 3
    end

    test "update item status", %{pid: pid} do
      [q] = call(pid, :list_questionnaires)
      loaded = call(pid, {:get_questionnaire, q.id})
      item = hd(loaded.items)

      {:ok, updated} =
        call(pid, {:update_item, item.id, %{status: :answered, final_answer: "A."}})

      assert updated.status == :answered
      assert updated.final_answer == "A."
    end

    test "maybe_mark_completed marks when all done", %{pid: pid} do
      {:ok, q} = call(pid, {:create_questionnaire, %{name: "Small"}})
      {1, _} = call(pid, {:create_items_from_text, q.id, "Q1?"})
      loaded = call(pid, {:get_questionnaire, q.id})
      item = hd(loaded.items)

      call(pid, {:update_item, item.id, %{status: :answered, final_answer: "A."}})
      loaded = call(pid, {:get_questionnaire, q.id})
      {:ok, completed} = call(pid, {:maybe_mark_completed, loaded})
      assert completed.status == :completed
    end

    test "progress tracks answered/total", %{pid: pid} do
      {:ok, q} = call(pid, {:create_questionnaire, %{name: "Progress test"}})
      {2, _} = call(pid, {:create_items_from_text, q.id, "Q1?\nQ2?"})
      loaded = call(pid, {:get_questionnaire, q.id})

      {done, total} = call(pid, {:progress, loaded})
      assert done == 0
      assert total == 2
    end

    test "CSV export works", %{pid: pid} do
      [q] = call(pid, :list_questionnaires)
      csv = call(pid, {:questionnaire_to_csv, q.id})
      assert csv =~ "original_question,final_answer,status"
    end
  end

  describe "vault CSV operations" do
    test "vault CSV export", %{pid: pid} do
      csv = call(pid, :vault_to_csv)
      assert csv =~ "question,answer,tags,source"
      assert csv =~ "encrypt"
    end

    test "CSV import", %{pid: pid} do
      csv = "question,answer,tags,source\nNew Q?,New A.,tag1;tag2,Test"
      {:ok, %{imported: 1, skipped: 0}} = call(pid, {:import_csv, csv})
    end

    test "CSV import skips duplicates", %{pid: pid} do
      csv = "question,answer,tags,source\nDo you encrypt data at rest?,Different answer,,"
      {:ok, %{imported: 0, skipped: 1}} = call(pid, {:import_csv, csv})
    end
  end
end
