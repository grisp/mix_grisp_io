defmodule MixGrispIo.Cancel do
  @moduledoc false

  alias MixGrispIo.Command

  def run(options) do
    device = Command.device!(options[:device])
    Command.api().cancel_update(Command.token!(), device)
    Command.io().success("Update cancellation requested for device ##{device}")
    :ok
  end
end
