defmodule :"Elixir.Mix.Tasks.Grisp-io.Validate" do
  use Mix.Task

  @shortdoc false
  @moduledoc "Validates an update with `mix grisp-io.validate --device SERIAL`."

  @switches [device: :string]
  @aliases [d: :device]

  @impl Mix.Task
  def run(args) do
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(fn -> MixGrispIo.Validate.run(options) end)
  end
end
