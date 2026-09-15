defmodule MixGrispIo.Validate do
  @moduledoc false

  alias MixGrispIo.Command

  def run(options) do
    device = Command.device!(options[:device])
    Command.api().validate_update(Command.token!(), device)
    Command.io().success("Update validated for device ##{device}")
    :ok
  end
end
