defmodule QuestionnaireCopilotWeb.ExportController do
  use QuestionnaireCopilotWeb, :controller

  alias QuestionnaireCopilot.Questionnaires
  alias QuestionnaireCopilot.Vault

  def csv(conn, %{"id" => id}) do
    questionnaire = Questionnaires.get_questionnaire!(id)
    csv = Questionnaires.to_csv(questionnaire)

    filename = sanitize_filename(questionnaire.name)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}.csv\"")
    |> send_resp(200, csv)
  end

  defp sanitize_filename(name) do
    name
    |> String.replace(~r/[^\w\s\-.]/, "")
    |> String.trim()
    |> String.slice(0, 100)
  end

  def vault_csv(conn, _params) do
    csv = Vault.to_csv()

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"vault_export.csv\"")
    |> send_resp(200, csv)
  end
end
