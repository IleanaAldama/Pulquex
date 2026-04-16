defmodule Pulquex.Plug do
  @behaviour Plug

  import Plug.Conn

  @cookie "pulquex-token"
  @verify_path "/_pulquex/verify"

  def init(opts) do
    %{
      difficulty: Keyword.get(opts, :difficulty, 4),
      ttl: Keyword.get(opts, :ttl, 3600),
      secret: Keyword.fetch!(opts, :secret),
      exempt: Keyword.get(opts, :exempt, [])
    }
  end

  def call(%{request_path: @verify_path, method: "POST"} = conn, config) do
    dbg("calling Verify")
    dbg(conn)
    handle_verify(conn, config)
  end

  def call(conn, config) do
    dbg(conn)

    cond do
      exempt?(conn, config) -> conn
      valid_token?(conn, config) -> conn
      true -> issue_challenge(conn, config)
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

  defp issue_challenge(conn, %{difficulty: difficulty, ttl: ttl}) do
    challenge = Pulquex.Challenge.new(difficulty)
    Pulquex.Storage.insert(challenge, ttl)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, challenge_html(challenge, conn.request_path))
    |> halt()
  end

  defp handle_verify(conn, config) do
    conn =
      Plug.Parsers.call(
        conn,
        Plug.Parsers.init(
          parsers: [:urlencoded, :json],
          json_decoder: JSON
        )
      )

    with {:ok, id} <- Map.fetch(conn.body_params, "challenge_id"),
         {:ok, nonce} <- fetch_nonce(conn),
         {:ok, ch} <- Pulquex.Storage.get(id),
         true <- Pulquex.Challenge.verify(%{ch | nonce: nonce}),
         {:ok, token, _} <- Pulquex.Token.sign(id, config.secret) do
      Pulquex.Storage.mark_as_used(id)
      redirect_to = Map.get(conn.body_params, "redirect_to", "/")

      conn
      |> put_resp_cookie(@cookie, token, http_only: true, same_site: "Lax", max_age: config.ttl)
      |> put_resp_header("location", redirect_to)
      |> send_resp(302, "")
      |> halt()
    else
      _ ->
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

  defp challenge_html(challenge, redirect_to) do
    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>Verificando...</title></head>
    <body>
      <p>Verificando que eres humano...</p>
      <script>
        const salt       = #{JSON.encode!(challenge.salt)};
        const difficulty = #{challenge.difficulty};
        const challengeId = #{JSON.encode!(challenge.id)};
        const redirectTo = #{JSON.encode!(redirect_to)};

        async function sha256(str) {
          const buf  = new TextEncoder().encode(str);
          const hash = await crypto.subtle.digest('SHA-256', buf);
          return new Uint8Array(hash);
        }

        function leadingZeroNibbles(bytes) {
          let count = 0;
          for (const byte of bytes) {
            const hi = (byte >> 4) & 0xf;
            const lo = byte & 0xf;
            if (hi !== 0) return count; count++;
            if (lo !== 0) return count; count++;
          }
          return count;
        }

        async function solve() {
          let nonce = 0;
          while (true) {
            const hash = await sha256(salt + String(nonce));
            if (leadingZeroNibbles(hash) >= difficulty) {
              const form = document.createElement('form');
              form.method = 'POST';
              form.action = '/_pulquex/verify';
              [['challenge_id', challengeId], ['nonce', nonce], ['redirect_to', redirectTo]]
                .forEach(([k, v]) => {
                  const i = document.createElement('input');
                  i.type = 'hidden'; i.name = k; i.value = v;
                  form.appendChild(i);
                });
              document.body.appendChild(form);
              form.submit();
              return;
            }
            nonce++;
          }
        }

        solve();
      </script>
    </body>
    </html>
    """
  end
end
