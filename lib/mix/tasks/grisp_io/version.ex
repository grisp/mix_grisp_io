defmodule :"Elixir.Mix.Tasks.Grisp-io.Version" do
  use Mix.Task

  @shortdoc false

  @impl Mix.Task
  def run([]) do
    MixGrispIo.ensure_started!()
    Mix.shell().info("mix_grisp_io: #{MixGrispIo.version()}")
  end

  def run(args), do: Mix.raise("Unexpected arguments: #{Enum.join(args, " ")}")
end
