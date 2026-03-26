defmodule QuestionnaireCopilotWeb.PageController do
  use QuestionnaireCopilotWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
