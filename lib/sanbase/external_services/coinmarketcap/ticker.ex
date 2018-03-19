defmodule Sanbase.ExternalServices.Coinmarketcap.Ticker do
  # A module which fetches the ticker data from coinmarketcap
  defstruct [
    :id,
    :name,
    :symbol,
    :price_usd,
    :price_btc,
    :rank,
    :"24h_volume_usd",
    :market_cap_usd,
    :last_updated,
    :available_supply,
    :total_supply,
    :percent_change_1h,
    :percent_change_24h,
    :percent_change_7d
  ]

  use Tesla

  alias Sanbase.ExternalServices.RateLimiting
  alias Sanbase.ExternalServices.Coinmarketcap.PricePoint

  plug(RateLimiting.Middleware, name: :api_coinmarketcap_rate_limiter)
  plug(Tesla.Middleware.BaseUrl, "https://api.coinmarketcap.com/v1/ticker")
  plug(Tesla.Middleware.Compression)
  plug(Tesla.Middleware.Logger)

  alias Sanbase.ExternalServices.Coinmarketcap.Ticker

  def fetch_data() do
    "/?limit=1000"
    |> get()
    |> case do
      %{status: 200, body: body} ->
        parse_json(body)
    end
  end

  def parse_json(json) do
    json
    |> Poison.decode!(as: [%Ticker{}])
    |> Enum.map(&make_timestamp_integer/1)
  end

  def convert_for_importing(%Ticker{
        symbol: ticker,
        last_updated: last_updated,
        price_btc: price_btc,
        price_usd: price_usd,
        "24h_volume_usd": volume_usd,
        market_cap_usd: marketcap_usd
      }) do
    price_point = %PricePoint{
      marketcap: marketcap_usd,
      volume_usd: volume_usd,
      price_btc: price_btc,
      price_usd: price_usd,
      datetime: DateTime.from_unix!(last_updated)
    }

    [
      PricePoint.convert_to_measurement(price_point, "USD", "#{ticker}_USD"),
      PricePoint.convert_to_measurement(price_point, "BTC", "#{ticker}_BTC")
    ]
  end

  # Helper functions

  defp make_timestamp_integer(ticker) do
    {ts, ""} = Integer.parse(ticker.last_updated)
    %{ticker | last_updated: ts}
  end
end
