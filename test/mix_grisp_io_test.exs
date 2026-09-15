defmodule MixGrispIoTest do
  use ExUnit.Case, async: true

  alias MixGrispIo.{Config, Error}

  setup do
    directory = Path.join(System.tmp_dir!(), "mix_grisp_io_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(directory) end)
    %{config_dir: directory}
  end

  test "encrypts, decrypts, and persists a token in the rebar-compatible format", context do
    token = "abcdefghijklmnop"
    encrypted = Config.encrypt_token("s3cur3pa55w0rd", token)
    config = %{username: "Test", encrypted_token: encrypted}

    assert encrypted.encrypted_token != token
    assert Config.decrypt_token("s3cur3pa55w0rd", encrypted) == token
    assert :ok = Config.write(config, config_dir: context.config_dir)
    assert Config.read(config_dir: context.config_dir) == config

    assert_raise Error, "Wrong local password", fn ->
      Config.decrypt_token("bad-password", encrypted)
    end
  end

  test "uses the same 256-bit zero-padded password rule as rebar3_grisp_io" do
    assert_raise Error, "Local password must be shorter than 32 bytes", fn ->
      Config.encrypt_token(:binary.copy("x", 32), "token")
    end
  end

  test "reports a missing configuration", context do
    assert_raise Error, "No GRiSP.io configuration is available", fn ->
      Config.read(config_dir: context.config_dir)
    end
  end

  test "validates device serial numbers" do
    assert MixGrispIo.Command.device!(1337) == "1337"
    assert MixGrispIo.Command.device!("001337") == "001337"
    assert MixGrispIo.Command.device!("ci-dummy") == "ci-dummy"

    assert_raise Error, fn -> MixGrispIo.Command.device!("") end
    assert_raise Error, fn -> MixGrispIo.Command.device!(nil) end
  end

  test "deletes a configuration and treats a missing file as already deleted", context do
    config = %{
      username: "Test",
      encrypted_token: Config.encrypt_token("password", "token")
    }

    assert :ok = Config.write(config, config_dir: context.config_dir)
    assert :ok = Config.delete(config_dir: context.config_dir)
    refute File.exists?(Config.path(config_dir: context.config_dir))
    assert :ok = Config.delete(config_dir: context.config_dir)
  end
end
