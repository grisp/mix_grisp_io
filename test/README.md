# Test boundaries

The ExUnit suite mirrors the boundaries of `rebar3_grisp_io`'s Common Test
suites. Authentication/deauthentication, upload/list/delete, and deploy/cancel
exercise the real GRiSP.io API. Validate and reboot remain mocked because they
depend on a device's current update state or cause a disruptive reboot.

Offline tests also cover browser PKCE login using a real loopback listener, a
temporary browser executable, and injected API/input stubs. They check nonce
rejection, malformed callbacks, preflight, PKCE proof, pasted and blank input,
EOF, pending-reader cleanup, and listener closure before redemption. Terminal
input never reaches the real test runner. Command tests use a temporary Mix
release project for upload/deploy/default delete and inspect actual version
output. Configuration tests cover plaintext and encrypted persistence and
tamper rejection.

Live tests use the same environment variables as `rebar3_grisp_io`:

- `GRISP_CI_USERNAME`
- `GRISP_CI_PASSWORD`
- `GRISP_CI_DEVICE`

If none of these variables is present, tests tagged `:live_api` are excluded.
If any is present, the live suite runs and reports any missing variables.

Run the complete suite against GRiSP.io with:

```shell
GRISP_CI_USERNAME=... \
GRISP_CI_PASSWORD=... \
GRISP_CI_DEVICE=... \
mix test
```

Each live test creates and revokes its own token. Tests that upload the fixture
also remove it during teardown, and deploy/cancel performs a best-effort cancel
before deleting the package. Never store live credentials in tracked files.
