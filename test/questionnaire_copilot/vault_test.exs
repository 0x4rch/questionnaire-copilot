defmodule QuestionnaireCopilot.VaultTest do
  use QuestionnaireCopilot.DataCase

  alias QuestionnaireCopilot.Vault
  alias QuestionnaireCopilot.Vault.QAPair

  @valid_attrs %{
    question: "Do you encrypt data at rest?",
    answer: "Yes, AES-256.",
    tags: ["encryption"],
    source: "SOC2"
  }
  @update_attrs %{answer: "Yes, AES-256 with AWS KMS."}

  describe "qa_pairs" do
    test "list_qa_pairs/0 returns all pairs ordered by updated_at" do
      {:ok, pair} = Vault.create_qa_pair(@valid_attrs)
      assert [returned] = Vault.list_qa_pairs()
      assert returned.id == pair.id
    end

    test "get_qa_pair!/1 returns the pair" do
      {:ok, pair} = Vault.create_qa_pair(@valid_attrs)
      assert Vault.get_qa_pair!(pair.id).id == pair.id
    end

    test "create_qa_pair/1 with valid data creates a pair" do
      assert {:ok, %QAPair{} = pair} = Vault.create_qa_pair(@valid_attrs)
      assert pair.question == "Do you encrypt data at rest?"
      assert pair.answer == "Yes, AES-256."
      assert pair.tags == ["encryption"]
      assert pair.source == "SOC2"
    end

    test "create_qa_pair/1 without question fails" do
      assert {:error, changeset} = Vault.create_qa_pair(%{answer: "Yes"})
      assert %{question: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_qa_pair/1 without answer fails" do
      assert {:error, changeset} = Vault.create_qa_pair(%{question: "Test?"})
      assert %{answer: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_qa_pair/1 without tags defaults to empty list" do
      assert {:ok, pair} = Vault.create_qa_pair(%{question: "Q?", answer: "A."})
      assert pair.tags == []
    end

    test "create_qa_pair/1 without source is nil" do
      assert {:ok, pair} = Vault.create_qa_pair(%{question: "Q?", answer: "A."})
      assert pair.source == nil
    end

    test "update_qa_pair/2 updates the pair" do
      {:ok, pair} = Vault.create_qa_pair(@valid_attrs)
      assert {:ok, updated} = Vault.update_qa_pair(pair, @update_attrs)
      assert updated.answer == "Yes, AES-256 with AWS KMS."
    end

    test "delete_qa_pair/1 deletes the pair" do
      {:ok, pair} = Vault.create_qa_pair(@valid_attrs)
      assert {:ok, _} = Vault.delete_qa_pair(pair)
      assert_raise Ecto.NoResultsError, fn -> Vault.get_qa_pair!(pair.id) end
    end
  end

  describe "search_qa_pairs/1" do
    test "returns matching pairs by question similarity" do
      {:ok, _} = Vault.create_qa_pair(@valid_attrs)
      results = Vault.search_qa_pairs("encrypt data")
      assert length(results) > 0
      assert hd(results).question =~ "encrypt"
    end

    test "returns matching pairs by answer similarity" do
      {:ok, _} = Vault.create_qa_pair(@valid_attrs)
      results = Vault.search_qa_pairs("AES-256")
      assert length(results) > 0
    end

    test "returns all pairs when query is empty" do
      {:ok, _} = Vault.create_qa_pair(@valid_attrs)
      results = Vault.search_qa_pairs("")
      assert length(results) > 0
    end
  end

  describe "import_csv/1" do
    test "imports valid CSV" do
      csv = "question,answer,tags,source\nTest question?,Test answer,tag1;tag2,Source1"
      assert {:ok, %{imported: 1, skipped: 0}} = Vault.import_csv(csv)
      assert [pair] = Vault.list_qa_pairs()
      assert pair.question == "Test question?"
      assert pair.tags == ["tag1", "tag2"]
    end

    test "skips duplicates" do
      {:ok, _} = Vault.create_qa_pair(%{question: "Existing?", answer: "Yes"})
      csv = "question,answer,tags,source\nExisting?,Different answer,,"
      assert {:ok, %{imported: 0, skipped: 1}} = Vault.import_csv(csv)
    end

    test "returns error for empty CSV" do
      assert {:error, "CSV is empty"} = Vault.import_csv("")
    end

    test "handles CSV with quoted fields containing commas" do
      csv = "question,answer,tags,source\n\"Has a, comma?\",\"Answer here\",tag1,"
      assert {:ok, %{imported: 1, skipped: 0}} = Vault.import_csv(csv)
      [pair] = Vault.list_qa_pairs()
      assert pair.question == "Has a, comma?"
      assert pair.answer == "Answer here"
    end
  end

  describe "all_tags/0" do
    test "returns tags with counts sorted by frequency" do
      {:ok, _} = Vault.create_qa_pair(%{question: "Q1?", answer: "A1", tags: ["a", "b"]})
      {:ok, _} = Vault.create_qa_pair(%{question: "Q2?", answer: "A2", tags: ["a", "c"]})
      tags = Vault.all_tags()
      assert {"a", 2} in tags
      assert {"b", 1} in tags
      assert {"c", 1} in tags
    end
  end

  describe "to_csv/0" do
    test "exports all pairs as CSV" do
      {:ok, _} = Vault.create_qa_pair(@valid_attrs)
      csv = Vault.to_csv()
      assert csv =~ "question,answer,tags,source"
      assert csv =~ "Do you encrypt data at rest?"
      assert csv =~ "encryption"
    end
  end

  describe "has_close_match?/1" do
    test "returns true when a close match exists" do
      {:ok, _} = Vault.create_qa_pair(@valid_attrs)
      assert Vault.has_close_match?("Do you encrypt data at rest?")
    end

    test "returns false when no close match exists" do
      {:ok, _} = Vault.create_qa_pair(@valid_attrs)
      refute Vault.has_close_match?("What color is the sky?")
    end
  end
end
