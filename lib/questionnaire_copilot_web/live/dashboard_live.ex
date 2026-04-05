defmodule QuestionnaireCopilotWeb.DashboardLive do
  use QuestionnaireCopilotWeb, :live_view

  alias QuestionnaireCopilot.Vault
  alias QuestionnaireCopilot.Questionnaires

  def mount(_params, _session, socket) do
    qa_pairs = Vault.list_qa_pairs()
    questionnaires = Questionnaires.list_questionnaires()
    tags = Vault.all_tags()

    in_progress =
      Enum.filter(questionnaires, &(&1.status == :in_progress))

    completed =
      Enum.filter(questionnaires, &(&1.status == :completed))

    {:ok,
     socket
     |> assign(:qa_count, length(qa_pairs))
     |> assign(:tag_count, length(tags))
     |> assign(:questionnaire_count, length(questionnaires))
     |> assign(:in_progress, in_progress)
     |> assign(:completed_count, length(completed))
     |> assign(:recent_pairs, Enum.take(qa_pairs, 5))}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Header --%>
      <div>
        <h1 class="text-2xl font-bold">Dashboard</h1>
        <p class="text-base-content/50 mt-1">Overview of your questionnaire workflow</p>
      </div>

      <%!-- Stats --%>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <.link
          navigate={~p"/vault"}
          class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow cursor-pointer"
        >
          <div class="card-body p-5">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-base-content/50">Vault Pairs</p>
                <p class="text-3xl font-bold mt-1">{@qa_count}</p>
              </div>
              <div class="bg-primary/10 rounded-lg p-3">
                <.icon name="hero-archive-box" class="size-6 text-primary" />
              </div>
            </div>
            <p class="text-xs text-base-content/40 mt-2">{@tag_count} tags</p>
          </div>
        </.link>

        <.link
          navigate={~p"/questionnaires"}
          class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow cursor-pointer"
        >
          <div class="card-body p-5">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-base-content/50">Questionnaires</p>
                <p class="text-3xl font-bold mt-1">{@questionnaire_count}</p>
              </div>
              <div class="bg-primary/10 rounded-lg p-3">
                <.icon name="hero-clipboard-document-list" class="size-6 text-primary" />
              </div>
            </div>
            <p class="text-xs text-base-content/40 mt-2">{@completed_count} completed</p>
          </div>
        </.link>

        <div class="card bg-base-100 shadow-sm">
          <div class="card-body p-5">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-base-content/50">In Progress</p>
                <p class="text-3xl font-bold mt-1">{length(@in_progress)}</p>
              </div>
              <div class="bg-warning/10 rounded-lg p-3">
                <.icon name="hero-clock" class="size-6 text-warning" />
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- In progress questionnaires --%>
      <div :if={@in_progress != []}>
        <h2 class="font-semibold mb-3">Continue Working</h2>
        <div class="space-y-3">
          <.link
            :for={q <- @in_progress}
            navigate={~p"/questionnaires/#{q.id}"}
            class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow block"
          >
            <div class="card-body p-4 flex-row items-center justify-between">
              <div>
                <p class="font-medium">{q.name}</p>
              </div>
              <div class="btn btn-sm btn-primary">
                <.icon name="hero-play" class="size-4" /> Resume
              </div>
            </div>
          </.link>
        </div>
      </div>

      <%!-- Quick actions --%>
      <div>
        <h2 class="font-semibold mb-3">Quick Actions</h2>
        <div class="flex flex-wrap gap-3">
          <.link navigate={~p"/vault"} class="btn btn-outline btn-sm">
            <.icon name="hero-plus" class="size-4" /> Add Q&A Pair
          </.link>
          <.link navigate={~p"/questionnaires"} class="btn btn-outline btn-sm">
            <.icon name="hero-clipboard-document-list" class="size-4" /> New Questionnaire
          </.link>
        </div>
      </div>

      <%!-- Recent vault additions --%>
      <div :if={@recent_pairs != []}>
        <div class="flex items-center justify-between mb-3">
          <h2 class="font-semibold">Recent Vault Additions</h2>
          <.link navigate={~p"/vault"} class="text-sm text-primary hover:underline">View all</.link>
        </div>
        <div class="space-y-2">
          <div :for={qa <- @recent_pairs} class="card bg-base-100 shadow-sm">
            <div class="card-body p-4">
              <p class="font-medium text-sm">{qa.question}</p>
              <p class="text-xs text-base-content/50 line-clamp-1">{qa.answer}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
