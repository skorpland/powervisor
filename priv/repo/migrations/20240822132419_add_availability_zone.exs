defmodule Powervisor.Repo.Migrations.AddAwsZone do
  use Ecto.Migration

  def change do
    alter table("tenants", prefix: "_powervisor") do
      add(:availability_zone, :string)
    end
  end
end
