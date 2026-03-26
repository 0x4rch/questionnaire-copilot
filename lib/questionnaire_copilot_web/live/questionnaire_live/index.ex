defmodule QuestionnaireCopilotWeb.QuestionnaireLive.Index do
  use QuestionnaireCopilotWeb, :live_view

  alias QuestionnaireCopilot.Questionnaires
  alias QuestionnaireCopilot.Questionnaires.Questionnaire

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:questionnaires, Questionnaires.list_questionnaires())
     |> assign(:form, to_form(Questionnaires.change_questionnaire(%Questionnaire{})))
     |> assign(:creating, false)
     |> assign(:input_mode, :text)
     |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1, max_file_size: 10_000_000)}
  end

  def handle_event("toggle-form", _, socket) do
    {:noreply,
     socket
     |> assign(:creating, !socket.assigns.creating)
     |> assign(:input_mode, :text)}
  end

  def handle_event("set-mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :input_mode, String.to_existing_atom(mode))}
  end

  def handle_event("validate-upload", _, socket), do: {:noreply, socket}

  def handle_event("create", %{"questionnaire" => params}, socket) do
    {questions_text, params} = Map.pop(params, "questions_text", "")

    # If CSV mode, read the uploaded file
    csv_questions =
      if socket.assigns.input_mode == :csv do
        consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
          {:ok, File.read!(path)}
        end)
        |> List.first()
        |> parse_questions_csv()
      else
        nil
      end

    case Questionnaires.create_questionnaire(params) do
      {:ok, questionnaire} ->
        if csv_questions do
          Questionnaires.create_items_from_list(questionnaire, csv_questions)
        else
          Questionnaires.create_items_from_text(questionnaire, questions_text)
        end

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

  # Parse CSV — expects a "question" column, ignores others
  defp parse_questions_csv(nil), do: []

  defp parse_questions_csv(csv_string) do
    lines =
      csv_string
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [] -> []
      [header | rows] ->
        columns = header |> String.downcase() |> String.split(",") |> Enum.map(&String.trim/1)
        q_index = Enum.find_index(columns, &(&1 == "question"))

        if q_index do
          Enum.map(rows, fn row ->
            row
            |> parse_csv_row()
            |> Enum.at(q_index, "")
            |> String.trim()
          end)
          |> Enum.reject(&(&1 == ""))
        else
          # No header match — treat each row as a question
          rows
        end
    end
  end

  defp parse_csv_row(row) do
    row
    |> String.graphemes()
    |> parse_fields([], "", false)
    |> Enum.reverse()
  end

  defp parse_fields([], acc, current, _in_quotes), do: [String.trim(current) | acc]
  defp parse_fields(["\"" | rest], acc, current, false), do: parse_fields(rest, acc, current, true)
  defp parse_fields(["\"", "\"" | rest], acc, current, true), do: parse_fields(rest, acc, current <> "\"", true)
  defp parse_fields(["\"" | rest], acc, current, true), do: parse_fields(rest, acc, current, false)
  defp parse_fields(["," | rest], acc, current, false), do: parse_fields(rest, [String.trim(current) | acc], "", false)
  defp parse_fields([char | rest], acc, current, in_quotes), do: parse_fields(rest, acc, current <> char, in_quotes)

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "Use a .csv file"
  defp error_to_string(:too_many_files), do: "Only one file"

  def render(assigns) do
    ~H"""
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
    <div :if={@creating} class="card bg-base-100 shadow-sm mb-6">
      <div class="card-body">
        <h2 class="card-title text-base">New Questionnaire</h2>
        <.form for={@form} phx-submit="create" phx-change="validate-upload" class="space-y-2">
          <.input field={@form[:name]} type="text" label="Name" placeholder="e.g. Acme Corp Security Assessment Q1 2025" required />

          <%!-- Tab toggle --%>
          <div class="tabs tabs-boxed w-fit">
            <button type="button" class={["tab", @input_mode == :text && "tab-active"]} phx-click="set-mode" phx-value-mode="text">
              Paste Text
            </button>
            <button type="button" class={["tab", @input_mode == :csv && "tab-active"]} phx-click="set-mode" phx-value-mode="csv">
              Upload CSV
            </button>
          </div>

          <%!-- Text input --%>
          <div :if={@input_mode == :text} class="fieldset mb-2">
            <label>
              <span class="label mb-1">Questions (one per line)</span>
              <textarea
                name="questionnaire[questions_text]"
                class="textarea textarea-bordered w-full h-48 font-mono text-sm"
                placeholder="Do you encrypt data at rest?&#10;How do you handle incident response?&#10;What is your password policy?"
              ></textarea>
            </label>
          </div>

          <%!-- CSV upload --%>
          <div :if={@input_mode == :csv}>
            <span class="label mb-1">CSV file with a "question" column</span>
            <div
              class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors"
              phx-drop-target={@uploads.csv.ref}
            >
              <div :if={@uploads.csv.entries == []}>
                <.icon name="hero-arrow-up-tray" class="size-8 mx-auto text-base-content/30 mb-3" />
                <p class="text-base-content/50 mb-2">Drag & drop a CSV file, or</p>
                <label for={@uploads.csv.ref} class="btn btn-sm btn-outline cursor-pointer">
                  Browse files
                </label>
              </div>
              <div :for={entry <- @uploads.csv.entries} class="flex items-center justify-center gap-3">
                <.icon name="hero-document-text" class="size-6 text-primary" />
                <span class="font-medium">{entry.client_name}</span>
                <span class="text-sm text-base-content/50">({Float.round(entry.client_size / 1024, 1)} KB)</span>
                <span :for={err <- upload_errors(@uploads.csv, entry)} class="badge badge-error badge-sm">
                  {error_to_string(err)}
                </span>
              </div>
              <.live_file_input upload={@uploads.csv} class="hidden" />
            </div>
          </div>

          <div class="flex justify-end gap-2 pt-2">
            <button type="button" class="btn btn-ghost" phx-click="toggle-form">Cancel</button>
            <button type="submit" class="btn btn-primary">Create</button>
          </div>
        </.form>
      </div>
    </div>

    <%!-- Empty state --%>
    <div :if={@questionnaires == []} class="text-center py-16">
      <.icon name="hero-clipboard-document-list" class="size-12 mx-auto text-base-content/20 mb-4" />
      <p class="text-base-content/50">No questionnaires yet. Click "New Questionnaire" to import one.</p>
    </div>

    <%!-- Questionnaire list --%>
    <div class="space-y-3">
      <div :for={q <- @questionnaires} class="card bg-base-100 shadow-sm">
        <div class="card-body p-5 flex-row items-center justify-between">
          <div>
            <.link navigate={~p"/questionnaires/#{q.id}"} class="font-semibold link link-hover">
              {q.name}
            </.link>
            <div class="flex gap-2 mt-1.5">
              <span class={[
                "badge badge-sm",
                q.status == :completed && "badge-success",
                q.status == :in_progress && "badge-warning"
              ]}>
                {if q.status == :in_progress, do: "In Progress", else: "Completed"}
              </span>
              <span class="text-xs text-base-content/40">{q.item_count} questions</span>
            </div>
          </div>
          <div class="flex gap-2 shrink-0">
            <.link navigate={~p"/questionnaires/#{q.id}"} class="btn btn-sm btn-primary">
              <.icon name="hero-play" class="size-4" /> Open
            </.link>
            <button
              class="btn btn-ghost btn-sm btn-square text-error"
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
