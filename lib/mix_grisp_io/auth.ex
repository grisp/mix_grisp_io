defmodule MixGrispIo.Auth do
  @moduledoc false

  alias MixGrispIo.{Command, Error}

  def run do
    io = Command.io()
    username = io.ask("Username", :string)
    password = io.ask("Password", :password)
    token = Command.api().auth(username, password)

    io.success("Authentication successful - Please provide new local password")
    local_password = io.ask("Local password", :password)
    confirmation = io.ask("Confirm your local password", :password)

    if local_password != confirmation, do: raise(Error, :local_passwords_do_not_match)

    encrypted = Command.config().encrypt_token(local_password, token)
    Command.config().write(%{username: username, encrypted_token: encrypted})
    io.success("Token successfully requested")
    :ok
  end
end
