defmodule MixGrispIo.Command do
  @moduledoc false

  alias MixGrispIo.{API, Config, Error, IO}

  def api, do: Application.get_env(:mix_grisp_io, :api_module, API)
  def config, do: Application.get_env(:mix_grisp_io, :config_module, Config)
  def io, do: Application.get_env(:mix_grisp_io, :io_module, IO)

  def token! do
    %{encrypted_token: encrypted} = config().read()
    password = io().ask("Local password", :password)
    config().decrypt_token(password, encrypted)
  end

  def device!(nil), do: raise(Error, :no_device_serial_number)

  def device!(device) when is_integer(device) and device >= 0,
    do: Integer.to_string(device)

  def device!(device) when is_binary(device) and byte_size(device) > 0, do: device
  def device!(_device), do: raise(Error, :invalid_device_serial_number)

  def handle_errors(fun) do
    fun.()
  rescue
    error in Error -> Mix.raise(error_message(error.reason))
  end

  defp error_message(:no_configuration),
    do: "No configuration available. First run 'mix grisp-io.auth' to authenticate"

  defp error_message(:wrong_local_password), do: "Wrong local password. Try again"

  defp error_message(:no_device_serial_number),
    do: "The serial number of the target device is missing. Specify it with -d or --device"

  defp error_message(:invalid_device_serial_number),
    do: "The serial number of the target device is invalid"

  defp error_message(:package_already_exists),
    do: "A package already exists for this release. Use -f or --force to overwrite it"

  defp error_message(:token_limit_reached),
    do: "Maximum number of tokens reached. Revoke unused tokens and try again"

  defp error_message({:package_does_not_exist, name}),
    do: "Package #{name} does not exist. Upload it before deploying"

  defp error_message({:device_does_not_exist, device}),
    do: "Device #{device} does not exist or is not linked for the configured platform"

  defp error_message({:api_error, "no_process"}), do: "No deployment process is running"
  defp error_message({:api_error, "disconnected"}), do: "The device is not connected to GRiSP.io"

  defp error_message({:api_error, "validate_from_unbooted"}),
    do: "The device needs to be rebooted"

  defp error_message({:api_error, "wait_device"}), do: "Deployment is waiting for the device"
  defp error_message({:api_error, "download"}), do: "The device is still downloading the update"
  defp error_message(reason), do: Exception.message(Error.exception(reason))
end
