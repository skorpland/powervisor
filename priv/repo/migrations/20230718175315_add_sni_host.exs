defmodule Powervisor.Repo.Migrations.AddSniHost do
  use Ecto.Migration

  def change do
    alter table("tenants", prefix: "_powervisor") do
      add(:sni_hostname, :string, null: true)
    end
  end
end
