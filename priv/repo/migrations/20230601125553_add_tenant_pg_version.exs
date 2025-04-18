defmodule Powervisor.Repo.Migrations.AddTenantDefaultPS do
  use Ecto.Migration

  def up do
    alter table("tenants", prefix: "_powervisor") do
      add(:default_parameter_status, :map, null: false)
    end
  end

  def down do
    alter table("tenants", prefix: "_powervisor") do
      remove(:default_parameter_status)
    end
  end
end
