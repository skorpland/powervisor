defmodule Powervisor.Repo.Migrations.AddTenantDefMaxClients do
  use Ecto.Migration

  def change do
    alter table("tenants", prefix: "_powervisor") do
      add(:default_max_clients, :integer, null: false, default: 1000)
    end
  end
end
