# Developer tools

Two scripts replace the most repeated manual steps:

| Script | What it does | Takes |
| --- | --- | --- |
| [`tools/check.sh`](../tools/check.sh) | Every automated check (format, analyze, all seven test suites), one line each | about 3 minutes |
| [`tools/release.sh`](../tools/release.sh) | Tags a release with tester notes, pushes it, waits for the Play, TestFlight and Windows builds, and prints a summary | about 20 to 40 minutes, mostly waiting |

Both are plain bash with no paths tied to one computer, so they work the same on Windows (Git Bash), macOS and Linux. They run from any folder: each script moves to the repository root itself.

## What you need

| Tool | For | Install | Check |
| --- | --- | --- | --- |
| bash | both | Windows: comes with [Git for Windows](https://git-scm.com/download/win) as **Git Bash**. macOS and Linux: built in | `bash --version` |
| Git | both | Windows `winget install Git.Git`, macOS `xcode-select --install`, Linux your package manager | `git --version` |
| Flutter (stable, 3.47 or newer; includes Dart) | `check.sh` | [docs/building.md](building.md), "One-time toolchain" | `flutter --version` |
| GitHub CLI, signed in | `release.sh` | Windows `winget install GitHub.cli`, macOS `brew install gh`, Linux [cli.github.com](https://cli.github.com); then `gh auth login` | `gh auth status` |

On Windows, run the scripts from a **Git Bash** window. From PowerShell use Git's bash by its full path, because plain `bash` there can start WSL instead:

```powershell
& "C:\Program Files\Git\bin\bash.exe" tools/check.sh
```

Line endings are handled by `.gitattributes` (`*.sh` is always checked out with LF), and the scripts are committed as executable, so a fresh clone runs them directly.

## tools/check.sh

```bash
tools/check.sh                  # everything
tools/check.sh phone tv         # only some checks
tools/check.sh --list           # the checks and what each covers
tools/check.sh --verbose puzzle # also print the full output
```

| Check | Folder | Command |
| --- | --- | --- |
| `format` | repo root | `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets` |
| `analyze` | repo root | `dart analyze` |
| `protocol` | `packages/protocol` | `dart test` |
| `connection` | `packages/connection` | `dart test` (real sockets on localhost) |
| `metrics` | `packages/metrics` | `dart test` |
| `arena` | `packages/test_game` | `flutter test` |
| `puzzle` | `packages/puzzle_game` | `flutter test` |
| `phone` | `controller_app` | `flutter test` |
| `tv` | `tv_test_app` | `flutter test` |

Output, all passing:

```
PASS  format      (3s)
PASS  analyze     (75s)
PASS  protocol    (73 tests, 8s)
...
PASS  tv          (45 tests, 22s)
All checks passed (169s). Logs: /tmp/thumbparty-check-20261101-210415
```

A failure shows the failing test and the expected and actual values, then the log file with everything:

```
FAIL  puzzle      (24 passed, exit 1, 6s)  log: /tmp/thumbparty-check-.../puzzle.log
      00:00 +18 -1: .../zz_fail_test.dart: a deliberately failing check [E]
        Expected: <3>
          Actual: <2>
```

- **Exit code:** 0 when everything passed, 1 when anything failed, 2 for an unknown check name or a missing tool.
- **Logs:** one file per check in a new folder under the system temp folder (`$TMPDIR`, `%TEMP%` or `/tmp`), named with the date and time.
- **Formatting:** the width (120 columns) is set in every `analysis_options.yaml` (`formatter: page_width: 120`), so a plain `dart format .` or the editor's format command gives the same result. To fix a `format` failure: `dart format controller_app tv_test_app packages assets`.
- **Not included:** the on-device sound test (`tv_test_app/integration_test`, needs audio hardware; see [building.md](building.md)) and checks on real devices or the emulator.

Run it before every commit that changes code, and always before a release.

## tools/release.sh

```bash
tools/release.sh m10.3 "What changed, for testers"   # asks before tagging
tools/release.sh m10.3 "..." --yes                   # no question
tools/release.sh m10.3 "..." --no-wait               # tag and push, don't wait
tools/release.sh --status m10.2                      # report on a release already pushed
```

**Before tagging** it checks the following, and stops with exit code 2 without changing anything if one fails:
- the tag is new and looks like `m10`, `m10.1` or `v1.0` (the Release workflow builds `m*` and `v*` tags);
- the notes aren't empty and fit Google Play's 500 characters together with the "Thumb Party 0.10.0 (build 78)" header;
- tracked files have no uncommitted changes (untracked files, like the PRD backups, are ignored);
- this commit is the tip of `origin/main` (push your commits first);
- both apps' `pubspec.yaml` and `lib/src/app_info.dart` have the same version.

Then it shows the tag, version, build number and notes, and asks **Tag and push? [y/N]** (skipped with `--yes`; in a shell with no terminal, such as a script or an agent, it counts as "no" unless `--yes` is given).

**After you answer yes** it:
1. creates an annotated tag on the current commit with the notes as its message. [`tools/release-notes.sh`](../tools/release-notes.sh) turns that message into Play's "What's new", TestFlight's "What to Test" and the GitHub Release text;
2. pushes the tag (if the push fails it deletes the local tag again);
3. waits for the GitHub **Release** run (Android bundles uploaded to Play for both apps, and the Windows zip on a GitHub Release), usually 15 to 25 minutes;
4. waits for Codemagic's **iOS TestFlight** check on the same commit (up to an hour);
5. prints a summary like this:

```
Release m10.2 (commit a836a81):
  GitHub Release run 41279888890: success
    job windows: success
    job android: success
  GitHub Release: Thumb Party 0.10.0 (m10.2)
    ThumbPartyTV-windows-0.10.0-78.zip
  iOS TestFlight (Codemagic): success (shows in TestFlight after Apple processes it)
All done.
```

- **Exit code:** 0 when everything succeeded; 1 when a build or upload failed or didn't finish in time; 2 when a check before tagging failed (nothing was tagged).
- **If the window closes while waiting,** nothing is lost: the builds run in the cloud. Run `tools/release.sh --status <tag>` later.
- **What it doesn't do:** bump the version (edit the two `pubspec.yaml` and two `app_info.dart` files and commit first), or fix failed uploads. For those, see "If something goes wrong" in [release.md](release.md).

## Moving development to another computer

Everything needed to build and test is in the repository. A few things live outside it.

**In the repository** (comes with `git clone`): code, docs, the scripts, `.gitattributes`, analysis and format settings, the CI workflows (`.github/workflows/`) and `codemagic.yaml`.

**In the cloud** (nothing to move, just sign in on the new computer):
- **GitHub:** the release secrets (Play upload key, Play service account) and variables (`PLAY_TRACK_APP`, `PLAY_TRACK_TV`, `FIRESTORE_PROJECT`, `FIRESTORE_API_KEY`). The Release workflow uses them; see them with `gh secret list` and `gh variable list`.
- **Codemagic:** the iOS signing and the App Store Connect key.
- **Firebase:** the `thumb-party-stats` project.
- **Play Console and App Store Connect.**

**On this computer only** (copy or redo):

| What | Where | Needed for | On the new computer |
| --- | --- | --- | --- |
| Play upload key | `%USERPROFILE%\.thumbparty\` (Windows) | local signed release builds only. CI has its own copy as a GitHub secret | Copy the folder, or skip it if you only release through CI. Back it up either way: losing it means asking Play for a key reset |
| GitHub CLI sign-in | the `gh` config | `release.sh`, `gh` commands | `gh auth login` |
| Google Cloud CLI sign-in | the `gcloud` config | the stats report from Firestore (`dart run metrics:report --firestore ...`) | install the Cloud SDK, then `gcloud auth login` |
| Android SDK, emulator image and the `m7_android12` emulator | `%LOCALAPPDATA%\Android\Sdk`, `~\.android\avd` | Android builds and the Android 12 check | [building.md](building.md): the toolchain and "Android 12 emulator check" |
| Android TV pairing for adb | the TV | installing on the TV | `adb connect <TV IP>:5555` again (accept the prompt on the TV) |
| Windows Firewall rules for the TV app | Windows | phones reaching the Windows TV app | allowed again on the first run ([building.md](building.md)) |
| Claude Code's notes for this project | `~/.claude/projects/<folder name>/memory/` | Claude remembering the project state and your preferences | copy the `memory` folder into the matching folder on the new computer. The folder name comes from the repository's path (`C--Users-singh-game-controller` for `C:\Users\singh\game-controller`), so it changes if the path does |

**First steps on the new computer:**
1. Install the tools in "What you need", and the rest of the toolchain from [building.md](building.md).
2. `git clone https://github.com/devtestman187/game-controller.git`, then `cd game-controller` and `flutter pub get`.
3. `gh auth login`.
4. `tools/check.sh`: everything should pass.
5. `tools/release.sh --status <the latest tag>`: shows that GitHub access works, without releasing anything.
