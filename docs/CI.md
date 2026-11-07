# CI

The iOS build in `.github/workflows/ios-build.yml` is `xcodebuild` on a Mac. A GitHub-hosted `macos-latest` minute costs about 10× a Linux minute. Every push to `main`, `claude/**`, and `codex/**`, and every pull request into `main` or `cursor/**`, still starts the workflow. The only job that runs by default is a Linux `mac preflight` on `ubuntu-latest`. It does not check out the repository and it does not compile the app.

There is no separate Linux test job. Nothing in this build runs without Xcode and the iOS and watchOS simulators. `media/higgsfield/fetch.sh` only restores media files. Website checks stay local: `npm ci`, `npm run lint`, `npm run build`.

A green Actions run where `build-and-test` was skipped did not compile the app.

## When the Mac job runs

`mac preflight` sets `run=true` only for one of these:

1. Someone runs the workflow manually (`workflow_dispatch`).
2. The pull request has the `mac-ci` label.
3. The repository Actions variable `MAC_RUNNER` is set to a non-empty value.

Otherwise `build-and-test` is skipped and no Mac runner is requested.

`runs-on` for that job is:

```yaml
runs-on: ${{ vars.MAC_RUNNER || 'macos-latest' }}
```

Leave `MAC_RUNNER` unset and the two opt-in paths above use the billed `macos-latest` runner. Set `MAC_RUNNER` and every path, including ordinary pushes and pull requests, uses that label instead. Hosted `macos-latest` is not requested while the variable is set.

Newer pushes and pull-request events for the same ref cancel the in-progress run (`cancel-in-progress: true`).

## Turn Mac CI on

Dre or Gene sets one of these. This repository does not define them.

**Always-on Mac Mini (no hosted Mac minutes):** repository Actions variable, not a secret.

- Name: `MAC_RUNNER`
- Where: Settings → Secrets and variables → Actions → Variables
- Value: one self-hosted runner label registered on the Mac Mini, for example `mac-mini`

Use a custom label that only that machine has. Do not set the value to `macos-latest` (that bills a hosted Mac on every push and pull request) or to plain `self-hosted` if any other self-hosted runner exists. The variable is the whole switch. Do not edit the workflow to change machines.

**One pull request before the Mini is registered:** create a `mac-ci` label if it is not there, then:

```bash
gh pr edit NUMBER --add-label mac-ci
```

With `MAC_RUNNER` unset, that pull request uses hosted `macos-latest`. Adding the label starts a run on its own only after this workflow file is on the default branch (`labeled` is read from that copy). Until then, open the pull request or push a commit while the label is already applied. Later commits build again while the label stays on.

**One branch, right now:**

```bash
gh workflow run "iOS Build" --ref main
gh workflow run "iOS Build" --ref my-branch
```

Manual runs use the workflow file on the default branch. In the Actions tab: iOS Build → Run workflow → choose the branch. With `MAC_RUNNER` unset, this uses hosted `macos-latest`.

## Mac Mini

The machine needs Xcode 26.6 installed at `/Applications/Xcode_26.6.app`. The workflow installs XcodeGen 2.46.0 with Mint. `sudo xcode-select` has to work without a password prompt. The same steps then run there at no GitHub-hosted macOS charge. If the machine is offline, `build-and-test` stays queued until it connects or a newer run cancels it. A queued self-hosted job does not consume hosted macOS minutes.

This repository is public. `pull_request` runs the workflow from the pull request, and `xcodebuild` compiles that pull request's code. Once `MAC_RUNNER` is set, those runs execute on the Mini, including fork pull requests whose workflows are allowed to run. Require approval for workflows from outside collaborators (Settings → Actions → General → Fork pull request workflows) and do not approve a fork workflow that changes `.github/workflows` or points `runs-on` at the Mini.

## Checkout

A fresh clone needs `GIT_LFS_SKIP_SMUDGE=1`. The LFS quota rejects a smudge of `media/higgsfield` and `public/videos`. The page videos inside the iOS app target are ordinary git files.

## StoreKit signing

The unit-test step passes `CODE_SIGN_IDENTITY=-` because hosted CI has no team certificate. That is ad-hoc, `TeamIdentifier` unset. At `6950582`, iPhone 16 / iOS 18.6 ran `StoreKitPurchaseFlowTests` 7/7 that way, with no skip and no hang. That is the only reported iOS 18.6 pass of this class. The `77ef95f` iOS 26.5 logs are a different result: `CODE_SIGNING_ALLOWED=NO` recorded Code=3 at session setup, then a trial mismatch, then `Purchase cancelled.` in 86 seconds; the `CODE_SIGN_IDENTITY=-` log records the same Code=3 and trial mismatch and ends during the purchase with no result. At `54a7bb9` the same iOS 18.6 class was killed at 600 seconds, exit 142, on two runs. The purchase failure text named Code=3. The runtime log did not. None of those is a signed archive. A device install still needs provisioning profiles for `com.earnyourcmsn.app` and `com.earnyourcmsn.app.watchkitapp`. Tailor owns signing.
