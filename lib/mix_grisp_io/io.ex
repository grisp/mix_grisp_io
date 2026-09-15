defmodule MixGrispIo.IO do
  @moduledoc false

  def ask(prompt, type \\ :string)

  def ask(prompt, :password) do
    prompt = "#{prompt} > "
    normalize!(read_hidden_password(prompt))
  end

  def ask(prompt, :string), do: IO.gets("\n#{prompt} > ") |> normalize!()

  def success(message) do
    Mix.shell().info(IO.ANSI.format([:green, IO.iodata_to_binary(message)]))
  end

  def info(message), do: Mix.shell().info(IO.iodata_to_binary(message))

  # `:io.get_password/0` does not reliably suppress echo when invoked by Mix on
  # all terminals. This is the same redraw strategy used by rebar3_grisp_io:
  # while `IO.gets/1` waits for input, a helper continually replaces the line
  # with the prompt and blank space.
  defp read_hidden_password(prompt) do
    over_writer = spawn_link(fn -> overwrite_password_prompt(prompt) end)

    try do
      IO.gets(prompt)
    after
      stop_overwriter(over_writer)
    end
  end

  defp overwrite_password_prompt(prompt) do
    receive do
      {:done, parent, reference} ->
        send(parent, {:done, self(), reference})
        IO.write(:stderr, ["\e[2K", String.duplicate(" ", byte_size(prompt) + 24), "\r"])
    after
      1 ->
        IO.write(:stderr, ["\e[2K", "\r", prompt, String.duplicate(" ", 24), "\r", prompt])
        overwrite_password_prompt(prompt)
    end
  end

  defp stop_overwriter(over_writer) do
    reference = make_ref()
    send(over_writer, {:done, self(), reference})

    receive do
      {:done, ^over_writer, ^reference} -> :ok
    after
      5_000 -> Mix.raise("Timed out while clearing password input")
    end
  end

  defp normalize!(:eof), do: Mix.raise("No input received")
  defp normalize!({:error, reason}), do: Mix.raise("Could not read input: #{inspect(reason)}")

  defp normalize!(value) do
    value
    |> IO.chardata_to_string()
    |> String.trim()
    |> case do
      "" -> Mix.raise("No input received")
      result -> result
    end
  end
end
