defmodule MixGrispIo.Error do
  @moduledoc "An error returned by the GRiSP.io HTTP or configuration layer."

  defexception [:reason, :message]

  @impl Exception
  def exception(reason), do: %__MODULE__{reason: reason, message: reason_message(reason)}

  @impl Exception
  def message(%__MODULE__{message: message}), do: message

  defp reason_message(:wrong_credentials), do: "Wrong credentials"
  defp reason_message(:token_limit_reached), do: "Maximum number of tokens per user reached"
  defp reason_message(:forbidden), do: "No permission to perform this operation"
  defp reason_message(:package_limit_reached), do: "The uploaded package limit has been reached"
  defp reason_message(:package_already_exists), do: "A package already exists for this release"
  defp reason_message(:package_too_big), do: "Package size is too big"
  defp reason_message(:package_not_found), do: "Package not found"
  defp reason_message(:device_does_not_exist), do: "The device does not exist or is not linked"
  defp reason_message(:wrong_local_password), do: "Wrong local password"
  defp reason_message(:local_password_too_big), do: "Local password must be shorter than 32 bytes"
  defp reason_message(:no_configuration), do: "No GRiSP.io configuration is available"

  defp reason_message(:local_passwords_do_not_match),
    do: "The local password entries do not match"

  defp reason_message({:package_does_not_exist, name}), do: "Package #{name} does not exist"

  defp reason_message({:device_does_not_exist, device}),
    do: "Device #{device} does not exist or is not linked"

  defp reason_message({:package_file_error, path, reason}),
    do: "Could not read package file #{path}: #{:file.format_error(reason)}"

  defp reason_message({:package_file_not_found, path}), do: "Package file #{path} not found"
  defp reason_message({:api_error, error}) when is_binary(error), do: error
  defp reason_message({:http_error, error}), do: "GRiSP.io request failed: #{inspect(error)}"
  defp reason_message(reason), do: inspect(reason)
end
