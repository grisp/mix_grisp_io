# Release instructions

## Before a release

1. Make sure that [release.yml](.github/workflows/release.yml) is on the default branch.
2. Use a GitHub CLI account with write access to `grisp/mix_grisp_io`.
3. Make sure that CI passed for the commit on the default branch.
4. Make sure that the requested version is newer than the last release and is
   absent from Git tags, GitHub Releases, and Hex. If it already exists, see
   [Continue a release](#continue-a-release).
5. Confirm the GitHub and Hex settings below with a package owner before the
   first release or after changing those settings.

### Release settings

The GitHub `release` environment supplies the `RELEASE_SIGNING_KEY` secret and the `RELEASE_SIGNING_EMAIL` variable.
Use the release bot's private GPG key and matching email. Set the
`RELEASE_GPG_KEY_PASSPHRASE` secret for a protected key or remove the secret
for an unprotected key. Replace any setup placeholders before dispatching.

Restrict the environment to the `main` branch.

On the [`mix_grisp_io` package](https://hex.pm/packages/mix_grisp_io), a full
Hex owner must enable staged publishing and configure Workload Identity with
repository owner `grisp`, repository `mix_grisp_io`, workflow `release.yml`,
and environment `release`. These settings require two-factor authentication
on Hex. See [Hex Workload Identity](https://hex.pm/docs/workload-identity).

## Send a release request

1. Replace `X.Y.Z` with the version that the user gives.
2. Run the following command.

   ```sh
   gh api --method POST repos/grisp/mix_grisp_io/dispatches --input - <<'JSON'
   {"event_type":"release","client_payload":{"version":"X.Y.Z"}}
   JSON
   ```

3. Open the new **Release** run in [GitHub Actions](https://github.com/grisp/mix_grisp_io/actions/workflows/release.yml).
4. Get the Hex approval link from the **Publish to Hex** step log. For a docs
   upload by itself, use the **Publish the Hex documentation** step log.
5. Give the link to the person who can approve the release on Hex.

The person who approves the release must complete two-factor authentication on Hex.
The workflow updates the version in `mix.exs` and prepares the changelog before
signing the release commit and tag.
The workflow creates the GitHub release before staging the package and documentation on Hex.
The job ends after the upload succeeds. Hex approval can happen later.

## Continue a release

If Hex approval is pending after a successful run, use the link in the
completed run to approve it. Approval completes the release on Hex.

If the run fails after pushing the tag, correct the cause and select
**Re-run all jobs** on the original run. The workflow checks that the tag
belongs to that run.

Before retrying an upload failure, check the run log and Hex for an existing
staged upload. If one is pending, use its approval link. If Hex reports
`No matching workload identity`, have a Hex owner check the settings above
before rerunning. Keep the original tag and GitHub release for recovery.

If the original run uses a workflow that fails to recover its own tag, wait
for the fixed workflow and passing CI on the default branch. Send a recovery
request with the existing version and the failed run ID. The workflow checks
the run, signed commit, and signed tag before using the tagged source.

Before staging on Hex, the workflow also checks that the GitHub release uses
the same annotated tag, was created by GitHub Actions, and has notes from the
tagged changelog. If these checks fail, inspect the GitHub release and tag
against the original run before retrying.

```sh
gh api --method POST repos/grisp/mix_grisp_io/dispatches --input - <<'JSON'
{"event_type":"release","client_payload":{"version":"X.Y.Z","resume_run_id":"123456789"}}
JSON
```
