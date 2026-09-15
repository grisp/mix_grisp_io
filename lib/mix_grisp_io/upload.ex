defmodule MixGrispIo.Upload do
  @moduledoc false

  alias MixGrispIo.Command

  def run(options, release_args \\ []) do
    {name, version} = MixGrisp.Project.select_release(options[:relname], options[:relvsn])
    package_path = MixGrisp.Project.update_file(name, version)
    package_name = Path.basename(package_path)
    refresh? = Keyword.get(options, :refresh, false)
    token = Command.token!()

    if File.regular?(package_path) and not refresh? do
      Command.io().info("* Using existing package: #{MixGrisp.relative(package_path)}")
    else
      Command.io().info("* Building software package...")

      MixGrisp.Pack.run(
        [
          force: true,
          quiet: true,
          refresh: refresh?,
          relname: Atom.to_string(name),
          relvsn: version
        ],
        release_args
      )
    end

    unless File.regular?(package_path) do
      raise MixGrispIo.Error, {:package_file_not_found, package_path}
    end

    Command.api().update_package(
      token,
      package_name,
      package_path,
      Keyword.get(options, :force, false)
    )

    Command.io().success("Package #{package_name} successfully uploaded to grisp.io")
    :ok
  end
end
