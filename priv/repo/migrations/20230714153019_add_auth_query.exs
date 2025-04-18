defmodule Powervisor.Repo.Migrations.AddAuthQuery do
  use Ecto.Migration

  def up do
    alter table("tenants", prefix: "_powervisor") do
      add(:require_user, :boolean, null: false, default: true)
      add(:auth_query, :string, null: true)
      add(:default_pool_size, :integer, null: false, default: 15)
    end

    auth_query_constraints = """
    (require_user = true) OR (require_user = false AND auth_query IS NOT NULL)
    """

    create(
      constraint("tenants", :auth_query_constraints,
        check: auth_query_constraints,
        prefix: "_powervisor"
      )
    )
  end

  def down do
    alter table("tenants", prefix: "_powervisor") do
      remove(:auth_query)
    end

    drop(constraint("tenants", "auth_query_constraints", prefix: "_powervisor"))
  end
end
