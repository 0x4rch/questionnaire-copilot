defmodule QuestionnaireCopilotWeb.PageControllerTest do
  use QuestionnaireCopilotWeb.ConnCase

  test "GET / renders dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Dashboard"
  end
end
