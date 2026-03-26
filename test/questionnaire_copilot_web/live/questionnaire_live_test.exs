defmodule QuestionnaireCopilotWeb.QuestionnaireLiveTest do
  use QuestionnaireCopilotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias QuestionnaireCopilot.Questionnaires
  alias QuestionnaireCopilot.Vault

  defp create_questionnaire_with_items(_) do
    {:ok, q} = Questionnaires.create_questionnaire(%{name: "Test Assessment"})
    Questionnaires.create_items_from_text(q, "Do you encrypt data?\nWhat is your password policy?")
    q = Questionnaires.get_questionnaire!(q.id)
    %{questionnaire: q}
  end

  describe "index page" do
    test "renders questionnaires page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/questionnaires")
      assert html =~ "Questionnaires"
    end

    test "creates a questionnaire from text", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/questionnaires")

      view |> element("button", "New Questionnaire") |> render_click()

      view
      |> form("form",
        questionnaire: %{name: "New Assessment"},
        "questionnaire[questions_text]": "Q1?\nQ2?\nQ3?"
      )
      |> render_submit()

      assert render(view) =~ "New Assessment"
      assert render(view) =~ "Questionnaire created."
    end

    setup [:create_questionnaire_with_items]

    test "lists questionnaires with item count", %{conn: conn, questionnaire: q} do
      {:ok, _view, html} = live(conn, ~p"/questionnaires")
      assert html =~ q.name
      assert html =~ "2 questions"
    end

    test "deletes a questionnaire", %{conn: conn, questionnaire: q} do
      {:ok, view, _html} = live(conn, ~p"/questionnaires")
      assert render(view) =~ q.name

      view
      |> element("[phx-click=delete][phx-value-id='#{q.id}']")
      |> render_click()

      refute render(view) =~ q.name
    end
  end

  describe "show page" do
    setup [:create_questionnaire_with_items]

    test "renders questionnaire with first question", %{conn: conn, questionnaire: q} do
      {:ok, _view, html} = live(conn, ~p"/questionnaires/#{q.id}")
      assert html =~ q.name
      assert html =~ "Do you encrypt data?"
      assert html =~ "Q1/2"
    end

    test "navigating with goto changes question", %{conn: conn, questionnaire: q} do
      {:ok, view, _html} = live(conn, ~p"/questionnaires/#{q.id}")
      assert render(view) =~ "Do you encrypt data?"

      view |> element("[phx-value-index='1']") |> render_click()
      assert render(view) =~ "What is your password policy?"
    end

    test "skipping a question advances", %{conn: conn, questionnaire: q} do
      {:ok, view, _html} = live(conn, ~p"/questionnaires/#{q.id}")
      view |> element("button", "Skip") |> render_click()
      # Should advance to next unanswered
      assert render(view) =~ "What is your password policy?"
    end

    test "accepting a vault match answers the question", %{conn: conn, questionnaire: q} do
      {:ok, pair} =
        Vault.create_qa_pair(%{
          question: "Do you encrypt data at rest?",
          answer: "Yes, AES-256.",
          tags: ["encryption"]
        })

      {:ok, view, _html} = live(conn, ~p"/questionnaires/#{q.id}")

      view
      |> element("[phx-click=accept][phx-value-qa-id='#{pair.id}']")
      |> render_click()

      # Should advance to next question
      assert render(view) =~ "What is your password policy?"
    end

    test "manual answer saves correctly", %{conn: conn, questionnaire: q} do
      {:ok, view, _html} = live(conn, ~p"/questionnaires/#{q.id}")

      view |> element("button", "Write Answer") |> render_click()

      view
      |> form("[phx-submit=save-answer]", answer: "Manual answer here.")
      |> render_submit()

      # Reload and check
      updated = Questionnaires.get_questionnaire!(q.id)
      item = hd(updated.items)
      assert item.final_answer == "Manual answer here."
      assert item.status == :answered
    end
  end
end
