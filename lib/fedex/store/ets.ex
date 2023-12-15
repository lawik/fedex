defmodule Fedex.Store.ETS do
  use GenServer

  @moduledoc """
  Document storage using ETS.
  """

  def start_link(name) when is_atom(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @impl GenServer
  def init(name) do
    name = :ets.new(name, [:named_table, :bag, :protected, {:read_concurrency, true}])
    {:ok, %{table: name}}
  end

  def get(name, key) do
    IO.inspect(key, label: "getting in #{name}")

    case :ets.lookup(name, key) do
      [{_key, item}] -> item
      [] -> nil
    end
  end

  def set(name, key, value) do
    IO.inspect(key, label: "setting in #{name}")
    GenServer.call(name, {:set, key, value})
  end

  def delete(name, key) do
    GenServer.call(name, {:delete, key})
  end

  @impl GenServer
  def handle_call({:set, key, value}, _from, state) do
    :ets.delete(state.table, key)
    :ets.insert(state.table, {key, value})
    {:reply, :ok, state}
  end

  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.table, key)
    {:reply, :ok, state}
  end
end
