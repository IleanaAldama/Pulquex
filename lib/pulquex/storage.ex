defmodule Pulquex.Storage do
  alias Pulquex.Challenge
  use GenServer

  @table_name :pulquex_challenges

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  def insert(challenge = %Challenge{}, ttl \\ 100) do
    expires_at = (DateTime.utc_now() |> DateTime.to_unix(:second)) + ttl

    :ets.insert(
      @table_name,
      {challenge.id, challenge, expires_at, false}
    )

    :ok
  end

  def get(id) do
    now = DateTime.utc_now() |> DateTime.to_unix(:second)

    case :ets.lookup(@table_name, id) do
      [] ->
        {:error, :not_found}

      [{^id, _challenge, expires_at, _used?}] when now > expires_at ->
        {:error, :expired}

      [{^id, _challenge, _expires_at, _used? = true}] ->
        {:error, :used}

      [{^id, challenge, _expires_at, _used?}] ->
        {:ok, challenge}
    end
  end

  def mark_as_used(id) do
    :ets.update_element(@table_name, id, {4, true})
    :ok
  end
end
