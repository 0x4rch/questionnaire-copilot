defmodule QuestionnaireCopilotWeb.VaultLiveTest do
  use QuestionnaireCopilotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias QuestionnaireCopilot.Vault

  defp create_pair(_) do
    {:ok, pair} =
      Vault.create_qa_pair(%{
        question: "Do you encrypt data at rest?",
        answer: "Yes, AES-256.",
        tags: ["encryption"],
        source: "SOC2"
      })

    %{pair: pair}
  end

  describe "vault page" do
    test "renders vault page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/vault")
      assert html =~ "Q&amp;A Vault"
    end

    setup [:create_pair]

    test "lists qa pairs", %{conn: conn, pair: pair} do
      {:ok, _view, html} = live(conn, ~p"/vault")
      assert html =~ pair.question
      assert html =~ pair.answer
    end

    test "creates a new qa pair", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/vault")

      view |> element("button", "Add Q&A Pair") |> render_click()
      assert render(view) =~ "New Q&amp;A Pair"

      view
      |> form("[phx-submit=save]", qa_pair: %{question: "New question?", answer: "New answer."})
      |> render_submit()

      assert render(view) =~ "New question?"
      assert render(view) =~ "Q&amp;A pair saved."
    end

    test "deletes a qa pair", %{conn: conn, pair: pair} do
      {:ok, view, _html} = live(conn, ~p"/vault")
      assert render(view) =~ pair.question

      view
      |> element("[phx-click=delete][phx-value-id='#{pair.id}']")
      |> render_click()

      refute render(view) =~ pair.question
    end

    test "searches qa pairs", %{conn: conn, pair: pair} do
      {:ok, view, _html} = live(conn, ~p"/vault")
      assert render(view) =~ pair.question

      view
      |> form("form", %{search: "nonexistent query that matches nothing"})
      |> render_change()

      refute render(view) =~ pair.question
    end

    test "filters by tag", %{conn: conn} do
      {:ok, _} = Vault.create_qa_pair(%{question: "Auth question?", answer: "Auth answer.", tags: ["auth"]})
      {:ok, view, _html} = live(conn, ~p"/vault")

      view |> element("button[phx-value-tag=auth]") |> render_click()
      assert render(view) =~ "Auth question?"
    end
  end
end
