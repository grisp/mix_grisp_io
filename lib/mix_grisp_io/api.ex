defmodule MixGrispIo.API do
  @moduledoc "HTTP client for the GRiSP.io authentication and update endpoints."

  alias MixGrispIo.Error

  @default_base_url "https://app.grisp.io"

  @spec auth(binary(), binary(), keyword()) :: binary()
  def auth(username, password, options \\ []) do
    {:ok, hostname} = :inet.gethostname()
    body = :jsx.encode(%{name: to_string(hostname)})

    headers = [
      {"authorization", basic_auth(username, password)},
      {"content-type", "application/json"},
      {"content-length", Integer.to_string(IO.iodata_length(body))}
    ]

    case request(:post, url(options, "/eresu/api/auth"), headers, body, options) do
      {:ok, 200, _headers, client} ->
        %{"token" => token} = response_json!(client, options)
        token

      {:ok, 401, _, _} ->
        raise Error, :wrong_credentials

      {:ok, 403, _, _} ->
        raise Error, :token_limit_reached

      other ->
        raise Error, {:http_error, other}
    end
  end

  @spec deauth(binary(), keyword()) :: :ok
  def deauth(token, options \\ []) do
    body = "{}"

    case request(:post, url(options, "/eresu/api/deauth"), json_headers(token, 2), body, options) do
      {:ok, 200, _, _} -> :ok
      {:ok, 401, _, _} -> raise Error, :wrong_credentials
      other -> raise Error, {:http_error, other}
    end
  end

  @spec list_packages(binary(), keyword()) :: [map()]
  def list_packages(token, options \\ []) do
    case request(
           :get,
           url(options, "/grisp-manager/api/update-package"),
           [{"authorization", bearer(token)}],
           "",
           options
         ) do
      {:ok, 200, _, client} ->
        %{"packages" => packages} = response_json!(client, options)
        packages

      {:ok, 401, _, _} ->
        raise Error, :wrong_credentials

      {:ok, 403, _, _} ->
        raise Error, :forbidden

      other ->
        raise Error, {:http_error, other}
    end
  end

  @spec update_package(binary(), binary(), Path.t(), boolean(), keyword()) :: :ok
  def update_package(token, package_name, package_path, force, options \\ []) do
    size = File.stat!(package_path).size

    headers =
      [
        {"authorization", bearer(token)},
        {"content-type", "application/octet-stream"},
        {"content-length", Integer.to_string(size)}
      ] ++ if(force, do: [], else: [{"if-none-match", ~s("#{package_name}")}])

    request_options =
      options
      |> Keyword.put(:recv_timeout, :infinity)
      |> Keyword.put(:protocols, [:http1])

    body =
      case File.read(package_path) do
        {:ok, contents} -> contents
        {:error, reason} -> raise Error, {:package_file_error, package_path, reason}
      end

    case request(
           :put,
           url(options, "/grisp-manager/api/update-package/#{package_name}"),
           headers,
           body,
           request_options
         ) do
      {:ok, status, _, _} when status in [201, 204] ->
        :ok

      {:ok, 400, _, client} ->
        consume_body(client, options)
        raise Error, :unknown_request

      {:ok, 401, _, _} ->
        raise Error, :wrong_credentials

      {:ok, 403, _, _} ->
        raise Error, :forbidden

      {:ok, 409, _, _} ->
        raise Error, :package_limit_reached

      {:ok, 412, _, _} ->
        raise Error, :package_already_exists

      {:ok, 413, _, _} ->
        raise Error, :package_too_big

      other ->
        raise Error, {:http_error, other}
    end
  end

  @spec delete_package(binary(), binary(), keyword()) :: :ok
  def delete_package(token, package_name, options \\ []) do
    headers = [{"authorization", bearer(token)}]

    case request(
           :delete,
           url(options, "/grisp-manager/api/update-package/#{package_name}"),
           headers,
           "",
           options
         ) do
      {:ok, 204, _, _} ->
        :ok

      {:ok, 400, _, client} ->
        consume_body(client, options)
        raise Error, :unknown_request

      {:ok, 401, _, _} ->
        raise Error, :wrong_credentials

      {:ok, 403, _, _} ->
        raise Error, :forbidden

      {:ok, 404, _, _} ->
        raise Error, :package_not_found

      other ->
        raise Error, {:http_error, other}
    end
  end

  @spec deploy_update(binary(), binary(), binary(), keyword()) :: :ok
  def deploy_update(token, package_name, device, options \\ []) do
    query = device_query(device, options)
    endpoint = "/grisp-manager/api/deploy-update/#{package_name}?#{query}"

    case request(:post, url(options, endpoint), json_headers(token, 0), "", options) do
      {:ok, 204, _, _} ->
        :ok

      {:ok, 400, _, client} ->
        %{"error" => error} = response_json!(client, options)
        raise Error, {:api_error, error}

      {:ok, 401, _, _} ->
        raise Error, :wrong_credentials

      {:ok, 404, _, _} ->
        if Enum.any?(list_packages(token, options), &(&1["name"] == package_name)) do
          raise Error, {:device_does_not_exist, device}
        else
          raise Error, {:package_does_not_exist, package_name}
        end

      other ->
        raise Error, {:http_error, other}
    end
  end

  @spec validate_update(binary(), binary(), keyword()) :: :ok
  def validate_update(token, device, options \\ []) do
    endpoint = "/grisp-manager/api/validate-update/#{device}?#{device_query(device, options)}"

    case request(:post, url(options, endpoint), json_headers(token, 0), "", options) do
      {:ok, 204, _, _} ->
        :ok

      {:ok, 400, _, client} ->
        %{"error" => error} = response_json!(client, options)
        raise Error, {:api_error, error}

      {:ok, 401, _, _} ->
        raise Error, :wrong_credentials

      {:ok, 403, _, _} ->
        raise Error, :forbidden

      {:ok, 404, _, _} ->
        raise Error, :device_does_not_exist

      other ->
        raise Error, {:http_error, other}
    end
  end

  @spec cancel_update(binary(), binary(), keyword()) :: :ok
  def cancel_update(token, device, options \\ []) do
    device_request(token, "/grisp-manager/api/cancel-update", device, options)
  end

  @spec reboot_device(binary(), binary(), keyword()) :: :ok
  def reboot_device(token, device, options \\ []) do
    device_request(token, "/grisp-manager/api/reboot-device", device, options)
  end

  defp device_request(token, endpoint, device, options) do
    endpoint = endpoint <> "?" <> device_query(device, options)

    case request(:post, url(options, endpoint), json_headers(token, 0), "", options) do
      {:ok, 204, _, _} ->
        :ok

      {:ok, 400, _, client} ->
        %{"error" => error} = response_json!(client, options)
        raise Error, {:api_error, error}

      {:ok, 401, _, _} ->
        raise Error, :wrong_credentials

      {:ok, 403, _, _} ->
        raise Error, :forbidden

      {:ok, 404, _, _} ->
        raise Error, :device_does_not_exist

      other ->
        raise Error, {:http_error, other}
    end
  end

  defp request(method, url, headers, body, options) do
    client = Keyword.get(options, :http_client, :hackney)
    client.request(method, url, headers, body, http_options(options))
  end

  defp response_json!(client, options) do
    client
    |> response_body(options)
    |> :jsx.decode([:return_maps])
  end

  defp consume_body(client, options), do: response_body(client, options)

  defp response_body(body, _options) when is_binary(body), do: body

  defp response_body(client, options) do
    {:ok, body} = http_client(options).body(client)
    body
  end

  defp http_client(options), do: Keyword.get(options, :http_client, :hackney)

  defp http_options(options) do
    selected = Keyword.take(options, [:recv_timeout, :protocols])
    selected = [:with_body | selected]
    if insecure?(options), do: [:insecure | selected], else: selected
  end

  defp insecure?(options) do
    Keyword.get_lazy(options, :insecure, fn ->
      Application.get_env(:mix_grisp_io, :insecure) || project_option(:insecure) || false
    end)
  end

  defp url(options, endpoint), do: base_url(options) <> endpoint

  defp base_url(options) do
    options[:base_url] ||
      Application.get_env(:mix_grisp_io, :base_url) ||
      project_option(:base_url) ||
      @default_base_url
  end

  defp project_option(key) do
    if Mix.Project.get() do
      Mix.Project.config() |> Keyword.get(:grisp_io, []) |> Keyword.get(key)
    end
  end

  defp basic_auth(username, password), do: "Basic " <> Base.encode64(username <> ":" <> password)
  defp bearer(token), do: "Bearer " <> token

  defp device_query(device, options) do
    platform = options[:platform] || MixGrisp.Config.platform()
    URI.encode_query(%{"serial_number" => device, "platform" => to_string(platform)})
  end

  defp json_headers(token, length),
    do: [
      {"authorization", bearer(token)},
      {"content-type", "application/json"},
      {"content-length", Integer.to_string(length)}
    ]
end
