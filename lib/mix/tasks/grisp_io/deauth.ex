defmodule :"Elixir.Mix.Tasks.Grisp-io.Deauth" do
  use Mix.Task

  @shortdoc false
  @moduledoc "Revokes the current GRiSP.io token and removes local credentials."

  @impl Mix.Task
  def run(args) do
    unless args == [], do: Mix.raise("Unexpected arguments: #{Enum.join(args, " ")}")
    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(&MixGrispIo.Deauth.run/0)
  end
end
