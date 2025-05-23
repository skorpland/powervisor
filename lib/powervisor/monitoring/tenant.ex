defmodule Powervisor.PromEx.Plugins.Tenant do
  @moduledoc "This module defines the PromEx plugin for Powervisor tenants."

  use PromEx.Plugin
  require Logger

  alias Powervisor, as: S

  @tags [:tenant, :user, :mode, :type, :db_name, :search_path]

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)

    [
      concurrent_connections(poll_rate),
      concurrent_proxy_connections(poll_rate),
      concurrent_tenants(poll_rate)
    ]
  end

  @impl true
  def event_metrics(_opts) do
    [
      system_metrics(),
      client_metrics(),
      db_metrics()
    ]
  end

  defmodule Buckets do
    @moduledoc false
    use Peep.Buckets.Custom,
      buckets: [1, 5, 10, 100, 1_000, 5_000, 10_000]
  end

  defp system_metrics do
    Event.build(
      :powervisor_metrics_cleaner_metrics,
      [
        counter(
          [:powervisor, :metrics_cleaner, :orphaned_metrics],
          event_name: [:powervisor, :metrics, :orphaned],
          description: "Amount of orphaned metrics that were cleaned up"
        )
      ]
    )
  end

  defp client_metrics do
    Event.build(
      :powervisor_tenant_client_event_metrics,
      [
        distribution(
          [:powervisor, :pool, :checkout, :duration, :local, :us],
          event_name: [:powervisor, :pool, :checkout, :stop, :local],
          measurement: :duration,
          description: "Duration of the checkout local process in the tenant db pool.",
          tags: @tags,
          unit: {:native, :microsecond},
          reporter_options: [
            peep_bucket_calculator: Buckets
          ]
        ),
        distribution(
          [:powervisor, :pool, :checkout, :duration, :remote, :us],
          event_name: [:powervisor, :pool, :checkout, :stop, :remote],
          measurement: :duration,
          description: "Duration of the checkout remote process in the tenant db pool.",
          tags: @tags,
          unit: {:native, :microsecond},
          reporter_options: [
            peep_bucket_calculator: Buckets
          ]
        ),
        distribution(
          [:powervisor, :client, :query, :duration],
          event_name: [:powervisor, :client, :query, :stop],
          measurement: :duration,
          description: "Duration of processing the query.",
          tags: @tags,
          unit: {:native, :millisecond},
          reporter_options: [
            peep_bucket_calculator: Buckets
          ]
        ),
        distribution(
          [:powervisor, :client, :connection, :duration],
          event_name: [:powervisor, :client, :connection, :stop],
          measurement: :duration,
          description: "Duration from the TCP connection to sending greetings to clients.",
          tags: @tags,
          unit: {:native, :millisecond},
          reporter_options: [
            peep_bucket_calculator: Buckets
          ]
        ),
        sum(
          [:powervisor, :client, :network, :recv],
          event_name: [:powervisor, :client, :network, :stat],
          measurement: :recv_oct,
          description: "The total number of bytes received by clients.",
          tags: @tags
        ),
        sum(
          [:powervisor, :client, :network, :send],
          event_name: [:powervisor, :client, :network, :stat],
          measurement: :send_oct,
          description: "The total number of bytes sent by clients.",
          tags: @tags
        ),
        counter(
          [:powervisor, :client, :queries, :count],
          event_name: [:powervisor, :client, :query, :stop],
          description: "The total number of queries received by clients.",
          tags: @tags
        ),
        counter(
          [:powervisor, :client, :joins, :ok],
          event_name: [:powervisor, :client, :joins, :ok],
          description: "The total number of successful joins.",
          tags: @tags
        ),
        counter(
          [:powervisor, :client, :joins, :fail],
          event_name: [:powervisor, :client, :joins, :fail],
          description: "The total number of failed joins.",
          tags: @tags
        ),
        counter(
          [:powervisor, :client_handler, :started, :count],
          event_name: [:powervisor, :client_handler, :started, :all],
          description: "The total number of created client_handler.",
          tags: @tags
        ),
        counter(
          [:powervisor, :client_handler, :stopped, :count],
          event_name: [:powervisor, :client_handler, :stopped, :all],
          description: "The total number of stopped client_handler.",
          tags: @tags
        )
      ]
    )
  end

  defp db_metrics do
    Event.build(
      :powervisor_tenant_db_event_metrics,
      [
        sum(
          [:powervisor, :db, :network, :recv],
          event_name: [:powervisor, :db, :network, :stat],
          measurement: :recv_oct,
          description: "The total number of bytes received by db process",
          tags: @tags
        ),
        sum(
          [:powervisor, :db, :network, :send],
          event_name: [:powervisor, :db, :network, :stat],
          measurement: :send_oct,
          description: "The total number of bytes sent by db process",
          tags: @tags
        ),
        counter(
          [:powervisor, :db_handler, :started, :count],
          event_name: [:powervisor, :db_handler, :started, :all],
          description: "The total number of created db_handler.",
          tags: @tags
        ),
        counter(
          [:powervisor, :db_handler, :stopped, :count],
          event_name: [:powervisor, :db_handler, :stopped, :all],
          description: "The total number of stopped db_handler.",
          tags: @tags
        ),
        counter(
          [:powervisor, :db_handler, :db_connection, :count],
          event_name: [:powervisor, :db_handler, :db_connection, :all],
          description: "The total number of database connections by db_handler.",
          tags: @tags
        )
      ]
    )
  end

  defp concurrent_connections(poll_rate) do
    Polling.build(
      :powervisor_concurrent_connections,
      poll_rate,
      {__MODULE__, :execute_tenant_metrics, []},
      [
        last_value(
          [:powervisor, :connections, :active],
          event_name: [:powervisor, :connections],
          description: "The total count of active clients for a tenant.",
          measurement: :active,
          tags: @tags
        )
      ]
    )
  end

  def execute_tenant_metrics do
    Registry.select(Powervisor.Registry.TenantClients, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.frequencies()
    |> Enum.each(&emit_telemetry_for_tenant/1)
  end

  @spec emit_telemetry_for_tenant({S.id(), non_neg_integer()}) :: :ok
  def emit_telemetry_for_tenant({{{type, tenant}, user, mode, db_name, search_path}, count}) do
    :telemetry.execute(
      [:powervisor, :connections],
      %{active: count},
      %{
        tenant: tenant,
        user: user,
        mode: mode,
        type: type,
        db_name: db_name,
        search_path: search_path
      }
    )
  end

  defp concurrent_proxy_connections(poll_rate) do
    Polling.build(
      :powervisor_concurrent_proxy_connections,
      poll_rate,
      {__MODULE__, :execute_tenant_proxy_metrics, []},
      [
        last_value(
          [:powervisor, :proxy, :connections, :active],
          event_name: [:powervisor, :proxy, :connections],
          description: "The total count of active proxy clients for a tenant.",
          measurement: :active,
          tags: @tags
        )
      ]
    )
  end

  def execute_tenant_proxy_metrics do
    Registry.select(Powervisor.Registry.TenantProxyClients, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.frequencies()
    |> Enum.each(&emit_proxy_telemetry_for_tenant/1)
  end

  @spec emit_proxy_telemetry_for_tenant({S.id(), non_neg_integer()}) :: :ok
  def emit_proxy_telemetry_for_tenant({{{type, tenant}, user, mode, db_name, search_path}, count}) do
    :telemetry.execute(
      [:powervisor, :proxy, :connections],
      %{active: count},
      %{
        tenant: tenant,
        user: user,
        mode: mode,
        type: type,
        db_name: db_name,
        search_path: search_path
      }
    )
  end

  defp concurrent_tenants(poll_rate) do
    Polling.build(
      :powervisor_concurrent_tenants,
      poll_rate,
      {__MODULE__, :execute_conn_tenants_metrics, []},
      [
        last_value(
          [:powervisor, :tenants, :active],
          event_name: [:powervisor, :tenants],
          description: "The total count of active tenants.",
          measurement: :active
        )
      ]
    )
  end

  def execute_conn_tenants_metrics do
    num =
      Registry.select(Powervisor.Registry.TenantSups, [{{:"$1", :_, :_}, [], [:"$1"]}])
      |> Enum.uniq()
      |> Enum.count()

    :telemetry.execute(
      [:powervisor, :tenants],
      %{active: num}
    )
  end
end
