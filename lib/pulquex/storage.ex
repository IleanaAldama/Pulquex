defmodule Pulquex.Storage do
  alias Pulquex.Challenge
  use GenServer

  @table_name :pulquex_challenges

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:set, :private, :named_table, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  def insert(challenge = %Challenge{}, ttl \\ 100) do
    GenServer.cast(__MODULE__, {:insert, challenge, ttl})
    :ok
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def mark_as_used(id) do
    GenServer.cast(__MODULE__, {:mark_as_used, id})
    :ok
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now() |> DateTime.to_unix(:second)
    :ets.select_delete(@table_name, [{{:_, :_, :"$1", :_}, [{:<, :"$1", now}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    now = DateTime.utc_now() |> DateTime.to_unix(:second)

    result =
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

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:insert, challenge, ttl}, state) do
    expires_at = (DateTime.utc_now() |> DateTime.to_unix(:second)) + ttl

    :ets.insert(
      @table_name,
      {challenge.id, challenge, expires_at, false}
    )

    {:noreply, state}
  end

  def handle_cast({:mark_as_used, id}, state) do
    :ets.update_element(@table_name, id, {4, true})
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, :timer.minutes(5))
end
