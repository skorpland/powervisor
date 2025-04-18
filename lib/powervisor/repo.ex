defmodule Powervisor.Repo do
  use Ecto.Repo,
    otp_app: :powervisor,
    adapter: Ecto.Adapters.Postgres
end
