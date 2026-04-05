defmodule QuestionnaireCopilot.Embeddings do
  @moduledoc """
  Manages text embeddings using a local sentence-transformers model via Bumblebee/Nx.
  The Nx.Serving is started in the application supervision tree and handles
  automatic batching of concurrent requests.
  """

  alias QuestionnaireCopilot.Repo
  alias QuestionnaireCopilot.Vault.QAPair

  import Ecto.Query

  @model "sentence-transformers/all-MiniLM-L6-v2"

  @doc """
  Builds the Nx.Serving for text embeddings. Called once at app startup.
  """
  def serving do
    {:ok, model_info} = Bumblebee.load_model({:hf, @model})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, @model})

    Bumblebee.Text.text_embedding(model_info, tokenizer,
      output_attribute: :hidden_state,
      output_pool: :mean_pooling,
      embedding_processor: :l2_norm,
      defn_options: [compiler: EXLA]
    )
  end

  @doc """
  Generates an embedding vector for the given text.
  Returns a list of floats.
  """
  def generate(text) when is_binary(text) do
    %{embedding: tensor} = Nx.Serving.batched_run(__MODULE__, text)
    Nx.to_flat_list(tensor)
  end

  @doc """
  Generates an embedding for a QAPair's question and stores it on the record.
  Combines question and answer text for a richer embedding.
  """
  def generate_and_store(%QAPair{} = qa_pair) do
    text = qa_pair.question <> " " <> (qa_pair.answer || "")
    embedding = generate(text)

    qa_pair
    |> Ecto.Changeset.change(%{embedding: Pgvector.new(embedding)})
    |> Repo.update()
  end

  @doc """
  Returns true if the embedding serving is running and available.
  """
  def serving_available? do
    Process.whereis(__MODULE__) != nil
  end

  @doc """
  Backfills embeddings for all QA pairs that don't have one yet.
  Yields `{index, total, qa_pair}` for each processed pair.
  """
  def backfill do
    pairs =
      from(q in QAPair, where: is_nil(q.embedding), order_by: q.id)
      |> Repo.all()

    total = length(pairs)

    pairs
    |> Enum.with_index(1)
    |> Enum.map(fn {qa_pair, index} ->
      {:ok, updated} = generate_and_store(qa_pair)
      {index, total, updated}
    end)
  end
end
