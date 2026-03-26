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
    {:ok, questionnaire} = Questionnaires.maybe_mark_completed(questionnaire)
    questionnaire = Questionnaires.get_questionnaire!(questionnaire.id)
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
    <div phx-window-keydown="keydown">
      <%!-- Header with progress --%>
      <div class="flex items-center justify-between mb-2">
        <div>
          <h1 class="text-lg font-semibold">{@questionnaire.name}</h1>
          <p class="text-sm text-base-content/50 mt-0.5">
            {@done} of {@total} complete
            <span :if={@total > 0} class="text-base-content/30">
              ({trunc(@done / max(@total, 1) * 100)}%)
            </span>
          </p>
        </div>
        <div class="flex gap-2">
          <a href={~p"/questionnaires/#{@questionnaire.id}/export"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-down-tray" class="size-4" /> Export
          </a>
          <.link navigate={~p"/questionnaires"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.link>
        </div>
      </div>

      <progress class="progress progress-primary w-full mb-6" value={@done} max={@total}></progress>

      <div :if={@current} class="grid grid-cols-1 lg:grid-cols-5 gap-6">
        <%!-- Left panel: current question (3/5 width) --%>
        <div class="lg:col-span-3 space-y-4">
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <span class="text-xs font-mono text-base-content/40">
                  Q{@current_index + 1}/{@total}
                </span>
                <span class={[
                  "badge badge-sm",
                  @current.status == :answered && "badge-success",
                  @current.status == :skipped && "badge-warning",
                  @current.status in [:unmatched, :matched] && "badge-ghost"
                ]}>
                  {Phoenix.Naming.humanize(@current.status)}
                </span>
              </div>
              <h2 class="text-lg font-medium mt-2">{@current.original_question}</h2>

              <%!-- Existing answer --%>
              <div :if={@current.final_answer} class="mt-4 p-4 bg-base-200 rounded-lg">
                <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40 mb-2">Current Answer</p>
                <p class="whitespace-pre-wrap text-sm">{@current.final_answer}</p>
              </div>

              <%!-- Manual answer editor --%>
              <div :if={@editing_answer} class="mt-4">
                <form phx-submit="save-answer">
                  <textarea
                    name="answer"
                    class="textarea textarea-bordered w-full h-32"
                    placeholder="Type your answer..."
                  >{@manual_answer}</textarea>
                  <div class="flex gap-2 mt-3 justify-end">
                    <button type="button" class="btn btn-sm btn-ghost" phx-click="goto" phx-value-index={@current_index}>
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-sm btn-primary">Save Answer</button>
                  </div>
                </form>
              </div>

              <%!-- Action buttons --%>
              <div :if={!@editing_answer} class="flex gap-2 mt-4">
                <button class="btn btn-sm btn-ghost" phx-click="manual">
                  <.icon name="hero-pencil" class="size-4" /> Write Answer
                </button>
                <div class="flex-1" />
                <button class="btn btn-sm btn-ghost" phx-click="skip">
                  Skip
                  <kbd class="kbd kbd-xs ml-1">s</kbd>
                </button>
              </div>
            </div>
          </div>

          <%!-- Question navigator --%>
          <div class="card bg-base-100 shadow-sm p-4">
            <div class="flex flex-wrap gap-1">
              <button
                :for={{item, idx} <- Enum.with_index(@items)}
                class={[
                  "btn btn-xs",
                  idx == @current_index && "btn-primary",
                  idx != @current_index && item.status == :answered && "btn-success btn-outline",
                  idx != @current_index && item.status == :skipped && "btn-warning btn-outline",
                  idx != @current_index && item.status in [:unmatched, :matched] && "btn-ghost"
                ]}
                phx-click="goto"
                phx-value-index={idx}
              >
                {idx + 1}
              </button>
            </div>
            <p class="text-xs text-base-content/30 mt-2">
              <kbd class="kbd kbd-xs">j</kbd>/<kbd class="kbd kbd-xs">k</kbd> navigate
              <span class="mx-1">&middot;</span>
              <kbd class="kbd kbd-xs">s</kbd> skip
            </p>
          </div>
        </div>

        <%!-- Right panel: suggested matches (2/5 width) --%>
        <div :if={@current.status in [:unmatched, :matched]} class="lg:col-span-2">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-base-content/50 mb-3">
            Suggested Matches
          </h3>
          <div :if={@matches == []} class="card bg-base-100 shadow-sm p-8 text-center">
            <.icon name="hero-magnifying-glass" class="size-8 mx-auto text-base-content/20 mb-2" />
            <p class="text-sm text-base-content/40">No matches found in vault</p>
          </div>
          <div class="space-y-3">
            <div :for={match <- Enum.take(@matches, 5)} class="card bg-base-100 shadow-sm">
              <div class="card-body p-4">
                <p class="font-medium text-sm">{match.question}</p>
                <p class="text-xs text-base-content/60 whitespace-pre-wrap mt-1.5 line-clamp-4">{match.answer}</p>
                <div :if={match.tags != []} class="flex flex-wrap gap-1 mt-2">
                  <span :for={tag <- match.tags} class="badge badge-primary badge-outline badge-xs">{tag}</span>
                </div>
                <div class="flex gap-2 mt-3">
                  <button class="btn btn-xs btn-primary flex-1" phx-click="accept" phx-value-qa-id={match.id}>
                    Accept
                  </button>
                  <button class="btn btn-xs btn-ghost flex-1" phx-click="accept-edit" phx-value-qa-id={match.id}>
                    Accept & Edit
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- All done state --%>
      <div :if={!@current} class="text-center py-16">
        <.icon name="hero-check-circle" class="size-16 mx-auto text-success mb-4" />
        <h2 class="text-xl font-semibold mb-2">All done!</h2>
        <p class="text-base-content/60 mb-6">All questions have been answered or skipped.</p>
        <div class="flex gap-3 justify-center">
          <a href={~p"/questionnaires/#{@questionnaire.id}/export"} class="btn btn-primary">
            <.icon name="hero-arrow-down-tray" class="size-4" /> Export CSV
          </a>
          <.link navigate={~p"/questionnaires"} class="btn btn-ghost">
            Back to Questionnaires
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
