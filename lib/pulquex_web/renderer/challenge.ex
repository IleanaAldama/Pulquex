defmodule PulquexWeb.Renderer.Challenge do
  require EEx

  @template Path.join(__DIR__, "templates/challenge.html.eex")

  EEx.function_from_file(:def, :render, @template, [:assigns])
end
