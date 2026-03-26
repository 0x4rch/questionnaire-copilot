defmodule QuestionnaireCopilotWeb.VaultLive do
  use QuestionnaireCopilotWeb, :live_view

  alias QuestionnaireCopilot.Vault
  alias QuestionnaireCopilot.Vault.QAPair

  # Mount: called when the LiveView first loads.
  # Initializes all the assigns (state) the template needs.
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search, "")
     |> assign(:active_tags, [])
     |> assign(:all_tags, Vault.all_tags())
     |> assign(:show_all_tags, false)
     |> assign(:qa_pairs, Vault.list_qa_pairs())
     |> assign(:form, to_form(Vault.change_qa_pair(%QAPair{})))
     |> assign(:editing, nil)
     |> assign(:importing, false)
     |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1)}
  end

  # Handle search input — "phx-change" on the search form triggers this.
  # Pattern matching on the event name is how LiveView routes events.
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search, query)
     |> apply_filters()}
  end

  def handle_event("toggle-tag", %{"tag" => tag}, socket) do
    active = socket.assigns.active_tags

    active =
      if tag in active,
        do: List.delete(active, tag),
        else: [tag | active]

    {:noreply,
     socket
     |> assign(:active_tags, active)
     |> apply_filters()}
  end

  def handle_event("clear-tags", _, socket) do
    {:noreply,
     socket
     |> assign(:active_tags, [])
     |> apply_filters()}
  end

  def handle_event("toggle-all-tags", _, socket) do
    {:noreply, assign(socket, :show_all_tags, !socket.assigns.show_all_tags)}
  end

  # Open the form to create a new Q&A pair
  def handle_event("new", _, socket) do
    {:noreply,
     socket
     |> assign(:editing, :new)
     |> assign(:form, to_form(Vault.change_qa_pair(%QAPair{})))}
  end

  # Open the form to edit an existing pair
  def handle_event("edit", %{"id" => id}, socket) do
    qa_pair = Vault.get_qa_pair!(id)

    {:noreply,
     socket
     |> assign(:editing, qa_pair)
     |> assign(:form, to_form(Vault.change_qa_pair(qa_pair)))}
  end

  # Cancel editing — close the form
  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, :editing, nil)}
  end

  # Save: handles both create and update depending on @editing state
  def handle_event("save", %{"qa_pair" => params}, socket) do
    # Tags come in as a comma-separated string, split into a list
    params = Map.update(params, "tags", [], &parse_tags/1)

    result =
      case socket.assigns.editing do
        :new -> Vault.create_qa_pair(params)
        %QAPair{} = qa_pair -> Vault.update_qa_pair(qa_pair, params)
      end

    case result do
      {:ok, _qa_pair} ->
        {:noreply,
         socket
         |> assign(:editing, nil)
         |> reload()
         |> put_flash(:info, "Q&A pair saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Delete a Q&A pair
  def handle_event("delete", %{"id" => id}, socket) do
    qa_pair = Vault.get_qa_pair!(id)
    {:ok, _} = Vault.delete_qa_pair(qa_pair)

    {:noreply,
     socket
     |> assign(:qa_pairs, Vault.search_qa_pairs(socket.assigns.search))
     |> put_flash(:info, "Q&A pair deleted.")}
  end

  # CSV Import
  def handle_event("validate-import", _, socket), do: {:noreply, socket}

  def handle_event("toggle-import", _, socket) do
    {:noreply, assign(socket, :importing, !socket.assigns.importing)}
  end

  def handle_event("import", _, socket) do
    [csv_content] =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case Vault.import_csv(csv_content) do
      {:ok, %{imported: imported, skipped: skipped}} ->
        msg =
          case {imported, skipped} do
            {n, 0} -> "Imported #{n} Q&A pairs."
            {0, s} -> "No new pairs imported (#{s} duplicates skipped)."
            {n, s} -> "Imported #{n} Q&A pairs (#{s} duplicates skipped)."
          end

        {:noreply,
         socket
         |> assign(:importing, false)
         |> reload()
         |> put_flash(:info, msg)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Import failed: #{reason}")}
    end
  end

  defp apply_filters(socket) do
    assign(socket, :qa_pairs, Vault.search_and_filter(socket.assigns.search, socket.assigns.active_tags))
  end

  defp reload(socket) do
    socket
    |> assign(:all_tags, Vault.all_tags())
    |> apply_filters()
  end

  # Parse "encryption, access-control" into ["encryption", "access-control"]
  defp parse_tags(tags) when is_binary(tags) do
    tags |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp parse_tags(tags), do: tags

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted (use .csv)"
  defp error_to_string(:too_many_files), do: "Only one file allowed"

  # The render callback — returns the HEEx template.
  # ~H is a sigil that compiles HEEx (HTML + Elixir Expressions) at compile time.
  def render(assigns) do
    ~H"""
    <.header>
      Q&A Vault
      <:subtitle>Your library of approved security questionnaire answers</:subtitle>
      <:actions>
        <div class="flex gap-2">
          <a href={~p"/vault/export"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-down-tray" class="size-4" /> Export
          </a>
          <button class="btn btn-ghost btn-sm" phx-click="toggle-import">
            <.icon name="hero-arrow-up-tray" class="size-4" /> Import CSV
          </button>
          <button class="btn btn-primary" phx-click="new">
            <.icon name="hero-plus" class="size-4" /> Add Q&A Pair
          </button>
        </div>
      </:actions>
    </.header>

    <%!-- CSV Import --%>
    <div :if={@importing} class="card bg-base-100 shadow-sm mb-6">
      <div class="card-body">
        <h2 class="card-title text-base">Import Q&A Pairs from CSV</h2>
        <p class="text-sm text-base-content/60 mb-2">
          CSV should have columns: <code>question, answer, tags, source</code>.
          Tags should be semicolon-separated (e.g. <code>encryption;access-control</code>).
        </p>
        <form id="import-form" phx-submit="import" phx-change="validate-import" phx-drop-target={@uploads.csv.ref}>
          <div class="border-2 border-dashed border-base-300 rounded-lg p-10 text-center hover:border-primary transition-colors cursor-pointer"
               phx-drop-target={@uploads.csv.ref}>
            <div :if={@uploads.csv.entries == []}>
              <.icon name="hero-arrow-up-tray" class="size-8 mx-auto text-base-content/30 mb-3" />
              <p class="text-base-content/50 mb-2">Drag & drop a CSV file here, or</p>
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
          <div class="flex justify-end gap-2 mt-4">
            <button type="button" class="btn btn-ghost" phx-click="toggle-import">Cancel</button>
            <button type="submit" class="btn btn-primary" disabled={@uploads.csv.entries == []}>
              <.icon name="hero-arrow-up-tray" class="size-4" /> Import
            </button>
          </div>
        </form>
      </div>
    </div>

    <%!-- Search bar --%>
    <form phx-change="search" class="mb-4">
      <label class="input input-bordered flex items-center gap-2 w-full">
        <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search questions and answers..."
          class="grow border-0 bg-transparent focus:outline-none"
          phx-debounce="300"
        />
      </label>
    </form>

    <%!-- Tag filter bar --%>
    <% visible_tags = if @show_all_tags, do: @all_tags, else: Enum.take(@all_tags, 8) %>
    <% hidden_count = length(@all_tags) - 8 %>
    <div class="flex flex-wrap gap-1.5 mb-6 items-center">
      <button
        :for={{tag, count} <- visible_tags}
        class={[
          "badge badge-sm cursor-pointer transition-colors",
          if(tag in @active_tags,
            do: "badge-primary",
            else: "bg-base-300/50 text-base-content/60 hover:text-base-content border-0")
        ]}
        phx-click="toggle-tag"
        phx-value-tag={tag}
      >
        {tag}
        <span class="opacity-40 ml-0.5">{count}</span>
      </button>
      <button
        :if={hidden_count > 0 && !@show_all_tags}
        class="text-xs text-base-content/40 hover:text-base-content/60 cursor-pointer ml-1"
        phx-click="toggle-all-tags"
      >
        +{hidden_count} more
      </button>
      <button
        :if={@show_all_tags && hidden_count > 0}
        class="text-xs text-base-content/40 hover:text-base-content/60 cursor-pointer ml-1"
        phx-click="toggle-all-tags"
      >
        show less
      </button>
      <button
        :if={@active_tags != []}
        class="badge badge-sm badge-ghost cursor-pointer ml-1"
        phx-click="clear-tags"
      >
        <.icon name="hero-x-mark" class="size-3" /> Clear
      </button>
    </div>

    <%!-- Add/Edit form --%>
    <div :if={@editing} class="card bg-base-100 shadow-sm mb-6">
      <div class="card-body">
        <h2 class="card-title text-base">
          {if @editing == :new, do: "New Q&A Pair", else: "Edit Q&A Pair"}
        </h2>
        <.form for={@form} phx-submit="save" class="space-y-2">
          <.input field={@form[:question]} type="textarea" label="Question" required />
          <.input field={@form[:answer]} type="textarea" label="Answer" required />
          <.input
            field={@form[:tags]}
            type="text"
            label="Tags (comma-separated)"
            value={(@form[:tags].value || []) |> Enum.join(", ")}
          />
          <.input field={@form[:source]} type="text" label="Source" placeholder="e.g. SOC2 2024" />
          <div class="flex justify-end gap-2 pt-2">
            <button type="button" class="btn btn-ghost" phx-click="cancel">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </.form>
      </div>
    </div>

    <%!-- Empty state --%>
    <div :if={@qa_pairs == []} class="text-center py-16">
      <.icon name="hero-archive-box" class="size-12 mx-auto text-base-content/20 mb-4" />
      <p class="text-base-content/50">No Q&A pairs yet. Click "Add Q&A Pair" to get started.</p>
    </div>

    <%!-- Q&A pairs list --%>
    <div class="space-y-3">
      <div :for={qa <- @qa_pairs} class="card bg-base-100 shadow-sm">
        <div class="card-body p-5">
          <div class="flex items-start justify-between gap-4">
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold">{qa.question}</h3>
              <p class="mt-2 text-sm text-base-content/70 whitespace-pre-wrap">{qa.answer}</p>
              <div class="flex flex-wrap gap-1.5 mt-3">
                <span
                  :for={tag <- qa.tags}
                  class={[
                    "badge badge-sm cursor-pointer transition-colors",
                    if(tag in @active_tags, do: "badge-primary", else: "bg-base-300/50 text-base-content/60 hover:text-base-content border-0")
                  ]}
                  phx-click="toggle-tag"
                  phx-value-tag={tag}
                >{tag}</span>
                <span :if={qa.source} class="badge badge-ghost badge-sm">
                  <.icon name="hero-document-text" class="size-3" /> {qa.source}
                </span>
              </div>
            </div>
            <div class="flex gap-1 shrink-0">
              <button class="btn btn-ghost btn-sm btn-square" phx-click="edit" phx-value-id={qa.id}>
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
              <button
                class="btn btn-ghost btn-sm btn-square text-error"
                phx-click="delete"
                phx-value-id={qa.id}
                data-confirm="Are you sure?"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
