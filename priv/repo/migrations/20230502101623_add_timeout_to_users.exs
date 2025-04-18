defmodule Powervisor.Repo.Migrations.AddTimeoutToUsers do
  use Ecto.Migration

  def up do
    alter table("users", prefix: "_powervisor") do
      add(:pool_checkout_timeout, :integer, default: 60_000, null: false)
    end
  end

  def down do
    alter table("users", prefix: "_powervisor") do
      remove(:pool_checkout_timeout)
    end
  end
end
