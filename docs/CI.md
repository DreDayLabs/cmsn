# CI

The iOS build in `.github/workflows/ios-build.yml` is `xcodebuild` on a Mac. A GitHub-hosted `macos-latest` minute costs about 10× a Linux minute, so that job does not run on every push or pull request.

There is no Linux CI job. Nothing in this build runs without Xcode and the iOS and watchOS simulators. `media/higgsfield/fetch.sh` only restores media files. Website checks stay local: `npm ci`, `npm run lint`, `npm run build`.

## When the Mac job runs

`build-and-test` starts only when one of these is true:

1. Someone runs the workflow manually.
2. The pull request has the `mac-ci` label. Later commits on that pull request build again while the label stays on.
3. The pull request is marked ready for review. That event builds the head commit once. Further commits do not build unless the label is on or someone dispatches the workflow.

Pushes to `main`, `claude/**`, and `codex/**` do not start the workflow. A draft pull request does not take a Mac runner unless it carries `mac-ci`. A pull request opened already ready for review is not the "marked ready" event; add `mac-ci` or run the workflow manually.

Before `build-and-test` is allowed to request a runner, a short Linux preflight reads prior checks. If this same head commit already has a successful `build-and-test` from an earlier run, the Mac job is skipped. `gh workflow run` with `-f force=true` rebuilds anyway. Re-running the same Actions run (`gh run rerun`) also rebuilds, because that attempt is ignored by the preflight.

A green Actions run where `build-and-test` was skipped did not compile the app.

`labeled` and `ready_for_review` start a run only after this workflow file is on the default branch. GitHub uses that copy to decide whether a pull request event fires.

## Run it manually

Manual runs use the workflow file on the default branch.

```bash
gh workflow run "iOS Build" --ref main
gh workflow run "iOS Build" --ref my-branch
gh workflow run "iOS Build" --ref my-branch -f force=true
```

In the Actions tab: iOS Build → Run workflow → choose the branch. Check "Run the iOS build even if this commit already passed" to ignore a previous success.

## Run it on a pull request

Create a `mac-ci` label in the repository if it is not there yet, then:

```bash
gh pr edit NUMBER --add-label mac-ci
```

Or open the pull request, add the `mac-ci` label, or click Ready for review.

## Mac Mini

The Mac job's runner is one label:

```yaml
runs-on: ${{ vars.MAC_RUNNER || 'macos-latest' }}
```

`MAC_RUNNER` is a repository variable, not a secret and not a value committed in this file. Leave it unset to keep the billed `macos-latest` fallback. When the Mac Mini is registered as a self-hosted runner, set the variable to that machine's label (Settings → Secrets and variables → Actions → Variables). Use a single custom label such as `mac-mini` so the job does not land on a different self-hosted runner. The variable is the whole switch; do not edit the workflow to change machines.

The machine needs Xcode 26.6 installed at `/Applications/Xcode_26.6.app`. The workflow installs XcodeGen 2.46.0 with Mint. `sudo xcode-select` has to work without a password prompt. The same steps then run there at no GitHub-hosted macOS charge.
