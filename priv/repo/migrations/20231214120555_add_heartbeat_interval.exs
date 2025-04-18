defmodule Powervisor.Repo.Migrations.AddHeartbeatInterval do
  use Ecto.Migration

  def change do
    alter table("tenants", prefix: "_powervisor") do
      add(:client_heartbeat_interval, :integer, null: false, default: 60)
    end
  end
end
