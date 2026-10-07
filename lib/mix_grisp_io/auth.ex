defmodule MixGrispIo.Auth do
  @moduledoc false

  alias MixGrispIo.{Command, Error, PKCE}

  def run(options \\ []) do
    {token, metadata} =
      if Keyword.get(options, :credentials, false) do
        username = Command.io().ask("Username", :string)
        password = Command.io().ask("Password", :password)
        {Command.api().auth(username, password), %{username: username}}
      else
        {PKCE.auth(), %{}}
      end

    config =
      if encryption_choice(Keyword.get(options, :encrypt_token)) do
        Command.io().success("Please provide a local password to encrypt the token")
        password = Command.io().ask("Local password", :password)
        confirmation = Command.io().ask("Confirm your local password", :password)
        if password != confirmation, do: raise(Error, :local_passwords_do_not_match)
        %{encrypted_token: Command.config().encrypt_token(password, token)}
      else
        %{token: token}
      end

    Command.config().write(Map.merge(config, metadata))
    Command.io().success("Token successfully requested")
    :ok
  end

  defp encryption_choice(nil) do
    response =
      Command.io().ask("Do you want to protect your token with a passphrase? (y/N)", :string, "n")

    case String.downcase(response) do
      choice when choice in ["y", "yes"] ->
        true

      choice when choice in ["n", "no"] ->
        false

      _ ->
        Command.io().info("Please answer yes or no")
        encryption_choice(nil)
    end
  end

  defp encryption_choice(choice) when choice in [true, "true"], do: true
  defp encryption_choice(choice) when choice in [false, "false"], do: false
  defp encryption_choice(_), do: raise(Error, :invalid_encrypt_token_choice)
end
