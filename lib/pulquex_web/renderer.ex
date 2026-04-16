defmodule PulquexWeb.Renderer do
  @type challenge_assigns :: %{
          salt: String.t(),
          difficulty: non_neg_integer(),
          challenge_id: String.t(),
          redirect_to: String.t(),
          solver_js: String.t()
        }

  @callback render(Plug.Conn.t(), challenge_assigns()) :: Plug.Conn.t()
end
