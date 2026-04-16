defmodule Pulquex.Token do
  use Joken.Config

  def sign(challenge_id, secret) do
    signer = Joken.Signer.create("HS256", secret)
    generate_and_sign(%{"jti" => challenge_id}, signer)
  end

  def verify(token, secret) do
    signer = Joken.Signer.create("HS256", secret)
    verify_and_validate(token, signer)
  end

  def token_config do
    default_claims()
    |> add_claim("jti", nil, &valid_jti?/1)
  end

  defp valid_jti?(jti), do: is_binary(jti) and byte_size(jti) > 0
end
