defmodule Powervisor.Repo.Migrations.AddEnforceSsl do
  use Ecto.Migration

  def up do
    alter table("tenants", prefix: "_powervisor") do
      add(:enforce_ssl, :boolean, null: false, default: false)
    end
  end

  def down do
    alter table("tenants", prefix: "_powervisor") do
      remove(:enforce_ssl)
    end
  end
end
