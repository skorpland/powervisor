defmodule PowervisorWeb.MetricsControllerTest do
  use PowervisorWeb.ConnCase
  alias Powervisor.Support.Cluster

  @tag cluster: true
  test "exporting metrics", %{conn: conn} do
    {:ok, _pid, node2} = Cluster.start_node()

    Node.connect(node2)

    conn =
      conn
      |> auth
      |> get(Routes.metrics_path(conn, :index))

    assert conn.status == 200
    assert conn.resp_body =~ "region=\"eu\""
    assert conn.resp_body =~ "region=\"usa\""
  end

  test "invalid jwt", %{conn: conn} do
    token = "invalid"

    conn =
      conn
      |> auth(token)
      |> get(Routes.metrics_path(conn, :index))

    assert conn.status == 403
  end

  defp auth(conn, bearer \\ gen_token()) do
    put_req_header(conn, "authorization", "Bearer " <> bearer)
  end

  defp gen_token(secret \\ Application.fetch_env!(:powervisor, :metrics_jwt_secret)) do
    Powervisor.Jwt.Token.gen!(secret)
  end
end
