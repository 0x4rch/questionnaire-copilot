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

  def filter_by_tag(tag) when is_binary(tag) and tag != "" do
    from(q in QAPair,
      where: ^tag in q.tags,
      order_by: [desc: q.updated_at]
    )
    |> Repo.all()
  end
end
