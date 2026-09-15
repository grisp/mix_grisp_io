defmodule :"Elixir.Mix.Tasks.Grisp-io.Cancel" do
  use Mix.Task

  @shortdoc false
  @moduledoc "Cancels an update running on a GRiSP.io device."

  @switches [device: :string]
  @aliases [d: :device]

  @impl Mix.Task
  def run(args) do
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(fn -> MixGrispIo.Cancel.run(options) end)
  end
end
