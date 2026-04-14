defmodule Pulquex.Challenge do
  defstruct [:salt, :nonce, :difficulty]

  def new(difficulty \\ 4) do
    %__MODULE__{
      nonce: 0,
      difficulty: difficulty,
      salt: Pulquex.Salt.new()
    }
  end

  def verify(challenge = %__MODULE__{}) do
    input =
      challenge.salt <> Integer.to_string(challenge.nonce)

    hash = :crypto.hash(:sha256, input)
    count_leading_zero_nibbles(hash) >= challenge.difficulty
  end

  @doc "Only for testing — in production the browser solves this."
  def solve(challenge) do
    if verify(challenge) do
      challenge
    else
      solve(%{challenge | nonce: challenge.nonce + 1})
    end
  end

  defp count_leading_zero_nibbles(<<0::4, rest::bits>>),
    do: 1 + count_leading_zero_nibbles(rest)

  defp count_leading_zero_nibbles(_), do: 0
end
