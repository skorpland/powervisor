defmodule Powervisor.FixturesHelpers do
  @moduledoc false

  def start_pool(id, secret) do
    secret = {:password, fn -> secret end}
    Powervisor.start(id, secret)
  end
end
