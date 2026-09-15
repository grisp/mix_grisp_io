defmodule MixGrispIo.LiveAPITest do
  use ExUnit.Case, async: false

  @moduletag :live_api

  alias MixGrispIo.{API, Auth, Cancel, Config, Deauth, Delete, Error, List}

  @environment ~w(GRISP_CI_USERNAME GRISP_CI_PASSWORD GRISP_CI_DEVICE)
  @local_password "grisp-ci-local-password"
  @package_name "grisp2.grisp_io_robot.0.1.0.tar"

  defmodule LiveIO do
    def ask(prompt, _type) do
      Process.get({:live_answer, prompt}) || raise "no live test answer for #{prompt}"
    end

    def success(message), do: send(self(), {:success, IO.iodata_to_binary(message)})
    def info(message), do: send(self(), {:info, IO.iodata_to_binary(message)})
  end

  setup do
    credentials = credentials!()

    config_dir =
      Path.join(System.tmp_dir!(), "mix_grisp_io_live_#{System.unique_integer([:positive])}")

    package_path = Path.join(config_dir, @package_name)
    File.mkdir_p!(config_dir)
    File.write!(package_path, :binary.copy(<<0>>, 1024))

    previous_io = Application.get_env(:mix_grisp_io, :io_module)
    previous_config_dir = Application.get_env(:mix_grisp_io, :config_dir)
    Application.put_env(:mix_grisp_io, :io_module, LiveIO)
    Application.put_env(:mix_grisp_io, :config_dir, config_dir)

    Process.put({:live_answer, "Username"}, credentials.username)
    Process.put({:live_answer, "Password"}, credentials.password)
    Process.put({:live_answer, "Local password"}, @local_password)
    Process.put({:live_answer, "Confirm your local password"}, @local_password)

    on_exit(fn ->
      restore_env(:io_module, previous_io)
      restore_env(:config_dir, previous_config_dir)
      File.rm_rf!(config_dir)
    end)

    {:ok,
     Map.merge(credentials, %{
       package_name: @package_name,
       package_path: package_path
     })}
  end

  test "auth and deauth request and revoke a live token" do
    assert :ok = Auth.run()
    token = stored_token()
    on_exit(fn -> deauth(token) end)

    assert is_binary(token) and byte_size(token) > 0
    assert :ok = Deauth.run()
    refute File.exists?(Config.path())

    assert_raise Error, "Wrong credentials", fn ->
      API.list_packages(token)
    end
  end

  test "upload, list, and named delete use the live package API", context do
    token = authenticate_and_store(context)

    on_exit(fn ->
      delete_package(token, context.package_name)
      deauth(token)
    end)

    assert :ok =
             API.update_package(
               token,
               context.package_name,
               context.package_path,
               true
             )

    assert Enum.any?(API.list_packages(token), &(&1["name"] == context.package_name))

    assert :ok = List.run()
    assert_received {:info, "NAME  APPLICATION  VERSION  PLATFORM  LAST MODIFIED"}

    assert :ok = Delete.run([], context.package_name)
    refute Enum.any?(API.list_packages(token), &(&1["name"] == context.package_name))

    assert :ok = List.run()
    assert_received {:info, "No update packages found."}
  end

  test "deploy and cancel operate on the configured live device", context do
    token = authenticate_and_store(context)

    on_exit(fn ->
      cancel_update(token, context.device)
      delete_package(token, context.package_name)
      deauth(token)
    end)

    assert :ok =
             API.update_package(
               token,
               context.package_name,
               context.package_path,
               true
             )

    assert :ok = API.deploy_update(token, context.package_name, context.device)
    assert :ok = Cancel.run(device: context.device)
    expected = "Update cancellation requested for device ##{context.device}"
    assert_received {:success, ^expected}
  end

  defp authenticate_and_store(context) do
    token = API.auth(context.username, context.password)
    encrypted = Config.encrypt_token(@local_password, token)
    Config.write(%{username: context.username, encrypted_token: encrypted})
    token
  end

  defp stored_token do
    %{encrypted_token: encrypted} = Config.read()
    Config.decrypt_token(@local_password, encrypted)
  end

  defp credentials! do
    values = Map.new(@environment, &{&1, System.get_env(&1)})
    missing = Enum.filter(@environment, &(values[&1] in [nil, ""]))

    if missing != [] do
      raise "missing live API environment variables: #{Enum.join(missing, ", ")}"
    end

    %{
      username: values["GRISP_CI_USERNAME"],
      password: values["GRISP_CI_PASSWORD"],
      device: values["GRISP_CI_DEVICE"]
    }
  end

  defp delete_package(token, package) do
    API.delete_package(token, package)
  rescue
    error in Error -> if error.reason != :package_not_found, do: reraise(error, __STACKTRACE__)
  end

  defp cancel_update(token, device) do
    API.cancel_update(token, device)
  rescue
    error in Error ->
      case error.reason do
        {:api_error, _state} -> :ok
        :device_does_not_exist -> :ok
        _other -> reraise(error, __STACKTRACE__)
      end
  end

  defp deauth(token) do
    API.deauth(token)
  rescue
    error in Error -> if error.reason != :wrong_credentials, do: reraise(error, __STACKTRACE__)
  end

  defp restore_env(key, nil), do: Application.delete_env(:mix_grisp_io, key)
  defp restore_env(key, value), do: Application.put_env(:mix_grisp_io, key, value)
end
