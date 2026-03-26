defmodule QuestionnaireCopilotWeb.DashboardLiveTest do
  use QuestionnaireCopilotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias QuestionnaireCopilot.Vault
  alias QuestionnaireCopilot.Questionnaires

  test "renders dashboard with stats", %{conn: conn} do
    {:ok, _} = Vault.create_qa_pair(%{question: "Q?", answer: "A.", tags: ["tag1"]})
    {:ok, q} = Questionnaires.create_questionnaire(%{name: "Test Q"})
    Questionnaires.create_items_from_text(q, "Q1?")

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Dashboard"
    assert html =~ "Vault Pairs"
    assert html =~ "Questionnaires"
    assert html =~ "Continue Working"
    assert html =~ "Test Q"
  end

  test "renders empty dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Dashboard"
    assert html =~ "0"
  end
end
