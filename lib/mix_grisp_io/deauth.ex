defmodule MixGrispIo.Deauth do
  @moduledoc false

  alias MixGrispIo.{Command, Error}

  def run do
    token = Command.token!()

    try do
      Command.api().deauth(token)
      Command.config().delete()
      Command.io().success("Authentication token successfully revoked")
    rescue
      error in Error ->
        if error.reason == :wrong_credentials do
          Command.config().delete()

          Command.io().success(
            "Authentication token is no longer valid; local credentials removed"
          )
        else
          reraise error, __STACKTRACE__
        end
    end

    :ok
  end
end
