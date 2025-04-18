defmodule Powervisor.Encrypted.Binary do
  @moduledoc false
  use Cloak.Ecto.Binary, vault: Powervisor.Vault
end
