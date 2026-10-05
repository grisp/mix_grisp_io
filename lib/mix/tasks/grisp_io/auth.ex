defmodule :"Elixir.Mix.Tasks.Grisp-io.Auth" do
  use Mix.Task

  @shortdoc false
  @moduledoc """
  Authenticates through the browser and saves an API token.

      mix grisp-io.auth [--credentials] [--encrypt-token=true|false]

  Use --credentials for username/password login. Without --encrypt-token,
  encryption is offered after login, defaulting to no.
  """

  @impl Mix.Task
  def run(args) do
    {options, extra} =
      MixGrisp.CLI.parse!(args, [credentials: :boolean, encrypt_token: :string], [])

    unless extra == [], do: Mix.raise("Unexpected arguments: #{Enum.join(extra, " ")}")

    if Keyword.has_key?(options, :encrypt_token) and
         options[:encrypt_token] not in ["true", "false"],
       do: Mix.raise("--encrypt-token must be true or false")

    MixGrispIo.ensure_started!()
    MixGrispIo.Command.handle_errors(fn -> MixGrispIo.Auth.run(options) end)
  end
end
