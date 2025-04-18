import Ecto.Adapters.SQL, only: [query: 3]

[
  "create schema if not exists _powervisor"
]
|> Enum.each(&query(Powervisor.Repo, &1, []))
