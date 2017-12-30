defmodule Sanbase.Prices.Store do
  # A module for storing and fetching pricing data from a time series data store
  #
  # Currently using InfluxDB for the time series data.
  #
  # There is a single database at the moment, which contains simple average
  # price data for a given currency pair within a given interval. The current
  # interval is about 5 mins (+/- 3 seconds). The timestamps are stored as
  # nanoseconds
  use Instream.Connection, otp_app: :sanbase

  alias Sanbase.Prices.Store
  alias Sanbase.Influxdb.Measurement

  def import(measurements) do
    # 1 day of 5 min resolution data
    measurements
    |> Stream.map(&Measurement.convert_measurement_for_import/1)
    |> Stream.chunk_every(288) # 1 day of 5 min resolution data
    |> Enum.map(fn data_for_import ->
         :ok = Store.write(data_for_import)
       end)
  end

  def fetch_price_points(pair, from, to) do
    fetch_query(pair, from, to)
    |> q()
  end

  def fetch_prices_with_resolution(pair, from, to, resolution) do
    # fill(none) skips intervals with no data to report instead of returning null
    ~s/SELECT MEAN(price), SUM(volume), MEAN(marketcap)
    FROM "#{pair}"
    WHERE time >= #{DateTime.to_unix(from, :nanoseconds)}
    AND time <= #{DateTime.to_unix(to, :nanoseconds)}
    GROUP BY time(#{resolution}) fill(none)/
    |> q()
  end

  def list_measurements() do
    "SHOW MEASUREMENTS"
    |> Store.query()
    |> parse_measurements_list()
  end

  def q(query) do
    Store.query(query)
    |> parse_price_series
  end

  defp fetch_query(pair, from, to) do
    ~s/SELECT time, price, volume, marketcap
    FROM "#{pair}"
    WHERE time >= #{DateTime.to_unix(from, :nanoseconds)}
    AND time <= #{DateTime.to_unix(to, :nanoseconds)
    }/
  end


  defp parse_measurements_list(%{results: [%{error: error}]}), do: raise(error)

  defp parse_measurements_list(%{
    results: [
      %{
        series: [
          %{
            values: measurements
          }
        ]
      }
    ]
  }) do

    measurements
    |> Enum.map(&Kernel.hd/1)
  end

  defp parse_price_series(%{results: [%{error: error}]}), do: raise(error)

  defp parse_price_series(%{
         results: [
           %{
             series: [
               %{
                 values: price_series
               }
             ]
           }
         ]
       }) do
    price_series
    |> Enum.map(fn [iso8601_datetime | tail] ->
         {:ok, datetime, _} = DateTime.from_iso8601(iso8601_datetime)
         [datetime | tail]
       end)
  end

  defp parse_price_series(_), do: []

  def first_price_datetime(pair) do
    ~s/SELECT FIRST(price) FROM "#{pair}"/
    |> Store.query()
    |> parse_price_datetime
  end

  def last_record(pair) do
    ~s/SELECT LAST(price), marketcap, volume from "#{pair}"/
    |> Store.query()
    |> parse_record
  end

  def fetch_closest_price_point(pair, timestamp) do
    ~s/SELECT LAST(price), marketcap, volume
    FROM "#{pair}"
    WHERE time <= #{DateTime.to_unix(timestamp, :nanoseconds)}/
    |> Store.query()
    |> parse_record
  end

  def last_price_datetime(pair) do
    ~s/SELECT LAST(price) FROM "#{pair}"/
    |> Store.query()
    |> parse_price_datetime
  end

  defp parse_price_datetime(%{
         results: [
           %{
             series: [
               %{
                 values: [[iso8601_datetime, _price]]
               }
             ]
           }
         ]
       }) do
    {:ok, datetime, _} = DateTime.from_iso8601(iso8601_datetime)
    datetime
  end

  defp parse_price_datetime(_), do: nil

  defp parse_record(%{
         results: [
           %{
             series: [
               %{
                 values: [[iso8601_datetime, price, marketcap, volume]]
               }
             ]
           }
         ]
       }) do
    {:ok, datetime, _} = DateTime.from_iso8601(iso8601_datetime)

    {datetime, price, marketcap, volume}
  end

  defp parse_record(x) do
    nil
  end

  def drop_pair(pair) do
    %{results: _} =
      "DROP MEASUREMENT #{pair}"
      |> Store.execute()
  end
end
