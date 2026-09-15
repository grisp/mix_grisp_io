defmodule MixGrispIo.APITest do
  use ExUnit.Case, async: true

  alias MixGrispIo.{API, Error}

  defmodule HTTPStub do
    def request(method, url, headers, body, options) do
      send(self(), {:request, method, url, headers, body, options})

      case Process.get(:http_responses) do
        [response | rest] ->
          Process.put(:http_responses, rest)
          response

        nil ->
          Process.get(:http_response)
      end
    end

    def body(reference), do: {:ok, reference}
  end

  test "auth uses basic authentication and returns the token" do
    Process.put(:http_response, {:ok, 200, [], ~s({"token":"secret"})})

    assert API.auth("user", "password", base_url: "https://example.test", http_client: HTTPStub) ==
             "secret"

    assert_received {:request, :post, "https://example.test/eresu/api/auth", headers, body,
                     [:with_body]}

    assert {"authorization", "Basic " <> encoded} = List.keyfind(headers, "authorization", 0)
    assert Base.decode64!(encoded) == "user:password"
    assert %{"name" => hostname} = :jsx.decode(body, [:return_maps])
    assert is_binary(hostname)
  end

  test "upload sends a fixed-length HTTP/1 body and protects against overwrite",
       context do
    path = Path.join(context.tmp_dir, "grisp2.robot.1.0.0.tar")
    File.write!(path, "package")
    Process.put(:http_response, {:ok, 201, [], :unused})

    assert :ok =
             API.update_package("token", Path.basename(path), path, false,
               base_url: "https://example.test",
               http_client: HTTPStub
             )

    assert_received {:request, :put, url, headers, "package", options}
    assert url == "https://example.test/grisp-manager/api/update-package/#{Path.basename(path)}"
    assert {"if-none-match", ~s("#{Path.basename(path)}")} in headers
    assert {:protocols, [:http1]} in options
    assert {:recv_timeout, :infinity} in options
  end

  test "maps upload status codes to domain errors" do
    Process.put(:http_response, {:ok, 412, [], :unused})
    path = Path.join(System.tmp_dir!(), "mix_grisp_io_api_#{System.unique_integer([:positive])}")
    File.write!(path, "package")
    on_exit(fn -> File.rm(path) end)

    assert_raise Error, "A package already exists for this release", fn ->
      API.update_package("token", "package.tar", path, false, http_client: HTTPStub)
    end
  end

  test "deauth revokes a bearer token" do
    Process.put(:http_response, {:ok, 200, [], "{}"})

    assert :ok = API.deauth("token", base_url: "https://example.test", http_client: HTTPStub)

    assert_received {:request, :post, "https://example.test/eresu/api/deauth", headers, "{}",
                     [:with_body]}

    assert {"authorization", "Bearer token"} in headers
  end

  test "lists packages" do
    body = ~s({"packages":[{"name":"grisp2.robot.1.0.0.tar"}]})
    Process.put(:http_response, {:ok, 200, [], body})

    assert [%{"name" => "grisp2.robot.1.0.0.tar"}] =
             API.list_packages("token",
               base_url: "https://example.test",
               http_client: HTTPStub
             )

    assert_received {:request, :get, "https://example.test/grisp-manager/api/update-package",
                     headers, "", [:with_body]}

    assert {"authorization", "Bearer token"} in headers
  end

  test "device requests include serial number and the mix_grisp platform" do
    Process.put(:http_responses, [
      {:ok, 204, [], :unused},
      {:ok, 204, [], :unused},
      {:ok, 204, [], :unused}
    ])

    options = [base_url: "https://example.test", http_client: HTTPStub, platform: :grisp2]

    assert :ok = API.validate_update("token", "ci-dummy", options)
    assert :ok = API.cancel_update("token", "ci-dummy", options)
    assert :ok = API.reboot_device("token", "ci-dummy", options)

    for endpoint <- ["validate-update/ci-dummy", "cancel-update", "reboot-device"] do
      assert_received {:request, :post, url, _headers, "", [:with_body]}
      assert url =~ "/grisp-manager/api/#{endpoint}?"

      assert URI.decode_query(URI.parse(url).query) == %{
               "platform" => "grisp2",
               "serial_number" => "ci-dummy"
             }
    end
  end

  test "deploy distinguishes a missing device from a missing package" do
    Process.put(:http_responses, [
      {:ok, 404, [], :unused},
      {:ok, 200, [], ~s({"packages":[{"name":"package.tar"}]})}
    ])

    assert_raise Error, "Device ci-dummy does not exist or is not linked", fn ->
      API.deploy_update("token", "package.tar", "ci-dummy",
        http_client: HTTPStub,
        platform: :grisp2
      )
    end

    Process.put(:http_responses, [
      {:ok, 404, [], :unused},
      {:ok, 200, [], ~s({"packages":[]})}
    ])

    assert_raise Error, "Package package.tar does not exist", fn ->
      API.deploy_update("token", "package.tar", "ci-dummy",
        http_client: HTTPStub,
        platform: :grisp2
      )
    end
  end

  setup do
    directory =
      Path.join(System.tmp_dir!(), "mix_grisp_io_api_#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    %{tmp_dir: directory}
  end
end
