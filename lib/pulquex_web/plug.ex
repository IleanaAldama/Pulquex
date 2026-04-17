defmodule PulquexWeb.Plug do
  @behaviour Plug

  import Plug.Conn
  require Logger

  @cookie "pulquex-token"
  @verify_path "/_pulquex/verify"

  @impl true
  def init(opts) do
    %{
      difficulty: Keyword.get(opts, :difficulty, 4),
      ttl: Keyword.get(opts, :ttl, 3600),
      secret: Keyword.fetch!(opts, :secret),
      exempt: Keyword.get(opts, :exempt, []),
      renderer: Keyword.get(opts, :renderer, PulquexWeb.Renderer.Default)
    }
  end

  @impl true
  def call(%{request_path: @verify_path, method: "POST"} = conn, config) do
    verify_challenge(conn, config)
  end

  def call(conn, config) do
    cond do
      exempt?(conn, config) ->
        Logger.debug("Pulquex: Exempt path #{conn.request_path}")
        conn

      valid_token?(conn, config) ->
        Logger.debug("Pulquex: Valid token for #{conn.request_path}")
        conn

      true ->
        Logger.debug("Pulquex: Issuing challenge for #{conn.request_path}")
        issue_challenge(conn, config)
    end
  end

  defp exempt?(conn, %{exempt: exempt}) do
    Enum.any?(exempt, fn
      path when is_binary(path) -> conn.request_path == path
      regex -> Regex.match?(regex, conn.request_path)
    end)
  end

  defp valid_token?(conn, %{secret: secret}) do
    with cookie when is_binary(cookie) <- get_cookie(conn),
         {:ok, _claims} <- Pulquex.Token.verify(cookie, secret) do
      true
    else
      _ -> false
    end
  end

  defp issue_challenge(conn, config) do
    challenge = Pulquex.Challenge.new(config.difficulty)
    Pulquex.Storage.insert(challenge, config.ttl)

    Logger.debug(
      "Pulquex: Issued challenge #{challenge.id} with difficulty #{challenge.difficulty}"
    )

    conn
    |> config.renderer.render(%{
      salt: challenge.salt,
      difficulty: challenge.difficulty,
      challenge_id: challenge.id,
      redirect_to: conn.request_path,
      solver_js:
        PulquexWeb.Renderer.JS.render(
          challenge.salt,
          challenge.difficulty,
          challenge.id,
          conn.request_path
        )
    })
  end

  def verify_challenge(conn, config) do
    Logger.debug("Pulquex: Verifying challenge for #{conn.request_path}")

    with {:ok, id} <- Map.fetch(conn.body_params, "challenge_id"),
         {:ok, nonce} <- fetch_nonce(conn),
         {:ok, ch} <- Pulquex.Storage.get(id),
         true <- Pulquex.Challenge.verify(%{ch | nonce: nonce}),
         {:ok, token, _} <- Pulquex.Token.sign(id, config.secret) do
      Pulquex.Storage.mark_as_used(id)
      redirect_to = Map.get(conn.body_params, "redirect_to", "/")

      Logger.debug(
        "Pulquex: Challenge #{id} solved, issuing token and redirecting to #{redirect_to}"
      )

      conn
      |> put_resp_cookie(@cookie, token, http_only: true, same_site: "Lax", max_age: config.ttl)
      |> put_resp_header("location", redirect_to)
      |> send_resp(302, "")
      |> halt()
    else
      error ->
        Logger.warning("Pulquex: Challenge verification failed: #{inspect(error)}")

        conn
        |> send_resp(403, "challenge failed")
        |> halt()
    end
  end

  defp fetch_nonce(conn) do
    case Map.fetch(conn.body_params, "nonce") do
      {:ok, n} when is_integer(n) -> {:ok, n}
      {:ok, n} when is_binary(n) -> {:ok, String.to_integer(n)}
      _ -> :error
    end
  end

  defp get_cookie(conn) do
    conn = fetch_cookies(conn)
    Map.get(conn.cookies, @cookie)
  end
end
