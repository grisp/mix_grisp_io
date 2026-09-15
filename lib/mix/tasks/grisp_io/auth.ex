defmodule :"Elixir.Mix.Tasks.Grisp-io.Auth" do
  use Mix.Task

  @shortdoc false
  @moduledoc "Authenticates with GRiSP.io and stores an encrypted API token."

  @impl Mix.Task
  def run(args) do
    unless args == [], do: Mix.raise("Unexpected arguments: #{Enum.join(args, " ")}")
    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(&MixGrispIo.Auth.run/0)
  end
end
