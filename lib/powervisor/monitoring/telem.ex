defmodule Powervisor.Monitoring.Telem do
  @moduledoc false

  require Logger

  defmacro telemetry_execute(event_name, measurements, metadata) do
    if not Application.get_env(:powervisor, :metrics_disabled, false) do
      quote do
        :telemetry.execute(unquote(event_name), unquote(measurements), unquote(metadata))
      end
    end
  end

  defmacro network_usage_disable(do: block) do
    if Application.get_env(:powervisor, :metrics_disabled, false) do
      quote do
        {:ok, %{recv_oct: 0, send_oct: 0}}
      end
    else
      block
    end
  end

  @spec network_usage(:client | :db, Powervisor.sock(), Powervisor.id(), map()) ::
          {:ok | :error, map()}
  def network_usage(type, {mod, socket}, id, stats) do
    network_usage_disable do
      mod = if mod == :ssl, do: :ssl, else: :inet

      case mod.getstat(socket, [:recv_oct, :send_oct]) do
        {:ok, [{:recv_oct, recv_oct}, {:send_oct, send_oct}]} ->
          stats = %{
            send_oct: send_oct - Map.get(stats, :send_oct, 0),
            recv_oct: recv_oct - Map.get(stats, :recv_oct, 0)
          }

          {{ptype, tenant}, user, mode, db_name, search_path} = id

          :telemetry.execute(
            [:powervisor, type, :network, :stat],
            stats,
            %{
              tenant: tenant,
              user: user,
              mode: mode,
              type: ptype,
              db_name: db_name,
              search_path: search_path
            }
          )

          {:ok, %{recv_oct: recv_oct, send_oct: send_oct}}

        {:error, reason} ->
          Logger.error("Failed to get socket stats: #{inspect(reason)}")
          {:error, stats}
      end
    end
  end

  @spec pool_checkout_time(integer(), Powervisor.id(), :local | :remote) :: :ok | nil
  def pool_checkout_time(time, {{type, tenant}, user, mode, db_name, search_path}, same_box) do
    telemetry_execute(
      [:powervisor, :pool, :checkout, :stop, same_box],
      %{duration: time},
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

  @spec client_query_time(integer(), Powervisor.id()) :: :ok | nil
  def client_query_time(start, {{type, tenant}, user, mode, db_name, search_path}) do
    telemetry_execute(
      [:powervisor, :client, :query, :stop],
      %{duration: System.monotonic_time() - start},
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

  @spec client_connection_time(integer(), Powervisor.id()) :: :ok | nil
  def client_connection_time(start, {{type, tenant}, user, mode, db_name, search_path}) do
    telemetry_execute(
      [:powervisor, :client, :connection, :stop],
      %{duration: System.monotonic_time() - start},
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

  @spec client_join(:ok | :fail, Powervisor.id() | any()) :: :ok | nil
  def client_join(status, {{type, tenant}, user, mode, db_name, search_path}) do
    telemetry_execute(
      [:powervisor, :client, :joins, status],
      %{},
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

  def client_join(_status, id) do
    Logger.warning("client_join is called with a mismatched id: #{inspect(id)}")
  end

  @spec handler_action(
          :client_handler | :db_handler,
          :started | :stopped | :db_connection,
          Powervisor.id()
        ) :: :ok | nil
  def handler_action(handler, action, {{type, tenant}, user, mode, db_name, search_path}) do
    telemetry_execute(
      [:powervisor, handler, action, :all],
      %{},
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

  def handler_action(handler, action, id) do
    Logger.warning(
      "handler_action is called with a mismatched #{inspect(handler)} #{inspect(action)} #{inspect(id)}"
    )
  end
end
