defmodule MixGrispIo.Reboot do
  @moduledoc false

  alias MixGrispIo.Command

  def run(options) do
    device = Command.device!(options[:device])
    Command.api().reboot_device(Command.token!(), device)
    Command.io().success("Reboot requested for device ##{device}")
    :ok
  end
end
