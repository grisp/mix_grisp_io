defmodule MixGrispIo do
  @moduledoc """
  Mix integration for authenticating with and publishing GRiSP software updates
  to GRiSP.io.

  The user-facing API is provided by the `mix grisp-io.*` tasks. The lower-level
  modules are public so applications and tests can use the same API, encrypted
  configuration, and package selection logic as the tasks.
  """

  @doc false
  def ensure_started! do
    case Application.ensure_all_started(:mix_grisp_io) do
      {:ok, _applications} -> :ok
      {:error, reason} -> Mix.raise("Could not start mix_grisp_io: #{inspect(reason)}")
    end
  end

  @doc false
  def version do
    Application.spec(:mix_grisp_io, :vsn)
    |> to_string()
  end
end
