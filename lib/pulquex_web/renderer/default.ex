defmodule PulquexWeb.Renderer.Default do
  @behaviour PulquexWeb.Renderer

  @impl true
  def render(conn, assigns) do
    html = PulquexWeb.Renderer.Challenge.render(assigns)

    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, html)
    |> Plug.Conn.halt()
  end
end
