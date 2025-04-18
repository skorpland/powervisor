defmodule PowervisorWeb.MetricsController do
  @moduledoc """
  Handles requests for Prometheus metrics
  from all nodes in the cluster.
  """

  use PowervisorWeb, :controller
  require Logger
  alias Powervisor.Monitoring.PromEx

  @spec index(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def index(conn, _) do
    cluster_metrics = fetch_cluster_metrics()

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, cluster_metrics)
  end

  def tenant(conn, %{"external_id" => ext_id}) do
    cluster_metrics = fetch_cluster_metrics(ext_id)
    code = if cluster_metrics == "", do: 404, else: 200

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(code, [cluster_metrics, "\n"])
  end

  @spec fetch_cluster_metrics() :: String.t()
  def fetch_cluster_metrics do
    Node.list()
    |> Task.async_stream(&fetch_node_metrics/1, timeout: :infinity)
    |> Enum.reduce(PromEx.get_metrics(), &merge_node_metrics/2)
  end

  @spec fetch_node_metrics(atom()) :: {atom(), term()}
  def fetch_node_metrics(node) do
    {node, :rpc.call(node, PromEx, :get_metrics, [], 25_000)}
  end

  @spec fetch_cluster_metrics(String.t()) :: String.t()
  def fetch_cluster_metrics(tenant) do
    Node.list()
    |> Task.async_stream(&fetch_node_metrics(&1, tenant), timeout: :infinity)
    |> Enum.reduce(PromEx.get_tenant_metrics(tenant), &merge_node_metrics/2)
  end

  @spec fetch_node_metrics(atom(), String.t()) :: {atom(), term()}
  def fetch_node_metrics(node, tenant) do
    {node, :rpc.call(node, PromEx, :get_tenant_metrics, [tenant], 25_000)}
  end

  def merge_node_metrics({_, {node, {:badrpc, reason}}}, acc) do
    Logger.error("Cannot fetch metrics from the node #{inspect(node)} because #{inspect(reason)}")
    acc
  end

  def merge_node_metrics({_, {_node, metrics}}, acc) do
    [metrics, "\n" | acc]
  end
end
