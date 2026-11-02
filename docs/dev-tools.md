# Developer tools

Two scripts replace the most repeated manual steps:

| Script | What it does | Takes |
| --- | --- | --- |
| [`tools/check.sh`](../tools/check.sh) | Every automated check (format, analyze, all seven test suites), one line each | about 3 minutes |
| [`tools/release.sh`](../tools/release.sh) | Tags a release with tester notes, pushes it, waits for the Play, TestFlight and Windows builds, and prints a summary | about 20 to 40 minutes, mostly waiting |
| [`tools/tv-dev.sh`](../tools/tv-dev.sh) | Starts and stops a development copy of the Windows TV app, and prints its port and pairing code | a few seconds (a few minutes for the first build) |
| [`tools/tv-window.ps1`](../tools/tv-window.ps1) | Screenshots, clicks and keys in that copy's window | instant |
| [`tools/emulator.sh`](../tools/emulator.sh) | Runs the phone app on the Android emulator: install with cleared data, connect to a TV app, list what's on screen, tap, screenshot | about a minute to boot |

They're plain bash (and one PowerShell script for the Windows window) with no paths tied to one computer. `check.sh`, `release.sh` and `emulator.sh` work the same on Windows (Git Bash), macOS and Linux; `tv-dev.sh` and `tv-window.ps1` are for Windows, where the desktop TV app runs. Each runs from any folder: the scripts move to the repository root themselves. They're written so a person, Claude Code or another AI agent can use them the same way.

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

## Checking on screens: the TV app and the phone app

Automated tests can't tell whether something looks right or feels right. These scripts make the hands-on check quick: the development TV app on Windows, the phone app on the Android emulator, connected to each other, with screenshots of both.

### Safety rules (the scripts follow them; anyone driving by hand should too)

- **Only the development copy.** A release copy of the TV app (from a Windows zip) may be open and in use, with phones paired to it. `tv-dev.sh` and `tv-window.ps1` only touch this repository's debug build (`tv_test_app\build\windows\x64\runner\Debug\ThumbPartyTV.exe`), found by its full path. Never stop `ThumbPartyTV` processes by name.
- **The development copy is the same app on the same PC.** It shares the release copy's saved pairings and network name. If no release copy is running, it takes the usual port (45780), and phones paired with this PC (yours too) may reconnect to it. Keep checks short, and stop it afterwards.
- **Clear the emulator's app data before running it.** The phone app reconnects to the last TV it paired with, which may be a real one. `emulator.sh launch` and `install` always clear it.

### The TV app on Windows: tools/tv-dev.sh and tools/tv-window.ps1

```bash
tools/tv-dev.sh start                 # build and start; prints port and code
tools/tv-dev.sh status
tools/tv-dev.sh window click 707,67   # Play (positions as in a screenshot of the 1280x720 window)
tools/tv-dev.sh window key space      # keys: left right up down space enter esc tab backspace a-z 0-9
tools/tv-dev.sh window hold right 900 # hold for 900 ms; several at once: right+space
tools/tv-dev.sh window shot tv.png    # the whole window, even when covered
tools/tv-dev.sh log                   # the last 40 log lines
tools/tv-dev.sh stop
```

`start` prints, for example:

```
Running: process 11336
Port:    45780   (a phone or the Android emulator connects to <this PC's IP>:45780, the emulator uses 10.0.2.2:45780)
Code:    5416
Log:     C:\Users\...\Temp\thumbparty-dev\tv.log
```

- `window ...` passes everything on to `tools/tv-window.ps1`, which can also be run from PowerShell: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\tv-window.ps1 shot tv.png`.
- On Windows the keyboard plays as another player: arrows to move, Space for A, X and Z to rotate.
- Debug runs save stats to a `sessions-debug` folder, so test sessions don't mix with real ones.
- Exit codes: 0 ok, 1 not running or didn't start (the end of the log is printed), 2 bad use.

### The phone app on the Android emulator: tools/emulator.sh

Needs the Android SDK with the emulator and an AVD (`m7_android12`: see "Android 12 emulator check" in [building.md](building.md)). The SDK is found through `ANDROID_HOME`, `ANDROID_SDK_ROOT` or its usual folder on each OS.

```bash
tools/emulator.sh start                       # boot m7_android12 (or: start <avd>) and wait
tools/emulator.sh install                     # the debug APK (built if missing); clears data before and after
tools/emulator.sh install --build             # rebuild it first, after changing the phone app
tools/emulator.sh launch                      # clears data and opens the Connect screen
tools/emulator.sh connect 10.0.2.2:45780 5416 # types the address and code, waits for "P1"
tools/emulator.sh ui                          # everything labelled on screen, with its centre
tools/emulator.sh tap-name "Sticks"           # tap by label (first match, from the start of the label)
tools/emulator.sh tap 1882 870                # tap at screen pixels
tools/emulator.sh hold 828 596 2300           # touch and hold (2.3 s on the D-pad's right arm)
tools/emulator.sh text "hello"; tools/emulator.sh key enter   # also: back, home, or a keycode
tools/emulator.sh shot phone.png              # pixels match tap and hold coordinates
tools/emulator.sh stop
```

`ui` reads the screen through Android's accessibility tree, so it finds buttons by name without guessing positions:

```
P1                                       View                76    73
TV · 5 ms                                Button             285    74
D-pad                                    Button            1516    73
Sticks                                   Button            2005    73
Select                                   View              1200   456
A, B, X, Y                               View              1858   598
```

The face buttons are one drawn control (`A, B, X, Y`; in a game it lists the labels too, such as `A Pick up, X Rotate ⟳`), so press them by position: take a screenshot first.

- `adb shell input tap` is a very short tap, good for checking that quick taps aren't lost; `hold` presses for as long as you say.
- With several devices attached, set `ANDROID_SERIAL` to the one to use. The same commands work on a real Android phone connected with adb, except `start` and `stop`.
- Exit codes: 0 ok, 1 failed or timed out, 2 bad use.

### A whole check, start to finish

```bash
tools/tv-dev.sh start                          # note the port and code
tools/emulator.sh start
tools/emulator.sh install && tools/emulator.sh launch
tools/emulator.sh connect 10.0.2.2:<port> <code>
tools/tv-dev.sh window click 707,67            # Play → then the game and puzzle
tools/tv-dev.sh window shot tv.png
tools/emulator.sh shot phone.png
tools/emulator.sh stop; tools/tv-dev.sh stop   # always clean up
```

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
| Claude Code's notes for this project | `~/.claude/projects/<folder name>/memory/` | Claude remembering the project state and your preferences | copy the `memory` folder into the matching folder on the new computer. The folder name comes from the repository's path (`C--Users-singh-game-controller` for `C:\Users\singh\game-controller`), so it changes if the path does. The same rules, open items and lessons are kept in [project-notes.md](project-notes.md), so nothing important is lost without the folder |

**First steps on the new computer:**
1. Install the tools in "What you need", and the rest of the toolchain from [building.md](building.md).
2. `git clone https://github.com/devtestman187/game-controller.git`, then `cd game-controller` and `flutter pub get`.
3. `gh auth login`.
4. `tools/check.sh`: everything should pass.
5. `tools/release.sh --status <the latest tag>`: shows that GitHub access works, without releasing anything.
