defmodule PulquexWeb.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  post "/verify" do
    PulquexWeb.Plug.verify_challenge(conn)
  end
end
