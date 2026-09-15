defmodule MixGrispIo.Deploy do
  @moduledoc false

  alias MixGrispIo.Command

  def run(options) do
    device = Command.device!(options[:device])
    {name, version} = MixGrisp.Project.select_release(options[:relname], options[:relvsn])

    package_name =
      options[:package] || MixGrisp.Project.update_file(name, version) |> Path.basename()

    Command.api().deploy_update(Command.token!(), package_name, device)
    Command.io().success("Deployment request for package #{package_name} on device ##{device}")
    :ok
  end
end
