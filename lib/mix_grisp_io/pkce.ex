defmodule MixGrispIo.PKCE do
  @moduledoc false

  alias MixGrispIo.{Command, Error}

  @login_timeout 300_000
  @request_timeout 10_000
  @max_body 4096

  def auth do
    verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    challenge = Base.url_encode64(:crypto.hash(:sha256, verifier), padding: false)
    nonce = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
    deadline = now() + @login_timeout
    listener = open_listener()

    try do
      {:ok, port} = :inet.port(listener)
      Command.io().info("Opening a CLI login session")
      %{"id" => id, "auth_url" => url} = Command.api().cli_session(challenge, nonce, port)
      Command.io().info("Opening browser: #{url}")
      open_browser(url)
      Command.io().info("Waiting for approval")
      code = receive_code(listener, nonce, deadline)
      :gen_tcp.close(listener)
      Command.io().info("Redeeming the authentication code")
      token = Command.api().cli_redeem(id, code, verifier)
      Command.io().info("Access token received")
      token
    after
      :gen_tcp.close(listener)
    end
  end

  defp open_listener do
    case :gen_tcp.listen(0, [
           :binary,
           active: false,
           packet: :http_bin,
           packet_size: 8192,
           reuseaddr: true,
           ip: {127, 0, 0, 1}
         ]) do
      {:ok, listener} -> listener
      {:error, reason} -> raise Error, {:cli_listener_failed, reason}
    end
  end

  # The callback and terminal input run independently; the first valid code wins.
  defp receive_code(listener, nonce, deadline) do
    parent = self()
    tag = make_ref()

    callback =
      spawn_monitor(fn ->
        send(parent, {tag, :callback, accept_code(listener, nonce, deadline)})
      end)

    prompt = start_prompt(parent, tag)

    try do
      await_code(tag, callback, prompt, deadline)
    after
      stop_worker(callback)
      # Each replacement prompt is owned by await_code and cleaned up there.
      stop_worker(prompt)
      flush_results(tag)
    end
  end

  defp start_prompt(parent, tag) do
    spawn_monitor(fn ->
      send(parent, {tag, :input, IO.gets("Paste the authentication code if prompted: ")})
    end)
  end

  defp await_code(
         tag,
         {callback_pid, callback_ref} = callback,
         {prompt_pid, prompt_ref} = prompt,
         deadline
       ) do
    receive do
      {^tag, :callback, code} ->
        code

      {^tag, :input, line} when is_binary(line) ->
        case String.trim(line) do
          "" ->
            next_prompt = start_prompt(self(), tag)

            try do
              await_code(tag, callback, next_prompt, deadline)
            after
              stop_worker(next_prompt)
            end

          code ->
            code
        end

      {^tag, :input, _eof_or_error} ->
        await_code(tag, callback, prompt, deadline)

      {:DOWN, ^prompt_ref, :process, ^prompt_pid, _reason} ->
        await_code(tag, callback, prompt, deadline)

      {:DOWN, ^callback_ref, :process, ^callback_pid, reason} ->
        case reason do
          {%Error{} = error, _stack} -> raise error
          _ -> raise Error, {:cli_listener_failed, reason}
        end
    after
      remaining(deadline) -> raise Error, :cli_login_timeout
    end
  end

  defp stop_worker({pid, reference}) do
    stopped = Process.monitor(pid)
    Process.exit(pid, :kill)

    receive do
      {:DOWN, ^stopped, :process, ^pid, _reason} -> :ok
    end

    Process.demonitor(reference, [:flush])
  end

  defp flush_results(tag) do
    receive do
      {^tag, _, _} -> flush_results(tag)
    after
      0 -> :ok
    end
  end

  defp accept_code(listener, nonce, deadline) do
    case :gen_tcp.accept(listener, remaining(deadline)) do
      {:ok, socket} ->
        result =
          try do
            callback(socket, nonce, deadline)
          rescue
            _ ->
              reply(socket, 400, "Invalid login callback.")
              :retry
          after
            :gen_tcp.close(socket)
          end

        case result do
          {:ok, code} -> code
          :retry -> accept_code(listener, nonce, deadline)
        end

      {:error, :timeout} ->
        raise Error, :cli_login_timeout

      {:error, reason} ->
        raise Error, {:cli_listener_failed, reason}
    end
  end

  defp callback(socket, nonce, deadline) do
    {:ok, {:http_request, method, path, _}} = recv(socket, 0, deadline)
    :ok = :inet.setopts(socket, packet: :httph_bin)
    length = read_headers(socket, deadline, nil, 0)

    case {method, path} do
      {:OPTIONS, {:abs_path, "/callback"}} ->
        reply(socket, 204, "")
        :retry

      {:POST, {:abs_path, "/callback"}}
      when is_integer(length) and length > 0 and length <= @max_body ->
        :ok = :inet.setopts(socket, packet: :raw)
        {:ok, body} = recv(socket, length, deadline)

        case :jsx.decode(body, [:return_maps]) do
          %{"nonce" => ^nonce, "code" => code} when is_binary(code) and byte_size(code) > 0 ->
            :ok = reply(socket, 200, "Login approved. You can return to the terminal.")
            {:ok, code}

          _ ->
            reply(socket, 400, "Invalid login callback.")
            :retry
        end

      _ ->
        reply(socket, 404, "Not found.")
        :retry
    end
  end

  defp read_headers(socket, deadline, length, count) when count < 64 do
    case recv(socket, 0, deadline) do
      {:ok, :http_eoh} ->
        length

      {:ok, {:http_header, _, name, _, value}} ->
        new_length =
          case String.downcase(to_string(name)) do
            "content-length" when is_nil(length) -> String.to_integer(value)
            "content-length" -> raise "Duplicate content length"
            _ -> length
          end

        read_headers(socket, deadline, new_length, count + 1)

      _ ->
        raise "Invalid headers"
    end
  end

  defp read_headers(_, _, _, _), do: raise("Too many headers")

  defp recv(socket, length, deadline),
    do: :gen_tcp.recv(socket, length, min(@request_timeout, remaining(deadline)))

  defp reply(socket, status, body) do
    reason = %{200 => "OK", 204 => "No Content", 400 => "Bad Request", 404 => "Not Found"}[status]

    :gen_tcp.send(socket, [
      "HTTP/1.1 #{status} #{reason}\r\n",
      "Content-Type: text/plain; charset=utf-8\r\n",
      "Connection: close\r\n",
      "Access-Control-Allow-Origin: *\r\n",
      "Access-Control-Allow-Methods: POST, OPTIONS\r\n",
      "Access-Control-Allow-Headers: Content-Type\r\n",
      "Access-Control-Allow-Private-Network: true\r\n",
      "Content-Length: #{byte_size(body)}\r\n\r\n",
      body
    ])
  end

  defp open_browser(url) do
    {command, args} =
      case :os.type() do
        {:unix, :darwin} -> {"open", [url]}
        {:unix, _} -> {"xdg-open", [url]}
        {:win32, _} -> {"rundll32.exe", ["url.dll,FileProtocolHandler", url]}
      end

    executable =
      System.find_executable(command) || raise(Error, {:cli_browser_failed, :browser_not_found})

    browser =
      Port.open(
        {:spawn_executable, to_charlist(executable)},
        [:binary, :exit_status, :use_stdio, :stderr_to_stdout, :hide, args: args]
      )

    try do
      browser_result(browser, now() + @request_timeout)
    after
      try do
        Port.close(browser)
      rescue
        ArgumentError -> :ok
      end
    end
  end

  defp browser_result(browser, deadline) do
    receive do
      {^browser, {:exit_status, 0}} ->
        :ok

      {^browser, {:exit_status, status}} ->
        raise Error, {:cli_browser_failed, {:exit_status, status}}

      {^browser, {:data, _}} ->
        browser_result(browser, deadline)
    after
      max(0, deadline - now()) -> raise Error, {:cli_browser_failed, :timeout}
    end
  end

  defp remaining(deadline) do
    case deadline - now() do
      timeout when timeout > 0 -> timeout
      _ -> raise Error, :cli_login_timeout
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
end
