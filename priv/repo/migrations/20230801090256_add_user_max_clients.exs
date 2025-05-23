defmodule Powervisor.Repo.Migrations.AddUserMaxClients do
  use Ecto.Migration

  def change do
    alter table("users", prefix: "_powervisor") do
      add(:max_clients, :integer, null: true)
    end
  end
end
