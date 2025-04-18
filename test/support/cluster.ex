defmodule Powervisor.Support.Cluster do
  @moduledoc """
  This module provides functionality to help handle distributive mode for testing.
  """

  def start_node(name \\ :peer.random_name()) do
    {:ok, pid, node} =
      :peer.start_link(%{
        name: name,
        host: ~c"127.0.0.1",
        longnames: true,
        connection: :standard_io
      })

    :peer.call(pid, :logger, :set_primary_config, [:level, :none])
    true = :peer.call(pid, :code, :set_path, [:code.get_path()])
    apply_config(pid)
    :peer.call(pid, Application, :ensure_all_started, [:powervisor])

    {:ok, pid, node}
  end

  defp apply_config(pid) do
    for {app_name, _, _} <- Application.loaded_applications() do
      for {key, val} <- Application.get_all_env(app_name) do
        val =
          case {app_name, key} do
            {:powervisor, :proxy_port_transaction} ->
              Application.get_env(:powervisor, :secondary_proxy_port)

            {:powervisor, PowervisorWeb.Endpoint} ->
              put_in(val[:http],
                ip: {127, 0, 0, 1},
                port: Application.get_env(:powervisor, :secondary_http)
              )

            {:powervisor, :region} ->
              "usa"

            {:powervisor, :availability_zone} ->
              "ap-southeast-1c"

            _ ->
              val
          end

        :peer.call(pid, Application, :put_env, [app_name, key, val])
      end
    end

    :peer.call(pid, Powervisor.Monitoring.PromEx, :set_metrics_tags, [])
  end
end
