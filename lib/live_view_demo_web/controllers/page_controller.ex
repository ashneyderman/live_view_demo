defmodule LiveViewDemoWeb.PageController do
  use LiveViewDemoWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def tetris(conn, _) do
    conn
    |> put_layout(:game)
    |> live_render(LiveViewDemoWeb.TetrisLive, session: %{})
  end
end
