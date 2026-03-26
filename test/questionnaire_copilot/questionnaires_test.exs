defmodule QuestionnaireCopilot.QuestionnairesTest do
  use QuestionnaireCopilot.DataCase

  alias QuestionnaireCopilot.Questionnaires

  defp create_questionnaire(name \\ "Test Questionnaire") do
    {:ok, q} = Questionnaires.create_questionnaire(%{name: name})
    q
  end

  describe "questionnaires" do
    test "list_questionnaires/0 returns all questionnaires" do
      q = create_questionnaire()
      assert [returned] = Questionnaires.list_questionnaires()
      assert returned.id == q.id
    end

    test "list_questionnaires/0 includes item count" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?\nQ2?\nQ3?")
      [returned] = Questionnaires.list_questionnaires()
      assert returned.item_count == 3
    end

    test "get_questionnaire!/1 returns questionnaire with ordered items" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "First?\nSecond?\nThird?")
      loaded = Questionnaires.get_questionnaire!(q.id)
      assert length(loaded.items) == 3
      assert hd(loaded.items).original_question == "First?"
      assert hd(loaded.items).position == 1
    end

    test "create_questionnaire/1 defaults status to in_progress" do
      q = create_questionnaire()
      assert q.status == :in_progress
    end

    test "create_questionnaire/1 without name fails" do
      assert {:error, changeset} = Questionnaires.create_questionnaire(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "delete_questionnaire/1 cascades to items" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?\nQ2?")
      {:ok, _} = Questionnaires.delete_questionnaire(q)
      assert Questionnaires.list_questionnaires() == []
    end
  end

  describe "create_items_from_text/2" do
    test "creates items from newline-separated text" do
      q = create_questionnaire()
      {3, _} = Questionnaires.create_items_from_text(q, "Q1?\nQ2?\nQ3?")
      loaded = Questionnaires.get_questionnaire!(q.id)
      assert length(loaded.items) == 3
      assert Enum.map(loaded.items, & &1.position) == [1, 2, 3]
    end

    test "trims whitespace and skips blank lines" do
      q = create_questionnaire()
      {2, _} = Questionnaires.create_items_from_text(q, "  Q1?  \n\n  Q2?  \n\n")
      loaded = Questionnaires.get_questionnaire!(q.id)
      assert length(loaded.items) == 2
    end

    test "items default to unmatched status" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?")
      loaded = Questionnaires.get_questionnaire!(q.id)
      assert hd(loaded.items).status == :unmatched
    end
  end

  describe "create_items_from_list/2" do
    test "creates items from a list of strings" do
      q = create_questionnaire()
      {2, _} = Questionnaires.create_items_from_list(q, ["Q1?", "Q2?"])
      loaded = Questionnaires.get_questionnaire!(q.id)
      assert length(loaded.items) == 2
    end
  end

  describe "update_item/2" do
    test "updates item status and answer" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?")
      loaded = Questionnaires.get_questionnaire!(q.id)
      item = hd(loaded.items)

      {:ok, updated} = Questionnaires.update_item(item, %{final_answer: "A1.", status: :answered})
      assert updated.final_answer == "A1."
      assert updated.status == :answered
    end
  end

  describe "progress/1" do
    test "returns done and total counts" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?\nQ2?\nQ3?")
      loaded = Questionnaires.get_questionnaire!(q.id)

      assert {0, 3} = Questionnaires.progress(loaded)

      item = hd(loaded.items)
      Questionnaires.update_item(item, %{status: :answered, final_answer: "A."})
      loaded = Questionnaires.get_questionnaire!(q.id)

      assert {1, 3} = Questionnaires.progress(loaded)
    end

    test "counts skipped as done" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?")
      loaded = Questionnaires.get_questionnaire!(q.id)

      Questionnaires.update_item(hd(loaded.items), %{status: :skipped})
      loaded = Questionnaires.get_questionnaire!(q.id)

      assert {1, 1} = Questionnaires.progress(loaded)
    end
  end

  describe "maybe_mark_completed/1" do
    test "marks questionnaire completed when all items are done" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?")
      loaded = Questionnaires.get_questionnaire!(q.id)

      Questionnaires.update_item(hd(loaded.items), %{status: :answered, final_answer: "A."})
      loaded = Questionnaires.get_questionnaire!(q.id)

      {:ok, updated} = Questionnaires.maybe_mark_completed(loaded)
      assert updated.status == :completed
    end

    test "does not mark completed when items remain" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?\nQ2?")
      loaded = Questionnaires.get_questionnaire!(q.id)

      Questionnaires.update_item(hd(loaded.items), %{status: :answered, final_answer: "A."})
      loaded = Questionnaires.get_questionnaire!(q.id)

      {:ok, unchanged} = Questionnaires.maybe_mark_completed(loaded)
      assert unchanged.status == :in_progress
    end
  end

  describe "to_csv/1" do
    test "exports questionnaire items as CSV" do
      q = create_questionnaire()
      Questionnaires.create_items_from_text(q, "Q1?\nQ2?")
      loaded = Questionnaires.get_questionnaire!(q.id)

      Questionnaires.update_item(hd(loaded.items), %{status: :answered, final_answer: "A1."})
      loaded = Questionnaires.get_questionnaire!(q.id)

      csv = Questionnaires.to_csv(loaded)
      assert csv =~ "original_question,final_answer,status"
      assert csv =~ "Q1?"
      assert csv =~ "A1."
    end
  end
end
