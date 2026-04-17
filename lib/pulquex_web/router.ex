defmodule PulquexWeb.Router do
  use Plug.Router
  import Plug.Conn

  plug(:match)
  plug(:dispatch)

  post "/verify" do
    conn
    |> resp(200, "OK")
  end
end
