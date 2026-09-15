defmodule MixGrispIo.Delete do
  @moduledoc false

  alias MixGrispIo.Command

  def run(options, package_name \\ nil) do
    package_name = package_name || current_package(options)
    Command.api().delete_package(Command.token!(), package_name)
    Command.io().success("Package #{package_name} successfully deleted!")
    :ok
  end

  defp current_package(options) do
    {name, version} = MixGrisp.Project.select_release(options[:relname], options[:relvsn])
    MixGrisp.Project.update_file(name, version) |> Path.basename()
  end
end
