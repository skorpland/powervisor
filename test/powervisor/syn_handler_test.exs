defmodule Powervisor.SynHandlerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  require Logger
  alias Ecto.Adapters.SQL.Sandbox
  alias Powervisor.Support.Cluster

  @id {{:single, "syn_tenant"}, "postgres", :session, "postgres", nil}

  @tag cluster: true
  test "resolving conflict" do
    {:ok, _pid, node2} = Cluster.start_node()

    secret = %{alias: "postgres"}
    auth_secret = {:password, fn -> secret end}
    {:ok, pid2} = :erpc.call(node2, Powervisor.FixturesHelpers, :start_pool, [@id, secret])
    Process.sleep(500)
    assert pid2 == Powervisor.get_global_sup(@id)
    assert node(pid2) == node2
    true = Node.disconnect(node2)
    Process.sleep(1000)

    assert nil == Powervisor.get_global_sup(@id)
    {:ok, pid1} = Powervisor.start(@id, auth_secret)
    assert pid1 == Powervisor.get_global_sup(@id)
    assert node(pid1) == node()

    :pong = Node.ping(node2)
    Process.sleep(500)

    msg = "Resolving syn_tenant conflict, stop local pid"

    assert capture_log(fn -> Logger.warning(msg) end) =~
             msg

    assert pid2 == Powervisor.get_global_sup(@id)
    assert node(pid2) == node2
  end

  setup tags do
    pid = Sandbox.start_owner!(Powervisor.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end
end
