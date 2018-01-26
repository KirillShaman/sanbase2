defmodule Sanbase.Etherbi.Transactions do
  @moduledoc ~S"""
    This module is a GenServer that periodically sends requests to etherbi API.
    In and out transactions are fetched and saved in a time series database for
    easier aggregation and querying.
  """

  use GenServer

  require Logger
  require Sanbase.Utils.Config

  import Ecto.Query

  alias Sanbase.Repo
  alias Sanbase.Utils.Config
  alias Sanbase.Etherbi.Store
  alias Sanbase.Etherbi.FundsMovement
  alias Sanbase.Influxdb.Measurement
  alias Sanbase.Model.ExchangeEthAddress
  alias Sanbase.Model.Project

  @default_update_interval 1000 * 60 * 5

  def start_link(_state) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    if Config.get(:sync_enabled, false) do
      Store.create_db()

      update_interval_ms = Config.get(:update_interval, @default_update_interval)

      GenServer.cast(self(), :sync)
      {:ok, %{update_interval_ms: update_interval_ms}}
    else
      :ignore
    end
  end

  def handle_cast(
        :sync,
        %{update_interval_ms: update_interval_ms} = state
      ) do
    # Precalculate the number by which we have to divide, that is pow(10, decimal_places)
    token_decimals = build_token_decimals_map()
    exchange_wallets_addrs = Repo.all(from(addr in ExchangeEthAddress, select: addr.address))

    Task.Supervisor.async_stream_nolink(
      Sanbase.TaskSupervisor,
      exchange_wallets_addrs,
      &fetch_and_store_in(&1, token_decimals),
      max_concurency: 1,
      timeout: 165_000
    )
    |> Stream.run()

    Task.Supervisor.async_stream_nolink(
      Sanbase.TaskSupervisor,
      exchange_wallets_addrs,
      &fetch_and_store_out(&1, token_decimals),
      max_concurency: 1,
      timeout: 165_000
    )
    |> Stream.run()

    Process.send_after(self(), {:"$gen_cast", :sync}, update_interval_ms)
    {:noreply, state}
  end

  def fetch_and_store_in(address, token_decimals) do
    with {:ok, transactions_in} <- FundsMovement.transactions_in(address) do
      convert_to_measurement(transactions_in, "in", token_decimals)
      |> Store.import()
    else
      {:error, reason} ->
        Logger.warn("Could not fetch and store in transactions for #{address}: #{reason}")
    end
  end

  def fetch_and_store_out(address, token_decimals) do
    with {:ok, transactions_out} <-FundsMovement.transactions_out(address) do
      convert_to_measurement(transactions_out, "out", token_decimals)
      |> Store.import()
    else
      {:error, reason} ->
        Logger.warn("Could not fetch and store out transactions for #{address}: #{reason}")
    end
  end

  # Private functions

  defp build_token_decimals_map() do
    query =
      from(
        p in Project,
        where: not is_nil(p.token_decimals),
        select: %{ticker: p.ticker, token_decimals: p.token_decimals}
      )

    Repo.all(query)
    |> Enum.map(fn %{ticker: ticker, token_decimals: token_decimals} ->
      {ticker, :math.pow(10, token_decimals)}
    end)
    |> Map.new()
  end

  # Better return no information than wrong information. If we have no data for the
  # number of decimal places `nil` is written instead and it gets filtered by the Store.import()
  defp convert_to_measurement(
         transactions_data,
         transaction_type,
         token_decimals
       ) do
    transactions_data
    |> Enum.map(fn {datetime, volume, address, token} ->
      if decimal_places = Map.get(token_decimals, token) do
        %Measurement{
          timestamp: datetime |> DateTime.to_unix(:nanoseconds),
          fields: %{volume: volume / decimal_places},
          tags: [transaction_type: transaction_type, address: address],
          name: token
        }
      else
        Logger.warn("Missing token decimals for #{token}")
        nil
      end
    end)
  end
end