# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog], and this project adheres to
[Semantic Versioning].

## [Unreleased]

## [1.1.0] - 2026-10-07

### Added

- Browser-based authentication using PKCE and a local callback listener, with
  a pasted authentication code as a fallback [#2](https://github.com/grisp/mix_grisp_io/pull/2).
- An `--encrypt-token` option to choose whether stored API tokens are encrypted.
- Offline regression coverage for browser login, callback validation and cleanup,
  command execution, CLI API errors, and token persistence.

### Changed

- Open the browser by default for `auth`; use `--credentials` to log in with
  a username and password.
- Ask whether to encrypt the token after authentication succeeds, defaulting
  to unencrypted storage. Commands only request a local password for encrypted
  tokens.

## [1.0.0] - 2026-09-15

### Added

- Mix tasks for authenticating with GRiSP.io, revoking credentials, uploading,
  listing, and deleting update packages, deploying and validating updates,
  cancelling deployments, rebooting devices, and reporting the plug-in version.
- GRiSP.io API support for authentication tokens, package management, and
  platform-aware device operations.
- AES-256-GCM token encryption and configuration compatibility with
  `rebar3_grisp_io`.
- Update package selection and generation through `mix_grisp`, including release
  selection, existing-package reuse, forced uploads, refreshes, and forwarded
  release arguments.
- Unit tests and credential-gated live integration tests using the same
  environment variables as `rebar3_grisp_io`.
- GitHub Actions coverage for formatting, warnings-as-errors compilation, unit
  tests, and serialized live GRiSP.io integration tests.

[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html
[Unreleased]: https://github.com/grisp/mix_grisp_io/compare/1.1.0...HEAD
[1.1.0]: https://github.com/grisp/mix_grisp_io/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/grisp/mix_grisp_io/releases/tag/1.0.0
