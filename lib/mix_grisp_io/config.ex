defmodule MixGrispIo.Config do
  @moduledoc """
  Persists and encrypts the GRiSP.io authentication token.

  Configuration is stored as an Erlang term in `grisp-io.config`, preserving
  compatibility with `rebar3_grisp_io`. Set `MIX_GRISP_IO_CONFIG_DIR` to choose
  another directory.
  """

  alias MixGrispIo.Error

  @config_file "grisp-io.config"
  @aad "LetItCrash"
  @key_bytes 32

  @type encrypted_token :: %{iv: binary(), tag: binary(), encrypted_token: binary()}
  @type t :: %{username: binary(), encrypted_token: encrypted_token()}

  @spec write(t(), keyword()) :: :ok
  def write(config, options \\ []) do
    path = path(options)
    File.mkdir_p!(Path.dirname(path))
    # `~w` forces binaries to numeric bit syntax. Pretty-printing (`~p` or
    # `io_lib:print/1`) may embed arbitrary ciphertext bytes inside a quoted
    # binary, producing a file that cannot be consulted as UTF-8.
    encoded = ["%% coding: utf-8\n", :io_lib.format(~c"~w", [config]), ".\n"]
    File.write!(path, encoded)
  end

  @spec read(keyword()) :: t()
  def read(options \\ []) do
    case :file.consult(to_charlist(path(options))) do
      {:ok, [config]} when is_map(config) -> config
      {:ok, terms} -> raise Error, {:invalid_configuration, terms}
      {:error, :enoent} -> raise Error, :no_configuration
      {:error, reason} -> raise Error, {:configuration_error, reason}
    end
  end

  @spec delete(keyword()) :: :ok
  def delete(options \\ []) do
    case File.rm(path(options)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> raise Error, {:configuration_error, reason}
    end
  end

  @spec encrypt_token(binary(), binary()) :: encrypted_token()
  def encrypt_token(local_password, token)
      when is_binary(local_password) and is_binary(token) do
    key = password_key!(local_password)
    iv = :crypto.strong_rand_bytes(16)
    {encrypted, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, token, @aad, true)
    %{iv: iv, tag: tag, encrypted_token: encrypted}
  end

  @spec decrypt_token(binary(), encrypted_token()) :: binary()
  def decrypt_token(local_password, %{iv: iv, tag: tag, encrypted_token: encrypted}) do
    key = password_key!(local_password)

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, encrypted, @aad, tag, false) do
      :error -> raise Error, :wrong_local_password
      token -> token
    end
  end

  @spec path(keyword()) :: String.t()
  def path(options \\ []) do
    directory =
      options[:config_dir] ||
        Application.get_env(:mix_grisp_io, :config_dir) ||
        System.get_env("MIX_GRISP_IO_CONFIG_DIR") ||
        default_config_dir()

    Path.join(directory, @config_file)
  end

  defp password_key!(password) when byte_size(password) < @key_bytes do
    password <> :binary.copy(<<0>>, @key_bytes - byte_size(password))
  end

  defp password_key!(_password), do: raise(Error, :local_password_too_big)

  defp default_config_dir do
    System.get_env("REBAR_GLOBAL_CONFIG_DIR") ||
      case :os.type() do
        {:win32, _} ->
          Path.join(System.get_env("APPDATA") || System.user_home!(), "rebar3")

        _ ->
          base = System.get_env("XDG_CONFIG_HOME") || Path.join(System.user_home!(), ".config")
          Path.join(base, "rebar3")
      end
  end
end
