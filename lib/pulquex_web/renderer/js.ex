defmodule PulquexWeb.Renderer.JS do
  require EEx
  @template Path.join(__DIR__, "templates/js.html.eex")

  EEx.function_from_file(:def, :render, @template, [
    :salt,
    :difficulty,
    :challenge_id,
    :redirect_to
  ])
end
