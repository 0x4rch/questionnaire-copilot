defmodule Mix.Tasks.Embeddings.Backfill do
  @moduledoc """
  Generates embeddings for all Q&A pairs that don't have one yet.

      mix embeddings.backfill
  """

  use Mix.Task

  @shortdoc "Backfill embeddings for vault Q&A pairs"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    if !QuestionnaireCopilot.Embeddings.serving_available?() do
      Mix.raise("Embedding serving is not running. Check your configuration.")
    end

    Mix.shell().info("Backfilling embeddings...")

    results = QuestionnaireCopilot.Embeddings.backfill()

    case results do
      [] ->
        Mix.shell().info("All Q&A pairs already have embeddings.")

      results ->
        for {index, total, qa_pair} <- results do
          Mix.shell().info(
            "[#{index}/#{total}] Embedded: #{String.slice(qa_pair.question, 0, 60)}..."
          )
        end

        Mix.shell().info("Done! Embedded #{length(results)} Q&A pairs.")
    end
  end
end
