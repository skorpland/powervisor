defmodule Powervisor.TenantSupervisor do
  @moduledoc false
  use Supervisor

  require Logger
  alias Powervisor.Manager
  alias Powervisor.SecretChecker

  def start_link(%{replicas: [%{mode: mode} = single]} = args)
      when mode in [:transaction, :session] do
    {:ok, meta} = Powervisor.start_local_server(single)
    Logger.info("Starting ranch instance #{inspect(meta)} for #{inspect(args.id)}")
    name = {:via, :syn, {:tenants, args.id, meta}}
    Supervisor.start_link(__MODULE__, args, name: name)
  end

  def start_link(args) do
    name = {:via, :syn, {:tenants, args.id}}
    Supervisor.start_link(__MODULE__, args, name: name)
  end

  @impl true
  def init(%{replicas: replicas} = args) do
    pools =
      replicas
      |> Enum.with_index()
      |> Enum.map(fn {e, i} ->
        id = {:pool, e.replica_type, i, args.id}

        %{
          id: {:pool, id},
          start: {:poolboy, :start_link, [pool_spec(id, e), e]},
          restart: :temporary
        }
      end)

    children = [{Manager, args}, {SecretChecker, args} | pools]

    {{type, tenant}, user, mode, db_name, search_path} = args.id
    map_id = %{user: user, mode: mode, type: type, db_name: db_name, search_path: search_path}
    Registry.register(Powervisor.Registry.TenantSups, tenant, map_id)

    Supervisor.init(children,
      strategy: :one_for_all,
      max_restarts: 10,
      max_seconds: 60
    )
  end

  def child_spec(args) do
    %{
      id: args.id,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient
    }
  end

  @spec pool_spec(tuple, map) :: Keyword.t()
  defp pool_spec(id, args) do
    # {size, overflow} =
    #   case args.mode do
    #     :session ->
    #       {1, args.pool_size}

    #     :transaction ->
    #       if args.pool_size < 10, do: {args.pool_size, 0}, else: {10, args.pool_size - 10}
    #   end

    {size, overflow} = {1, args.pool_size}
    # {size, overflow} = {args.pool_size, 0}

    [
      name: {:via, Registry, {Powervisor.Registry.Tenants, id, args.replica_type}},
      worker_module: Powervisor.DbHandler,
      size: size,
      max_overflow: overflow,
      strategy: :lifo,
      idle_timeout: :timer.minutes(5)
    ]
  end
end
