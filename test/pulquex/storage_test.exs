defmodule Pulquex.StorageTest do
  alias Pulquex.Challenge
  alias Pulquex.Storage
  use ExUnit.Case

  setup do
    storage_pid = Storage.start_link()
    challenge = Challenge.new()
    {:ok, %{storage_pid: storage_pid, challenge: challenge}}
  end

  describe "mark_as_used" do
    test "should mark an existing challenge as used", %{challenge: challenge} do
      assert Storage.insert(challenge) == :ok
      assert Storage.mark_as_used(challenge.id) == :ok
      assert Storage.get(challenge.id) == {:error, :used}
    end
  end

  describe "get" do
    test "should return an existing challente", %{challenge: challenge} do
      assert Storage.insert(challenge) == :ok
      {:ok, retrieved} = Storage.get(challenge.id)
      assert retrieved == challenge
    end

    test "should return not found for a non existing challenge" do
      assert {:error, :not_found} == Storage.get("bogus-id")
    end

    test "should return expired for expired challenge", %{challenge: challenge} do
      assert Storage.insert(challenge, -200) == :ok
      assert Storage.get(challenge.id) == {:error, :expired}
    end
  end
end
