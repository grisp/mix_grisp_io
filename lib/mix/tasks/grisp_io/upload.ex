defmodule :"Elixir.Mix.Tasks.Grisp-io.Upload" do
  use Mix.Task

  @shortdoc false
  @moduledoc """
  Builds (or reuses) and uploads a GRiSP software update package.

      mix grisp-io.upload [--force] [--refresh] [--relname NAME] [--relvsn VERSION]
  """

  @switches [relname: :string, relvsn: :string, force: :boolean, refresh: :boolean]
  @aliases [n: :relname, v: :relvsn, f: :force, r: :refresh]

  @impl Mix.Task
  def run(args) do
    {options, release_args} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(fn -> MixGrispIo.Upload.run(options, release_args) end)
  end
end
