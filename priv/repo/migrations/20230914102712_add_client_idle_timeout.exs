defmodule Powervisor.Repo.Migrations.AddClientIdleTimeout do
  use Ecto.Migration

  def change do
    alter table("tenants", prefix: "_powervisor") do
      add(:client_idle_timeout, :integer, null: false, default: 0)
    end
  end
end
