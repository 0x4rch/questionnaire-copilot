defmodule QuestionnaireCopilotWeb.QuestionnaireLive.Index do
  use QuestionnaireCopilotWeb, :live_view

  alias QuestionnaireCopilot.Questionnaires
  alias QuestionnaireCopilot.Questionnaires.Questionnaire

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:questionnaires, Questionnaires.list_questionnaires())
     |> assign(:form, to_form(Questionnaires.change_questionnaire(%Questionnaire{})))
     |> assign(:creating, false)}
  end

  def handle_event("toggle-form", _, socket) do
    {:noreply, assign(socket, :creating, !socket.assigns.creating)}
  end

  def handle_event("create", %{"questionnaire" => params}, socket) do
    {questions_text, params} = Map.pop(params, "questions_text", "")

    case Questionnaires.create_questionnaire(params) do
      {:ok, questionnaire} ->
        Questionnaires.create_items_from_text(questionnaire, questions_text)

        {:noreply,
         socket
         |> assign(:creating, false)
         |> assign(:questionnaires, Questionnaires.list_questionnaires())
         |> put_flash(:info, "Questionnaire created.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    questionnaire = Questionnaires.get_questionnaire!(id)
    {:ok, _} = Questionnaires.delete_questionnaire(questionnaire)

    {:noreply,
     socket
     |> assign(:questionnaires, Questionnaires.list_questionnaires())
     |> put_flash(:info, "Questionnaire deleted.")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <.header>
        Questionnaires
        <:subtitle>Import and work through vendor security questionnaires</:subtitle>
        <:actions>
          <button class="btn btn-primary" phx-click="toggle-form">
            <.icon name="hero-plus" class="size-4" /> New Questionnaire
          </button>
        </:actions>
      </.header>

      <%!-- Create form --%>
      <div :if={@creating} class="card bg-base-200 mb-6">
        <div class="card-body">
          <h2 class="card-title">New Questionnaire</h2>
          <.form for={@form} phx-submit="create">
            <.input field={@form[:name]} type="text" label="Name" placeholder="e.g. Acme Corp Security Assessment Q1 2025" required />
            <div class="fieldset mb-2">
              <label>
                <span class="label mb-1">Questions (one per line)</span>
                <textarea
                  name="questionnaire[questions_text]"
                  class="textarea textarea-bordered w-full h-48"
                  placeholder="Do you encrypt data at rest?&#10;How do you handle incident response?&#10;What is your password policy?"
                  required
                ></textarea>
              </label>
            </div>
            <div class="card-actions justify-end mt-4">
              <button type="button" class="btn" phx-click="toggle-form">Cancel</button>
              <button type="submit" class="btn btn-primary">Create</button>
            </div>
          </.form>
        </div>
      </div>

      <%!-- Questionnaire list --%>
      <div :if={@questionnaires == []} class="text-center py-12 text-base-content/50">
        No questionnaires yet. Click "New Questionnaire" to import one.
      </div>

      <div :for={q <- @questionnaires} class="card bg-base-100 shadow-sm mb-4">
        <div class="card-body flex-row items-center justify-between">
          <div>
            <.link navigate={~p"/questionnaires/#{q.id}"} class="card-title text-base link link-hover">
              {q.name}
            </.link>
            <div class="flex gap-2 mt-1">
              <span class={[
                "badge badge-sm",
                q.status == :completed && "badge-success",
                q.status == :in_progress && "badge-warning"
              ]}>
                {q.status}
              </span>
            </div>
          </div>
          <div class="flex gap-2">
            <.link navigate={~p"/questionnaires/#{q.id}"} class="btn btn-sm btn-primary">
              Open
            </.link>
            <button
              class="btn btn-ghost btn-sm text-error"
              phx-click="delete"
              phx-value-id={q.id}
              data-confirm="Delete this questionnaire and all its items?"
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
