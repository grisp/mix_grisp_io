defmodule :"Elixir.Mix.Tasks.Grisp-io.Reboot" do
  use Mix.Task

  @shortdoc false
  @moduledoc "Requests a reboot of a GRiSP.io device."

  @switches [device: :string]
  @aliases [d: :device]

  @impl Mix.Task
  def run(args) do
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(fn -> MixGrispIo.Reboot.run(options) end)
  end
end
