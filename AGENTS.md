# Release instructions

## Before a release

1. Dispatch only when the user asks to release `mix_grisp_io` and provides the
   version. Use the GitHub CLI account with write access to
   `grisp/mix_grisp_io`.
2. Read the current remote `main` SHA. Check [release.yml](.github/workflows/release.yml)
   at that SHA, review the changes since the last release tag, and verify
   successful `ci.yml` for the exact SHA on `main`. A local checkout or a
   passing PR check does not establish that the release commit passed CI.

   ```sh
   gh api repos/grisp/mix_grisp_io/branches/main --jq .commit.sha
   gh run list --repo grisp/mix_grisp_io --workflow ci.yml --branch main \
     --commit FULL_COMMIT_SHA --json headSha,status,conclusion,url
   ```

3. For a fresh release, check that the version is newer than the last tag and
   absent from remote tags, GitHub Releases (including drafts), and Hex.
   Check recent Release runs for the same version because a staged Hex
   upload may be absent from the public registry. If a tag, release, or run
   already exists for that version, see [Continue a release](#continue-a-release).
   Stop and report any API error or ambiguous state before dispatching.
4. Confirm the GitHub and Hex settings below with a package owner before the
   first release or after changing those settings.

### Release settings

The GitHub `release` environment supplies the `RELEASE_SIGNING_KEY` secret and the `RELEASE_SIGNING_EMAIL` variable.
Use the release bot's private GPG key and matching email. Set the
`RELEASE_GPG_KEY_PASSPHRASE` secret for a protected key or remove the secret
for an unprotected key. Replace any setup placeholders before dispatching.
Keep signing key and passphrase values in the environment secrets. Use Hex
Workload Identity for publishing.

Restrict the environment to the `main` branch.

On the [`mix_grisp_io` package](https://hex.pm/packages/mix_grisp_io), a full
Hex owner must enable staged publishing and configure Workload Identity with
repository owner `grisp`, repository `mix_grisp_io`, workflow `release.yml`,
and environment `release`. These settings require two-factor authentication
on Hex. See [Hex Workload Identity](https://hex.pm/docs/workload-identity).

## Send a release request

1. Replace `X.Y.Z` with the version that the user gives and
   `FULL_COMMIT_SHA` with the full SHA of the reviewed default branch commit
   that passed CI.
2. Run the following command. GitHub dispatches from the default branch.
   The request fails if that commit differs from the supplied SHA.

   ```sh
   gh api --method POST repos/grisp/mix_grisp_io/dispatches --input - <<'JSON'
   {"event_type":"release","client_payload":{"version":"X.Y.Z","expected_sha":"FULL_COMMIT_SHA"}}
   JSON
   ```

3. Open the new **Release** run in [GitHub Actions](https://github.com/grisp/mix_grisp_io/actions/workflows/release.yml).
   Verify its dispatch SHA and the `RELEASE_VERSION` shown in the
   **Check the branch and tag** step log.
   If the dispatch response is missing or uncertain, look for the matching
   run before sending another request.
4. Check that the signed release tag points to the release commit and the
   GitHub release uses that tag. Get the Hex approval link from **Publish to
   Hex**, or **Publish the Hex documentation** for a docs upload alone.
5. Give the link, version, tagged commit, and run link to the person who can
   approve the upload. They should review the staged package and docs and
   compare any checksums printed by the run before approving on Hex with 2FA.

The workflow updates the version in `mix.exs` and prepares the changelog before
signing the release commit and tag.
The workflow creates the GitHub release before staging the package and documentation on Hex.
The job ends after the upload succeeds. Report the release as staged until
the exact version is public on Hex. After approval, verify the requested
version, its workflow provenance, and the versioned docs on HexDocs.

## Continue a release

1. Inspect the original run, its publish logs, the exact remote tag, the
   GitHub release, and Hex before retrying. If the tag exists, verify it
   points to the signed release commit and that its `Release-Run` trailer
   identifies the original run. Use an existing pending approval link.
   If the release is already public with its docs, verify it and report
   completion. Keep the original tag and GitHub release for recovery.
2. If the run failed, fix the cause before retrying. For `No matching workload
   identity`, have a Hex owner check the settings above. Use **Re-run all
   jobs** on the original run. For a run that failed before pushing a tag
   and whose dispatch commit is no longer on the tip of `main`, review the
   new commit and repeat the fresh release checks before dispatching again.
3. If a tag or release belongs to a different run, or the signed tag or
   GitHub release fails verification, stop and report the mismatch. Use the
   workflow to publish so the upload keeps its Hex provenance and approval.

If the original run uses a workflow that fails to recover its own tag, wait
for the fixed workflow and passing CI on the default branch. Send a recovery
request with the existing version and the failed run ID. The workflow checks
the run, signed commit, and signed tag before using the tagged source.
`expected_sha` is the reviewed default branch commit that runs the recovery
workflow. The existing release tag determines which source is packaged.

Before staging on Hex, the workflow also checks that the GitHub release uses
the same annotated tag, was created by GitHub Actions, and has notes from the
tagged changelog. If these checks fail, inspect the GitHub release and tag
against the original run before retrying.

```sh
gh api --method POST repos/grisp/mix_grisp_io/dispatches --input - <<'JSON'
{"event_type":"release","client_payload":{"version":"X.Y.Z","expected_sha":"FULL_COMMIT_SHA","resume_run_id":"123456789"}}
JSON
```
