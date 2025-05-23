defmodule Powervisor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  alias Powervisor.Monitoring.PromEx

  @metrics_disabled Application.compile_env(:powervisor, :metrics_disabled, false)

  @impl true
  def start(_type, _args) do
    primary_config = :logger.get_primary_config()

    host =
      case node() |> Atom.to_string() |> String.split("@") do
        [_, host] -> host
        _ -> nil
      end

    region = Application.get_env(:powervisor, :region)

    global_metadata =
      %{
        nodehost: host,
        az: Application.get_env(:powervisor, :availability_zone),
        region: region,
        location: System.get_env("LOCATION_KEY") || region,
        instance_id: System.get_env("INSTANCE_ID")
      }

    :ok =
      :logger.set_primary_config(
        :metadata,
        Map.merge(primary_config.metadata, global_metadata)
      )

    :ok =
      :gen_event.swap_sup_handler(
        :erl_signal_server,
        {:erl_signal_handler, []},
        {Powervisor.SignalHandler, []}
      )

    proxy_ports = [
      {:pg_proxy_transaction, Application.get_env(:powervisor, :proxy_port_transaction),
       :transaction, Powervisor.ClientHandler},
      {:pg_proxy_session, Application.get_env(:powervisor, :proxy_port_session), :session,
       Powervisor.ClientHandler},
      {:pg_proxy, Application.get_env(:powervisor, :proxy_port), :proxy, Powervisor.ClientHandler}
    ]

    for {key, port, mode, handler} <- proxy_ports do
      case :ranch.start_listener(
             key,
             :ranch_tcp,
             %{
               max_connections: String.to_integer(System.get_env("MAX_CONNECTIONS") || "75000"),
               num_acceptors: String.to_integer(System.get_env("NUM_ACCEPTORS") || "100"),
               socket_opts: [port: port, keepalive: true]
             },
             handler,
             %{mode: mode}
           ) do
        {:ok, _pid} ->
          Logger.notice("Proxy started #{mode} on port #{port}")

        error ->
          Logger.error("Proxy on #{port} not started because of #{inspect(error)}")
      end
    end

    :syn.set_event_handler(Powervisor.SynHandler)
    :syn.add_node_to_scopes([:tenants, :availability_zone])

    :syn.join(:availability_zone, Application.get_env(:powervisor, :availability_zone), self(),
      node: node()
    )

    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      Powervisor.ErlSysMon,
      {Registry, keys: :unique, name: Powervisor.Registry.Tenants},
      {Registry, keys: :unique, name: Powervisor.Registry.ManagerTables},
      {Registry, keys: :unique, name: Powervisor.Registry.PoolPids},
      {Registry, keys: :duplicate, name: Powervisor.Registry.TenantSups},
      {Registry,
       keys: :duplicate,
       name: Powervisor.Registry.TenantClients,
       partitions: System.schedulers_online()},
      {Registry,
       keys: :duplicate,
       name: Powervisor.Registry.TenantProxyClients,
       partitions: System.schedulers_online()},
      {Cluster.Supervisor, [topologies, [name: Powervisor.ClusterSupervisor]]},
      Powervisor.Repo,
      # Start the Telemetry supervisor
      PowervisorWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Powervisor.PubSub},
      {
        PartitionSupervisor,
        child_spec: DynamicSupervisor, strategy: :one_for_one, name: Powervisor.DynamicSupervisor
      },
      Powervisor.Vault,

      # Start the Endpoint (http/https)
      PowervisorWeb.Endpoint
    ]

    Logger.warning("metrics_disabled is #{inspect(@metrics_disabled)}")

    children =
      if @metrics_disabled do
        children
      else
        PromEx.set_metrics_tags()
        children ++ [PromEx, Powervisor.TenantsMetrics, Powervisor.MetricsCleaner]
      end

    # start Cachex only if the node uses names, this is necessary for test setup
    children =
      if node() != :nonode@nohost do
        [{Cachex, name: Powervisor.Cache} | children]
      else
        children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Powervisor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PowervisorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
