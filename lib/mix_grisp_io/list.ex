defmodule MixGrispIo.List do
  @moduledoc false

  alias MixGrispIo.Command

  @columns ["name", "app_name", "version", "platform", "last_modified"]
  @headings ["NAME", "APPLICATION", "VERSION", "PLATFORM", "LAST MODIFIED"]

  def run do
    packages = Command.api().list_packages(Command.token!())

    case packages do
      [] ->
        Command.io().info("No update packages found.")

      packages ->
        Command.io().info(Enum.join(@headings, "  "))

        packages
        |> Enum.sort_by(&Map.fetch!(&1, "name"))
        |> Enum.each(fn package ->
          Command.io().info(Enum.map_join(@columns, "  ", &to_string(Map.fetch!(package, &1))))
        end)
    end

    :ok
  end
end
