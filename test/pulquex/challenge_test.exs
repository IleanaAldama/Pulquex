defmodule Pulquex.ChallengeTest do
  use ExUnit.Case

  describe "verify" do
    test "verifiy a valid challenge" do
      challenge = %Pulquex.Challenge{
        salt:
          "866452b9e7cb65e8fd4c7a38643970d785e56a98fc5471b0d65affea77c5f9fc59a2b9ad231f623a557b4224a75acf364971fa6a64de18b4891ced576212c967",
        nonce: 70884,
        difficulty: 4
      }

      assert Pulquex.Challenge.verify(challenge)
    end

    test "returns false if not valid challenge" do
      challenge = %Pulquex.Challenge{
        salt:
          "866452b9e7cb65e8fd4c7a38643970d785e56a98fc5471b0d65affea77c5f9fc59a2b9ad231f623a557b4224a75acf364971fa6a64de18b4891ced576212c967",
        nonce: 0,
        difficulty: 4
      }

      refute Pulquex.Challenge.verify(challenge)
    end
  end
end
