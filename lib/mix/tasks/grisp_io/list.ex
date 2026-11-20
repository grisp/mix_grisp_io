defmodule :"Elixir.Mix.Tasks.Grisp-io.List" do
  use Mix.Task

  @shortdoc "List update packages"
  @moduledoc "Lists update packages stored on GRiSP.io."

  @impl Mix.Task
  def run(args) do
    unless args == [], do: Mix.raise("Unexpected arguments: #{Enum.join(args, " ")}")
    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(&MixGrispIo.List.run/0)
  end
end
