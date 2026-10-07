defmodule MixGrispIo.PKCETest do
  use ExUnit.Case, async: false

  alias MixGrispIo.{Auth, Error, PKCE}

  defmodule IOStub do
    def info(_), do: :ok
    def success(_), do: :ok

    def read_line(prompt) do
      state = Application.fetch_env!(:mix_grisp_io, :pkce_test_state)

      {owner, input, callback} =
        Agent.get_and_update(state, fn data ->
          [input | rest] = data.inputs
          {{data.owner, input, Map.get(data, :callback_pid)}, %{data | inputs: rest}}
        end)

      send(owner, {:prompt, self(), prompt})
      if callback, do: send(callback, :start)

      case input do
        :pending -> receive do: (:stop -> :eof)
        value -> value
      end
    end
  end

  defmodule ConfigStub do
    def write(config), do: send(self(), {:config_written, config})
  end

  defmodule APIStub do
    def cli_session(challenge, nonce, port) do
      data = Agent.get(Application.fetch_env!(:mix_grisp_io, :pkce_test_state), & &1)
      send(self(), {:session, challenge, nonce, port})
      Process.put(:pkce_session, {challenge, port})

      if data.callback do
        owner = self()

        pid =
          spawn_link(fn ->
            receive do
              :start -> data.callback.(port, nonce)
            end

            send(owner, {:callback_complete, self()})
          end)

        Agent.update(
          Application.fetch_env!(:mix_grisp_io, :pkce_test_state),
          &Map.put(&1, :callback_pid, pid)
        )
      end

      %{"id" => "session", "auth_url" => "https://example.test/login"}
    end

    def cli_redeem("session", code, verifier) do
      {challenge, port} = Process.get(:pkce_session)

      if Base.url_encode64(:crypto.hash(:sha256, verifier), padding: false) != challenge,
        do: raise("PKCE challenge does not match verifier")

      case :gen_tcp.connect({127, 0, 0, 1}, port, [active: false], 1_000) do
        {:error, :econnrefused} -> :ok
        other -> raise "Listener still open at redemption: #{inspect(other)}"
      end

      send(self(), {:redeemed, code, verifier})
      "access-token"
    end
  end

  setup %{tmp_dir: directory} do
    owner = self()
    {:ok, state} = Agent.start_link(fn -> %{owner: owner, inputs: [:eof], callback: nil} end)
    keys = [:io_module, :api_module, :config_module, :pkce_test_state]
    previous = Map.new(keys, &{&1, Application.fetch_env(:mix_grisp_io, &1)})
    Application.put_env(:mix_grisp_io, :io_module, IOStub)
    Application.put_env(:mix_grisp_io, :api_module, APIStub)
    Application.put_env(:mix_grisp_io, :config_module, ConfigStub)
    Application.put_env(:mix_grisp_io, :pkce_test_state, state)

    old_path = System.get_env("PATH")
    old_url = System.get_env("MIX_GRISP_PKCE_TEST_URL")
    url_file = Path.join(directory, "browser-url")
    System.put_env("PATH", directory <> ":" <> old_path)
    System.put_env("MIX_GRISP_PKCE_TEST_URL", url_file)

    for name <- ["open", "xdg-open"] do
      path = Path.join(directory, name)
      File.write!(path, "#!/bin/sh\nprintf '%s' \"$1\" > \"$MIX_GRISP_PKCE_TEST_URL\"\n")
      File.chmod!(path, 0o700)
    end

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:mix_grisp_io, key, value)
        {key, :error} -> Application.delete_env(:mix_grisp_io, key)
      end)

      System.put_env("PATH", old_path)

      if old_url,
        do: System.put_env("MIX_GRISP_PKCE_TEST_URL", old_url),
        else: System.delete_env("MIX_GRISP_PKCE_TEST_URL")
    end)

    %{state: state, url_file: url_file}
  end

  @tag :tmp_dir
  test "browser auth rejects invalid callbacks and redeems the correct PKCE proof", context do
    callback = fn port, nonce ->
      assert request(port, "POST", :jsx.encode(%{nonce: "wrong", code: "code"})) == 400
      assert request(port, "POST", :jsx.encode(%{nonce: nonce, code: ""})) == 400
      assert request(port, "OPTIONS", "") == 204
      assert request(port, "POST", "invalid-json") == 400
      assert request(port, "POST", String.duplicate("x", 4097)) == 404
      assert request(port, "POST", "{}", ["Content-Length: 2\r\n"]) == 400
      assert request(port, "POST", :jsx.encode(%{nonce: nonce, code: "browser-code"})) == 200
    end

    Agent.update(context.state, &%{&1 | callback: callback})
    assert :ok = Auth.run(encrypt_token: false)
    assert_received {:config_written, %{token: "access-token"}}
    assert_receive {:session, challenge, nonce, port}
    assert byte_size(challenge) == 43
    assert byte_size(nonce) == 32
    assert is_integer(port) and port > 0
    assert_received {:redeemed, "browser-code", verifier}
    assert byte_size(verifier) == 43
    assert_receive {:callback_complete, callback}
    reference = Process.monitor(callback)
    assert_receive {:DOWN, ^reference, :process, ^callback, _}
    assert File.read!(context.url_file) == "https://example.test/login"
    assert_workers_stopped()
  end

  @tag :tmp_dir
  test "browser callback stops a pending terminal reader", context do
    callback = fn port, nonce ->
      assert request(port, "POST", :jsx.encode(%{nonce: nonce, code: "code"})) == 200
    end

    Agent.update(context.state, &%{&1 | inputs: [:pending], callback: callback})
    assert PKCE.auth() == "access-token"
    assert_receive {:callback_complete, callback}
    reference = Process.monitor(callback)
    assert_receive {:DOWN, ^reference, :process, ^callback, _}
    assert_workers_stopped()
  end

  @tag :tmp_dir
  test "pasted code wins and stops the callback listener", context do
    Agent.update(context.state, &%{&1 | inputs: ["  pasted-code\n"]})
    assert PKCE.auth() == "access-token"
    assert_received {:redeemed, "pasted-code", _}
    assert_workers_stopped()
  end

  @tag :tmp_dir
  test "blank terminal input creates a new reader and accepts the next code", context do
    Agent.update(context.state, &%{&1 | inputs: [" \n", "second-code\n"]})
    assert PKCE.auth() == "access-token"
    assert_received {:redeemed, "second-code", _}
    assert_receive {:prompt, first, _}
    assert_receive {:prompt, second, _}
    refute first == second
    refute Process.alive?(first)
    refute Process.alive?(second)
    refute_receive {_, :input, _}
  end

  @tag :tmp_dir
  test "browser launch failure closes the listener without redeeming", context do
    for name <- ["open", "xdg-open"] do
      File.write!(Path.join(context.tmp_dir, name), "#!/bin/sh\nexit 7\n")
    end

    error = assert_raise Error, fn -> PKCE.auth() end
    assert error.reason == {:cli_browser_failed, {:exit_status, 7}}
    assert_receive {:session, _, _, port}
    assert {:error, :econnrefused} = :gen_tcp.connect({127, 0, 0, 1}, port, [active: false], 1000)
    refute_received {:redeemed, _, _}
    refute_received {:prompt, _, _}
  end

  defp assert_workers_stopped do
    assert_receive {:prompt, pid, "Paste the authentication code if prompted: "}
    refute Process.alive?(pid)
    refute_receive {_, :input, _}
    refute_receive {_, :callback, _}
  end

  defp request(port, method, body, extra_headers \\ []) do
    {:ok, socket} =
      :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false, packet: :http_bin], 1000)

    try do
      :ok =
        :gen_tcp.send(socket, [
          method,
          " /callback HTTP/1.1\r\n",
          "Host: localhost\r\nContent-Type: text/plain\r\n",
          "Content-Length: #{byte_size(body)}\r\n",
          extra_headers,
          "\r\n",
          body
        ])

      {:ok, {:http_response, _, status, _}} = :gen_tcp.recv(socket, 0, 1000)
      status
    after
      :gen_tcp.close(socket)
    end
  end
end
