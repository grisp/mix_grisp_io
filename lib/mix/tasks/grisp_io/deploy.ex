defmodule :"Elixir.Mix.Tasks.Grisp-io.Deploy" do
  use Mix.Task

  @shortdoc false
  @moduledoc """
  Requests deployment of an uploaded package.

      mix grisp-io.deploy --device SERIAL [--package PACKAGE]
  """

  @switches [relname: :string, relvsn: :string, device: :string, package: :string]
  @aliases [n: :relname, v: :relvsn, d: :device, p: :package]

  @impl Mix.Task
  def run(args) do
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(fn -> MixGrispIo.Deploy.run(options) end)
  end
end
