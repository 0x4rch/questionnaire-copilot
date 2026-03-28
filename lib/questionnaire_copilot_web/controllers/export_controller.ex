defmodule QuestionnaireCopilotWeb.ExportController do
  use QuestionnaireCopilotWeb, :controller

  alias QuestionnaireCopilot.DataStore

  def csv(conn, %{"id" => id}) do
    store = build_store(conn)
    questionnaire = DataStore.get_questionnaire!(store, id)
    csv = DataStore.questionnaire_to_csv(store, questionnaire)

    filename = sanitize_filename(questionnaire.name)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}.csv\"")
    |> send_resp(200, csv)
  end

  def vault_csv(conn, _params) do
    store = build_store(conn)
    csv = DataStore.vault_to_csv(store)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"vault_export.csv\"")
    |> send_resp(200, csv)
  end

  defp build_store(conn) do
    if QuestionnaireCopilot.Demo.enabled?() do
      {:demo, get_session(conn, :demo_session_id)}
    else
      :db
    end
  end

  defp sanitize_filename(name) do
    name
    |> String.replace(~r/[^\w\s\-.]/, "")
    |> String.trim()
    |> String.slice(0, 100)
  end
end
