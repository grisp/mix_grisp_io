defmodule MixGrispIo.CommandTest do
  use ExUnit.Case, async: false

  alias MixGrispIo.{Auth, Cancel, Deauth, Delete, Error, List, Reboot, Validate}

  defmodule IOStub do
    def ask(prompt, _type), do: Process.get({:answer, prompt}, default_answer(prompt))
    def success(message), do: send(self(), {:success, message})
    def info(message), do: send(self(), {:info, message})

    defp default_answer("Username"), do: "user"
    defp default_answer("Password"), do: "account-password"
    defp default_answer(_prompt), do: "password"
  end

  defmodule ConfigStub do
    def read, do: %{encrypted_token: :encrypted}
    def decrypt_token("password", :encrypted), do: "token"
    def delete, do: send(self(), :config_deleted)
    def encrypt_token("password", "new-token"), do: :new_encrypted_token
    def write(config), do: send(self(), {:config_written, config})
  end

  defmodule APIStub do
    def auth("user", "account-password"), do: "new-token"
    def cancel_update("token", device), do: send(self(), {:cancelled, device})
    def reboot_device("token", device), do: send(self(), {:rebooted, device})
    def validate_update("token", device), do: send(self(), {:validated, device})
    def delete_package("token", package), do: send(self(), {:deleted, package})
    def deauth("token"), do: response(:deauth_response, :deauthenticated)
    def list_packages("token"), do: Process.get(:packages, [])

    defp response(key, message) do
      case Process.get(key, :ok) do
        :ok -> send(self(), message)
        {:error, reason} -> raise Error, reason
      end
    end
  end

  test "auth requests and persists an encrypted token" do
    assert :ok = Auth.run()

    assert_received {:config_written, %{username: "user", encrypted_token: :new_encrypted_token}}

    assert_received {:success, "Authentication successful - Please provide new local password"}
    assert_received {:success, "Token successfully requested"}
  end

  test "auth rejects non-matching local passwords" do
    Process.put({:answer, "Confirm your local password"}, "different")
    assert_raise Error, "The local password entries do not match", &Auth.run/0
    refute_received {:config_written, _}
  end

  setup do
    old =
      for key <- [:api_module, :config_module, :io_module], into: %{} do
        {key, Application.get_env(:mix_grisp_io, key)}
      end

    Application.put_env(:mix_grisp_io, :api_module, APIStub)
    Application.put_env(:mix_grisp_io, :config_module, ConfigStub)
    Application.put_env(:mix_grisp_io, :io_module, IOStub)

    on_exit(fn ->
      Enum.each(old, fn
        {key, nil} -> Application.delete_env(:mix_grisp_io, key)
        {key, value} -> Application.put_env(:mix_grisp_io, key, value)
      end)
    end)
  end

  test "cancel requires a device and requests cancellation" do
    assert_raise Error, fn -> Cancel.run([]) end
    assert :ok = Cancel.run(device: "ci-dummy")
    assert_received {:cancelled, "ci-dummy"}
    assert_received {:success, "Update cancellation requested for device #ci-dummy"}
  end

  test "reboot requires a device and requests reboot" do
    assert_raise Error, fn -> Reboot.run([]) end
    assert :ok = Reboot.run(device: "ci-dummy")
    assert_received {:rebooted, "ci-dummy"}
    assert_received {:success, "Reboot requested for device #ci-dummy"}
  end

  test "validate requires a device and validates the update" do
    assert_raise Error, fn -> Validate.run([]) end
    assert :ok = Validate.run(device: "ci-dummy")
    assert_received {:validated, "ci-dummy"}
    assert_received {:success, "Update validated for device #ci-dummy"}
  end

  test "delete accepts an explicit package name without release selection" do
    assert :ok = Delete.run([], "grisp2.robot.1.0.0.tar")
    assert_received {:deleted, "grisp2.robot.1.0.0.tar"}
    assert_received {:success, "Package grisp2.robot.1.0.0.tar successfully deleted!"}
  end

  test "list prints sorted package rows" do
    Process.put(:packages, [
      package("z.tar", "zapp"),
      package("a.tar", "aapp")
    ])

    assert :ok = List.run()
    assert_received {:info, "NAME  APPLICATION  VERSION  PLATFORM  LAST MODIFIED"}
    assert_received {:info, "a.tar  aapp  1.0.0  grisp2  2026-01-01"}
    assert_received {:info, "z.tar  zapp  1.0.0  grisp2  2026-01-01"}
  end

  test "list reports an empty account" do
    assert :ok = List.run()
    assert_received {:info, "No update packages found."}
  end

  test "deauth revokes the token and deletes local credentials" do
    assert :ok = Deauth.run()
    assert_received :deauthenticated
    assert_received :config_deleted
    assert_received {:success, "Authentication token successfully revoked"}
  end

  test "deauth deletes stale credentials when the token is already invalid" do
    Process.put(:deauth_response, {:error, :wrong_credentials})

    assert :ok = Deauth.run()
    assert_received :config_deleted

    assert_received {:success,
                     "Authentication token is no longer valid; local credentials removed"}
  end

  test "all reference commands are registered as Mix tasks" do
    for command <- ~w(auth deauth deploy upload list delete validate cancel reboot version) do
      assert Mix.Task.get("grisp-io.#{command}")
    end
  end

  defp package(name, app) do
    %{
      "name" => name,
      "app_name" => app,
      "version" => "1.0.0",
      "platform" => "grisp2",
      "last_modified" => "2026-01-01"
    }
  end
end
