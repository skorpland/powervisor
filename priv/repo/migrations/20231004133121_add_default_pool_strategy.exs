defmodule Powervisor.Repo.Migrations.AddDefaultPoolStrategy do
  use Ecto.Migration

  def change do
    alter table("tenants", prefix: "_powervisor") do
      add(:default_pool_strategy, :string, null: false, default: "fifo")
    end

    create(
      constraint(
        "tenants",
        :default_pool_strategy_values,
        check: "default_pool_strategy IN ('fifo', 'lifo')",
        prefix: "_powervisor"
      )
    )
  end
end
