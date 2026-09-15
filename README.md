# mix_grisp_io

Mix plug-in for GRiSP.io. It is the Elixir/Mix port of `rebar3_grisp_io` and
keeps the same command architecture and feature set while using `mix_grisp` for
release selection, artifact naming, and update-package creation.

## Installation

Add the plug-in to your project dependencies:

```elixir
def deps do
  [
    {:mix_grisp_io, "~> 1.0"}
  ]
end
```

`mix_grisp_io` depends on `mix_grisp`; the project must have a valid
`releases:` entry and GRiSP configuration as described by `mix_grisp`.

## Commands

Inspect a command with `mix help grisp-io.COMMAND`.

### Authentication

```shell
mix grisp-io.auth
```

This requests an API token and encrypts it locally using AES-256-GCM and the
local password you provide. By default the plug-in uses the rebar3 global
configuration directory and the same `grisp-io.config` format, so an existing
`rebar3_grisp_io` login can be reused. Set `MIX_GRISP_IO_CONFIG_DIR` to override
the directory.

### Upload

```shell
mix grisp-io.upload [--force] [--refresh] [--relname NAME] [--relvsn VERSION]
```

An existing `_grisp/update/*.tar` is reused unless `--refresh` is set. Otherwise
the package is built through `MixGrisp.Pack`. `--force` allows overwriting the
remote package.

Arguments after `--` are forwarded to Mix's release generation, as with
`mix grisp.pack`.

### Deauthentication

```shell
mix grisp-io.deauth
```

This revokes the stored token and removes the local credentials. Stale local
credentials are also removed when the server reports that the token is already
invalid.

### List

```shell
mix grisp-io.list
```

Lists the stored update packages and their application, version, platform, and
last-modified time.

### Deploy

```shell
mix grisp-io.deploy --device SERIAL [--package PACKAGE]
```

Without `--package`, the package name is derived from the selected Mix release.
Use `--relname` and `--relvsn` when the project defines multiple releases.

### Delete

```shell
mix grisp-io.delete [PACKAGE] [--relname NAME] [--relvsn VERSION]
```

When `PACKAGE` is omitted, its name is derived from the selected Mix release.

### Validate

```shell
mix grisp-io.validate --device SERIAL
```

### Cancel and reboot

```shell
mix grisp-io.cancel --device DEVICE
mix grisp-io.reboot --device DEVICE
```

### Version

```shell
mix grisp-io.version
```

## Configuration

The production service defaults to `https://app.grisp.io`. A different endpoint
can be configured for development or testing:

```elixir
config :mix_grisp_io, base_url: "https://localhost:8443"
```

TLS verification remains enabled by default in every Mix environment. A local
development endpoint can opt out explicitly with `insecure: true` in the
`:grisp_io` project configuration or `:mix_grisp_io` application environment.
