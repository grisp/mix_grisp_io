defmodule :"Elixir.Mix.Tasks.Grisp-io.Delete" do
  use Mix.Task

  @shortdoc false
  @moduledoc "Deletes the selected release's update package from GRiSP.io."

  @switches [relname: :string, relvsn: :string]
  @aliases [n: :relname, v: :relvsn]

  @impl Mix.Task
  def run(args) do
    {options, package_names, invalid} =
      OptionParser.parse(args, strict: @switches, aliases: @aliases)

    unless invalid == [], do: Mix.raise("Invalid options: #{inspect(invalid)}")

    package_name =
      case package_names do
        [] -> nil
        [name] -> name
        _ -> Mix.raise("Specify only one package name")
      end

    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(fn -> MixGrispIo.Delete.run(options, package_name) end)
  end
end
