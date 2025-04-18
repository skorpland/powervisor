defmodule Mix.Tasks.Powervisor.Gen.Appup do
  @moduledoc """
  Generates an appup file for a given release.

  ## Examples

      # Generate an appup from 0.0.1 to 0.0.2 versions

      mix powervisor.gen.appup --from=0.0.1 --to=0.0.2
  """

  use Mix.Task
  alias Distillery.Releases.Appup

  @impl true
  def run(args) do
    {parsed, _, _} = OptionParser.parse(args, strict: [from: :string, to: :string])

    {from_vsn, to_vsn} =
      if !parsed[:from] || !parsed[:to] do
        Mix.Task.run("help", ["powervisor.gen.appup"])
        System.halt(1)
      else
        {parsed[:from], parsed[:to]}
      end

    Mix.shell().info("Generating appup from #{from_vsn} to #{to_vsn}...\n")

    rel_dir = Path.join([File.cwd!(), "_build", "#{Mix.env()}", "rel", "powervisor"])
    lib_path = Path.join(rel_dir, "lib")
    path_from = Path.join(lib_path, "powervisor-#{from_vsn}")
    path_to = Path.join(lib_path, "powervisor-#{to_vsn}")
    appup_path = Path.join([path_to, "ebin", "powervisor.appup"])

    transforms = [Powervisor.HotUpgrade]

    case Appup.make(:powervisor, from_vsn, to_vsn, path_from, path_to, transforms) do
      {:ok, appup} ->
        Mix.shell().info("Writing appup to #{appup_path}")

        case File.write(appup_path, :io_lib.format("~p.", [appup]), [:utf8]) do
          :ok ->
            Mix.shell().info("Appup:\n#{File.read!(appup_path)}")

          {:error, reason} ->
            Mix.raise("Failed to write appup file: #{reason}")
        end

      {:error, reason} ->
        Mix.raise("Failed to generate appup file: #{inspect(reason)}")
    end
  end
end
