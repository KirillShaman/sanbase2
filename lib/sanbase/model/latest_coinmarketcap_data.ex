defmodule Sanbase.Model.LatestCoinmarketcapData do
  use Ecto.Schema
  import Ecto.Changeset
  alias Sanbase.Model.LatestCoinmarketcapData

  schema "latest_coinmarketcap_data" do
    field :name, :string
    field :market_cap_usd, :decimal
    field :price_usd, :decimal
    field :symbol, :string
    field :update_time, Timex.Ecto.DateTime
  end

  @doc false
  def changeset(%LatestCoinmarketcapData{} = latest_coinmarketcap_data, attrs \\ %{}) do
    latest_coinmarketcap_data
    |> cast(attrs, [:name, :symbol, :price_usd, :market_cap_usd, :update_time])
    |> validate_required([:name, :symbol, :price_usd, :market_cap_usd, :update_time])
  end
end
