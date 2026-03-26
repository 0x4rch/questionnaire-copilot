defmodule QuestionnaireCopilotWeb.QuestionnaireLive.Show do
  use QuestionnaireCopilotWeb, :live_view

  alias QuestionnaireCopilot.Questionnaires
  alias QuestionnaireCopilot.Vault

  def mount(%{"id" => id}, _session, socket) do
    questionnaire = Questionnaires.get_questionnaire!(id)
    items = questionnaire.items
    current_index = find_first_unanswered(items)

    {:ok,
     socket
     |> assign(:questionnaire, questionnaire)
     |> assign(:items, items)
     |> assign(:current_index, current_index)
     |> assign(:matches, find_matches(items, current_index))
     |> assign(:editing_answer, false)
     |> assign(:manual_answer, "")}
  end

  # Accept a matched answer
  def handle_event("accept", %{"qa-id" => qa_id}, socket) do
    qa_pair = Vault.get_qa_pair!(qa_id)
    item = current_item(socket)

    {:ok, _} =
      Questionnaires.update_item(item, %{
        final_answer: qa_pair.answer,
        matched_qa_pair_id: qa_pair.id,
        status: :answered
      })

    {:noreply, reload_and_advance(socket)}
  end

  # Accept and open editor to tweak the answer
  def handle_event("accept-edit", %{"qa-id" => qa_id}, socket) do
    qa_pair = Vault.get_qa_pair!(qa_id)

    {:noreply,
     socket
     |> assign(:editing_answer, true)
     |> assign(:manual_answer, qa_pair.answer)
     |> assign(:matched_qa_pair_id, qa_pair.id)}
  end

  # Start writing a manual answer from scratch
  def handle_event("manual", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_answer, true)
     |> assign(:manual_answer, "")
     |> assign(:matched_qa_pair_id, nil)}
  end

  # Save the edited/manual answer
  def handle_event("save-answer", %{"answer" => answer}, socket) do
    item = current_item(socket)
    matched_id = socket.assigns[:matched_qa_pair_id]

    {:ok, _} =
      Questionnaires.update_item(item, %{
        final_answer: answer,
        matched_qa_pair_id: matched_id,
        status: :answered
      })

    {:noreply,
     socket
     |> assign(:editing_answer, false)
     |> reload_and_advance()}
  end

  # Skip the current question
  def handle_event("skip", _, socket) do
    item = current_item(socket)
    {:ok, _} = Questionnaires.update_item(item, %{status: :skipped})
    {:noreply, reload_and_advance(socket)}
  end

  # Navigate to a specific question by index
  def handle_event("goto", %{"index" => index}, socket) do
    index = String.to_integer(index)

    {:noreply,
     socket
     |> assign(:current_index, index)
     |> assign(:matches, find_matches(socket.assigns.items, index))
     |> assign(:editing_answer, false)}
  end

  # Keyboard navigation
  def handle_event("keydown", %{"key" => "j"}, socket) do
    next = min(socket.assigns.current_index + 1, length(socket.assigns.items) - 1)

    {:noreply,
     socket
     |> assign(:current_index, next)
     |> assign(:matches, find_matches(socket.assigns.items, next))
     |> assign(:editing_answer, false)}
  end

  def handle_event("keydown", %{"key" => "k"}, socket) do
    prev = max(socket.assigns.current_index - 1, 0)

    {:noreply,
     socket
     |> assign(:current_index, prev)
     |> assign(:matches, find_matches(socket.assigns.items, prev))
     |> assign(:editing_answer, false)}
  end

  def handle_event("keydown", %{"key" => "s"}, socket) do
    handle_event("skip", %{}, socket)
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  # Helpers

  defp current_item(socket) do
    Enum.at(socket.assigns.items, socket.assigns.current_index)
  end

  defp find_first_unanswered(items) do
    Enum.find_index(items, &(&1.status in [:unmatched, :matched])) || 0
  end

  defp find_matches(items, index) do
    case Enum.at(items, index) do
      nil -> []
      item -> Vault.search_qa_pairs(item.original_question)
    end
  end

  defp reload_and_advance(socket) do
    questionnaire = Questionnaires.get_questionnaire!(socket.assigns.questionnaire.id)
    items = questionnaire.items
    next_index = find_first_unanswered(items)

    socket
    |> assign(:questionnaire, questionnaire)
    |> assign(:items, items)
    |> assign(:current_index, next_index)
    |> assign(:matches, find_matches(items, next_index))
    |> assign(:editing_answer, false)
  end

  def render(assigns) do
    {done, total} = Questionnaires.progress(assigns.questionnaire)
    assigns = assign(assigns, :done, done) |> assign(:total, total)
    current = Enum.at(assigns.items, assigns.current_index)
    assigns = assign(assigns, :current, current)

    ~H"""
    <div class="max-w-6xl mx-auto" phx-window-keydown="keydown">
      <%!-- Header with progress --%>
      <div class="flex items-center justify-between mb-4">
        <div>
          <h1 class="text-lg font-semibold">{@questionnaire.name}</h1>
          <p class="text-sm text-base-content/60">{@done}/{@total} answered</p>
        </div>
        <.link navigate={~p"/questionnaires"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Back
        </.link>
      </div>

      <%!-- Progress bar --%>
      <progress class="progress progress-primary w-full mb-6" value={@done} max={@total}></progress>

      <div :if={@current} class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Left panel: current question --%>
        <div>
          <div class="card bg-base-200">
            <div class="card-body">
              <div class="text-sm text-base-content/50 mb-2">
                Question {@current_index + 1} of {@total}
              </div>
              <h2 class="card-title text-base">{@current.original_question}</h2>

              <%!-- Status badge --%>
              <div class="mt-2">
                <span class={[
                  "badge badge-sm",
                  @current.status == :answered && "badge-success",
                  @current.status == :skipped && "badge-warning",
                  @current.status in [:unmatched, :matched] && "badge-ghost"
                ]}>
                  {@current.status}
                </span>
              </div>

              <%!-- Show existing answer if answered --%>
              <div :if={@current.final_answer} class="mt-4 p-3 bg-base-100 rounded">
                <p class="text-sm font-semibold mb-1">Current answer:</p>
                <p class="whitespace-pre-wrap">{@current.final_answer}</p>
              </div>

              <%!-- Manual answer editor --%>
              <div :if={@editing_answer} class="mt-4">
                <form phx-submit="save-answer">
                  <textarea
                    name="answer"
                    class="textarea textarea-bordered w-full h-32"
                    placeholder="Type your answer..."
                  >{@manual_answer}</textarea>
                  <div class="flex gap-2 mt-2 justify-end">
                    <button type="button" class="btn btn-sm" phx-click="goto" phx-value-index={@current_index}>
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-sm btn-primary">Save Answer</button>
                  </div>
                </form>
              </div>

              <%!-- Action buttons --%>
              <div :if={!@editing_answer} class="card-actions justify-end mt-4">
                <button class="btn btn-sm" phx-click="manual">
                  <.icon name="hero-pencil" class="size-4" /> Answer Manually
                </button>
                <button class="btn btn-sm" phx-click="skip">
                  Skip (s)
                </button>
              </div>
            </div>
          </div>

          <%!-- Question navigator --%>
          <div class="flex flex-wrap gap-1 mt-4">
            <button
              :for={{item, idx} <- Enum.with_index(@items)}
              class={[
                "btn btn-xs",
                idx == @current_index && "btn-primary",
                idx != @current_index && item.status == :answered && "btn-success",
                idx != @current_index && item.status == :skipped && "btn-warning",
                idx != @current_index && item.status in [:unmatched, :matched] && "btn-ghost"
              ]}
              phx-click="goto"
              phx-value-index={idx}
            >
              {idx + 1}
            </button>
          </div>
          <p class="text-xs text-base-content/40 mt-2">j/k to navigate, s to skip</p>
        </div>

        <%!-- Right panel: suggested matches --%>
        <div>
          <h3 class="font-semibold mb-3">Suggested Matches</h3>
          <div :if={@matches == []} class="text-base-content/50 text-sm">
            No matches found in vault.
          </div>
          <div :for={match <- Enum.take(@matches, 5)} class="card bg-base-100 shadow-sm mb-3">
            <div class="card-body p-4">
              <p class="font-medium text-sm">{match.question}</p>
              <p class="text-sm whitespace-pre-wrap mt-1">{match.answer}</p>
              <div class="flex flex-wrap gap-1 mt-2">
                <span :for={tag <- match.tags} class="badge badge-outline badge-xs">{tag}</span>
              </div>
              <div class="card-actions justify-end mt-2">
                <button class="btn btn-xs btn-primary" phx-click="accept" phx-value-qa-id={match.id}>
                  Accept
                </button>
                <button class="btn btn-xs" phx-click="accept-edit" phx-value-qa-id={match.id}>
                  Accept & Edit
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- All done state --%>
      <div :if={!@current} class="text-center py-12">
        <h2 class="text-xl font-semibold mb-2">All done!</h2>
        <p class="text-base-content/60 mb-4">All questions have been answered or skipped.</p>
        <.link navigate={~p"/questionnaires"} class="btn btn-primary">
          Back to Questionnaires
        </.link>
      </div>
    </div>
    """
  end
end
