defmodule Powervisor.Repo.Migrations.CreateClusters do
  use Ecto.Migration

  def change do
    create table("clusters", primary_key: false, prefix: "_powervisor") do
      add(:id, :binary_id, primary_key: true)
      add(:active, :boolean, default: false, null: false)
      add(:alias, :string, null: false)

      timestamps()
    end

    create(index(:clusters, [:alias], unique: true, prefix: "_powervisor"))
  end
end
