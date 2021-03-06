defmodule Sanbase.Model.ProjectEthAddress do
  use Ecto.Schema
  import Ecto.Changeset
  alias Sanbase.Model.{ProjectEthAddress, Project, LatestEthWalletData}

  schema "project_eth_address" do
    field(:address, :string)
    belongs_to(:project, Project)

    belongs_to(
      :latest_eth_wallet_data,
      LatestEthWalletData,
      foreign_key: :address,
      references: :address,
      define_field: false
    )
  end

  @doc false
  def changeset(%ProjectEthAddress{} = project_eth_address, attrs \\ %{}) do
    project_eth_address
    |> cast(attrs, [:address, :project_id])
    |> validate_required([:address, :project_id])
    |> update_change(:address, &String.downcase/1)
    |> unique_constraint(:address)
  end
end
