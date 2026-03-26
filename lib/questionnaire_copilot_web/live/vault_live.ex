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
     |> assign(:qa_pairs, Vault.list_qa_pairs())
     |> assign(:form, to_form(Vault.change_qa_pair(%QAPair{})))
     |> assign(:editing, nil)}
  end

  # Handle search input — "phx-change" on the search form triggers this.
  # Pattern matching on the event name is how LiveView routes events.
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search, query)
     |> assign(:qa_pairs, Vault.search_qa_pairs(query))}
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
         |> assign(:qa_pairs, Vault.search_qa_pairs(socket.assigns.search))
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

  # Parse "encryption, access-control" into ["encryption", "access-control"]
  defp parse_tags(tags) when is_binary(tags) do
    tags |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp parse_tags(tags), do: tags

  # The render callback — returns the HEEx template.
  # ~H is a sigil that compiles HEEx (HTML + Elixir Expressions) at compile time.
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <.header>
        Q&A Vault
        <:subtitle>Your library of approved security questionnaire answers</:subtitle>
        <:actions>
          <button class="btn btn-primary" phx-click="new">
            <.icon name="hero-plus" class="size-4" /> Add Q&A Pair
          </button>
        </:actions>
      </.header>

      <%!-- Search bar --%>
      <form phx-change="search" class="mb-6">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search questions and answers..."
          class="input input-bordered w-full"
          phx-debounce="300"
        />
      </form>

      <%!-- Add/Edit form — shown when @editing is not nil --%>
      <div :if={@editing} class="card bg-base-200 mb-6">
        <div class="card-body">
          <h2 class="card-title">
            {if @editing == :new, do: "New Q&A Pair", else: "Edit Q&A Pair"}
          </h2>
          <.form for={@form} phx-submit="save">
            <.input field={@form[:question]} type="textarea" label="Question" required />
            <.input field={@form[:answer]} type="textarea" label="Answer" required />
            <.input
              field={@form[:tags]}
              type="text"
              label="Tags (comma-separated)"
              value={(@form[:tags].value || []) |> Enum.join(", ")}
            />
            <.input field={@form[:source]} type="text" label="Source" placeholder="e.g. SOC2 2024" />
            <div class="card-actions justify-end mt-4">
              <button type="button" class="btn" phx-click="cancel">Cancel</button>
              <button type="submit" class="btn btn-primary">Save</button>
            </div>
          </.form>
        </div>
      </div>

      <%!-- Q&A pairs list --%>
      <div :if={@qa_pairs == []} class="text-center py-12 text-base-content/50">
        No Q&A pairs yet. Click "Add Q&A Pair" to get started.
      </div>

      <div :for={qa <- @qa_pairs} class="card bg-base-100 shadow-sm mb-4">
        <div class="card-body">
          <h3 class="card-title text-base">{qa.question}</h3>
          <p class="whitespace-pre-wrap">{qa.answer}</p>
          <div class="flex flex-wrap gap-2 mt-2">
            <span :for={tag <- qa.tags} class="badge badge-outline badge-sm">{tag}</span>
            <span :if={qa.source} class="badge badge-ghost badge-sm">{qa.source}</span>
          </div>
          <div class="card-actions justify-end">
            <button class="btn btn-ghost btn-sm" phx-click="edit" phx-value-id={qa.id}>
              <.icon name="hero-pencil-square" class="size-4" /> Edit
            </button>
            <button
              class="btn btn-ghost btn-sm text-error"
              phx-click="delete"
              phx-value-id={qa.id}
              data-confirm="Are you sure?"
            >
              <.icon name="hero-trash" class="size-4" /> Delete
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
