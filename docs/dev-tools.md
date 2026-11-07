# Developer tools

Two scripts replace the most repeated manual steps:

| Script | What it does | Takes |
| --- | --- | --- |
| [`tools/check.sh`](../tools/check.sh) | Every automated check (format, analyze, all seven test suites), one line each | about 3 minutes |
| [`tools/review.sh`](../tools/review.sh) | The coding guidelines' mechanical checks over the `.dart` files that changed, one line per finding | a few seconds |
| [`tools/commit-job.sh`](../tools/commit-job.sh) | Commits one finished job: the changes under its brief's `allow:` paths, the brief, its report and its review files, with the report's draft message | instant |
| [`tools/release.sh`](../tools/release.sh) | Tags a release with tester notes, pushes it, waits for the Play, TestFlight and Windows builds, and prints a summary | about 20 to 40 minutes, mostly waiting |
| [`tools/tv-dev.sh`](../tools/tv-dev.sh) | Starts and stops a development copy of the Windows TV app, and prints its port and pairing code | a few seconds (a few minutes for the first build) |
| [`tools/tv-window.ps1`](../tools/tv-window.ps1) | Screenshots, clicks and keys in that copy's window | instant |
| [`tools/emulator.sh`](../tools/emulator.sh) | Runs the phone app on the Android emulator: install with cleared data, connect to a TV app, list what's on screen, tap, screenshot | about a minute to boot |
| [`tools/smoke.sh`](../tools/smoke.sh) | Pairs a simulated controller (and with `--emulator` the phone app) with the development TV app and checks each step against the clients' and the app's own logs | about 30 seconds (a few minutes with `--emulator`) |
| [`tools/audio/`](../tools/audio/README.md) | `render.py`, which generates the game's sound effects, and how to encode them | a few seconds |

They're plain bash (and one PowerShell script for the Windows window) with no paths tied to one computer. `check.sh`, `review.sh`, `commit-job.sh`, `release.sh` and `emulator.sh` work the same on Windows (Git Bash), macOS and Linux; `tv-dev.sh` and `tv-window.ps1` are for Windows, where the desktop TV app runs, and so is `smoke.sh`, which drives them. Each runs from any folder: the scripts move to the repository root themselves. They're written so a person, Claude Code or another AI agent can use them the same way.

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
| `host` | `packages/party_host` | `flutter test` |
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

## tools/review.sh

```bash
tools/review.sh                     # the uncommitted changes (one job's diff)
tools/review.sh --base origin/main  # the whole branch (any commit or branch works)
tools/review.sh --all           # every file, every line
tools/review.sh --strings       # which texts a diff adds or removes
tools/review.sh --help
```

It's the [coding guidelines](coding-guidelines.md) done by script. It prints one line per finding, the failures first, then the notes:

```
FAIL func     tv_test_app/lib/src/ui/home_screen.dart:471 102 lines (>60): Widget build(BuildContext context)
FAIL leftover packages/party_host/lib/src/providers.dart:47 debugPrint(
NOTE number   tv_test_app/lib/src/ui/home/panel.dart:25 numeric literal 16
review: 2 fail, 1 note
```

- **Scope:** the `.dart` files under `controller_app`, `tv_test_app`, `packages` and `assets`, without `build/`, `.dart_tool/`, `*.g.dart` and `generated_plugin_registrant*`. By default it takes the files that changed since the last commit (staged, unstaged and untracked), so it reviews one job's diff; `--base <ref>` compares with another commit and includes what was committed since. Inside those files, the line checks look only at the lines the change adds; `--all` takes every file and every line.
- **Checks:** `size` (a lib file over 400 lines, a test over 500), `func` (a member over 60 lines; a note from 41; a `build` method's limit is 60), `platform` (`Platform.is` in a package), `layers` (a package importing an app, `flutter` in a pure Dart package, a game importing another game or `party_host`, any `package:x/src/` from outside `x`), `leftover` (`TODO`/`FIXME`/`XXX`, `print` and `debugPrint` in lib, `// ignore`), `catch` (an empty one), `types` (`dynamic` in lib), `timing` (`Future.delayed`, `sleep`), `clock` (`DateTime.now()` or an unseeded `Random()` in a game) and `number` (a numeric literal other than 0, 1, -1, 2, 0.0, 1.0 or 0.5 that isn't a named constant).
- **Exit code:** 0 when there is no FAIL, 1 when there is any, 2 for bad arguments, an unknown base or a missing git.
- **Messages (`--strings`):** `tools/review.sh --strings [--base <ref>] [--head <ref>]` compares the string literals of a diff instead of running the checks: the `.dart` files under any `lib/` or `bin/` folder, as they are at `--base` (default `HEAD`) and at `--head` (default the working tree, untracked files included), a file added or deleted counting with an empty other side. The literals are read as written in the source (quotes and `$x`/`${…}` kept, one literal per line of a `'''` string, no comments or `import`/`part` lines) and the two sides are compared as one multiset, so a text that moved to another changed file counts as unchanged (only files that differ are read: a copy that stays in an untouched file still shows as removed) while a renamed variable inside `${…}` counts as a change. It prints each text that is only on the old side as `- 'text'  file` and each one only on the new side as `+ 'text'  file:line`, sorted by file and line, then the totals:

  ```
  - 'A shape is {"circle": r}, {"rect": [w, h]} or {"polygon": [[x, y], ...]}'  packages/puzzle_game/lib/src/puzzle.dart
  + 'regular'  packages/puzzle_game/lib/src/puzzle.dart:109
  + 'A regular shape needs 3 or more sides'  packages/puzzle_game/lib/src/puzzle.dart:110
  + 'A regular shape needs a radius above 0'  packages/puzzle_game/lib/src/puzzle.dart:111
  + 'A shape is {"circle": r}, {"rect": [w, h]}, {"regular": [sides, r]} or {"polygon": [[x, y], ...]}'  packages/puzzle_game/lib/src/puzzle.dart:124
  strings: 1 removed, 4 added, 28 unchanged or moved
  ```

  Run it before committing a pure move: what it prints is then the texts that really changed (a move that only renamed variables shows a few pairs, one that changed no text shows none). `--head` needs `--strings` and `--strings` can't be used with `--all`; a run is information, not a check, so it exits 0 (2 only for bad arguments, an unknown ref or a missing git).
- **It doesn't replace the review, it finds the mechanical things first.** A design that won't hold, a name that lies, a test that checks the wrong thing and a race all pass it.

## tools/commit-job.sh

```bash
tools/commit-job.sh docs/briefs/m12/t2-g4.md                            # commit the job
tools/commit-job.sh docs/briefs/m12/t2-g4.md --dry-run                  # the files and the message, nothing staged
tools/commit-job.sh docs/briefs/m12/t2-g4.md --message-file message.txt # a message Claude edited
tools/commit-job.sh docs/briefs/m12/t2-g4.md --push
```

A finished job leaves work in a few places: the files its brief allowed, the brief, its report, and the review files of its gate. This stages exactly those and commits them with the message the report drafted, so committing a job is one command.

- **What it stages:** every change under the brief's `allow:` paths (modified, untracked and deleted files alike), the brief itself, its report (the `report:` line), and the job's `<brief>-review.md`, `<brief>-review-report.md` and `<brief>-plan.md` when they exist. `allow:` and `report:` are read the way `tools/flash.sh` reads them (` · ` between paths), and the paths are from the repository root.
- **What it never stages:** anything outside those paths, and no `*/windows/flutter/generated_*` file: Flutter rewrites those on every run, so they never belong in a commit.
- **It refuses (exit code 1), staging nothing,** when something was already staged before it ran (it lists it: commit or unstage that first), when the report the brief names isn't there, when the message is empty, or when there is nothing to commit under the allow paths.
- **The message:** the report's `## Commit message` section, without the code fence around it and without blank lines at its edges, or the file given with `--message-file`. When `COMMIT_TRAILER` is set in the environment, it is added as a last paragraph (a `Co-Authored-By:` line, for example).
- **Then** it prints `git diff --cached --stat` and the message, commits with `git commit -F` (hooks and signing run as configured: it never skips them), and pushes only with `--push`.
- **`--dry-run`** prints the same file list and message with a scratch index of its own, so the real index is untouched and nothing is committed: the same checks run as in a real commit.
- **Exit code:** 0 committed (or shown, with `--dry-run`), 1 refused or a git command failed, 2 bad use (no brief, a missing message file, a brief without `allow:`).
- **What it doesn't do:** choose which changes belong together, split a job into several commits, or edit the message. Those are decisions: change the message with `--message-file`, or say what to include in the brief.

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

- Don't pipe `start` into another command (`| tail`, `| head`): the app's Windows processes keep the pipe open, so the command never ends and looks stuck although the app is running (found in M11). Run it on its own, or redirect it to a file.
- Keys and clicks are real input, which Windows gives to the window in front, so `tv-window.ps1` only sends them once the TV window is confirmed in front, and otherwise stops with "nothing was sent". Before m11.1 they could land in another window: an Esc that reached the terminal stopped Claude Code's running command. (Input posted straight to the window doesn't work: Flutter ignores it while the window isn't active.)
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

### A quick check with real clients: tools/smoke.sh

```bash
tools/smoke.sh                # the development TV app and a simulated controller
tools/smoke.sh --emulator     # also the phone app on the emulator
tools/smoke.sh --keep         # leave what it started running
```

Before committing a change to `connection`, to the protocol or to the host, this checks it the way a phone would: over the real network stack, against the development TV app, without a phone in hand. Each step is proved by a line in the simulated controller's own output and, when the TV app's log is live, by the app's matching line too; the PASS line says which proofs it used (`sim`, `sim+tv`, `tv` or `tool`). The output below is a sample (sample; replaced after the first real run): the steps and their wording are what a run prints, the seconds are guesses.

```
PASS  tv-app        (0s)
TV app on port 45780, pairing code 5416 (log: /c/Users/.../thumbparty-dev/tv.log)
PASS  hello         (2s)
PASS  paired        (0s)
PASS  input         (10s)
PASS  metrics       (0s)
PASS  disconnect    (1s)
Smoke passed. Logs: /c/Users/.../thumbparty-smoke-20261106-195842
```

- **The steps.** `tv-app` starts the development TV app with `tools/tv-dev.sh start` (or uses the copy that is already running) and reads its port and pairing code. The simulated controller's 12-second run then proves, from its own output: `hello` (the host's `Welcome from …`, which is its answer to the hello), `paired` (`Paired with …`), `player` (the number the TV gave this controller), `ping` (the host's answers to its pings), `input` (its summary's `N input states sent, 0 drops`; the `--stream` option sends tilt 60 times a second), `metrics` (`metrics batch 1`) and `disconnect` once it has quit. Its `--name` is `Smoke controller`, so its lines can't be taken for the TV app's own built-in simulated controllers.
- **The TV app's own log, when it is live.** A step is also checked against the app's log then: `hello` against `Smoke controller (sim 0.11.0, supports metrics, rating) says hello from 127.0.0.1`, `paired` and `player` against `Smoke controller connected (pairing code), player 1`, `disconnect` against `Smoke controller disconnected`. A step passes on the simulated controller's line alone (`PASS hello (sim, 2s)`), and it prints `sim+tv` when the app's line came too. When the app's log is live and has no line for the step, the step fails and prints what the log says about the controller (`ping`, `input` and `metrics` have no line of the host's own: it answers pings and takes input and metrics silently).
- **When the app's log is silent.** In a sandbox `flutter run`'s tool can crash after the app starts (it can't make the folder it needs for a reload). The app keeps running and pairing, but its later lines no longer reach the log, which holds only the `[host] Listening on port …` line: that log isn't live, and the run goes on the simulated controller's proofs (`sim`) instead of failing. The log counts as live when it has a `[host]` line after the last `Listening` one. On an ordinary PC it is live and the steps print `sim+tv`.
- **The second connect, with the saved pairing.** `sim_controller`'s `--token-file` makes it save the pairing after the first connect (this controller's id, the host's id and the token the host gave) to `sim-token.json` in the run's folder, deleted when the run ends. A second, 5-second run then connects with that file and no code: `reconnect` passes when it reaches `CONNECTED` without `Sending pairing code`, and the app's log adds `Smoke controller connected (saved pairing), player 1`.
- **With `--emulator`** it also boots the emulator if none is attached, installs the phone app when the device hasn't got it (`pm path com.thumbparty.app` finds nothing, so `tools/emulator.sh install` runs: `phone-install`), launches the phone app with cleared data (`phone-app`), connects it to `10.0.2.2:<port>` with the pairing code (`phone-paired`: `tools/emulator.sh connect` exits 0 once the phone shows the player badge), saves a screenshot to the run's folder (`phone-shot`) and launches the app once more, which clears its data so it doesn't rejoin a TV later (`phone-reset`). `phone-hello` reads the app's log for the phone's hello, and is skipped when that log is silent (its `tv` proof is the only one there is). The emulator is left running.
- **A failure** is a step that doesn't see its line within 20 s (`SMOKE_WAIT_SECS` changes that; the summary steps wait the simulated controller's whole run plus that): it prints `FAIL <step>`, the last 10 lines of the log that step was reading (the simulated controller's, the TV app's, or the tool's own output), the TV app's lines about the controller when its log is live, and `Smoke failed: <step>`.
- **Safety.** It starts the TV app only when no development copy is running, and never touches a release copy. On the way out it stops only what it started (the simulated controller, and the development TV app through `tools/tv-dev.sh stop`, which stops this repository's debug build only), unless `--keep` leaves them running. It never stops a phone, the emulator, or any other process. Like `tv-dev.sh` it needs Windows (Git Bash) and Flutter.
- **The output folder** (`%TEMP%`, `$TMPDIR` or `/tmp`, named `thumbparty-smoke-<date>-<time>`) holds each tool's own output (`tv-start.log`, `sim.log`, `sim2.log`, `emulator.log`, `phone-*.log`) and, with `--emulator`, `phone.png`. Its path is printed at the end; the saved pairing (`sim-token.json`) is deleted on the way out.
- **Exit code:** 0 smoke passed, 1 a step failed, 2 bad use or a missing tool.
- **What it doesn't check:** whether anything looks right on screen (that still needs the screenshots and a person), sound, and a saved pairing that outlives the TV app: the second run reconnects to the same running app, not one restarted since.

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

## Helper agents for Claude Code

Three sub-agents in [`.claude/agents/`](../.claude/agents) let Claude Code hand the most repetitive jobs to a cheaper model (Haiku, or DeepSeek Flash for `flash-worker`). They run the scripts above and return only a short summary, so long test and build output never fills the main conversation. Claude Code loads them when it starts in this repository; `/agents` lists them.

| Agent | Model | Does | Never does |
| --- | --- | --- | --- |
| [`test-runner`](../.claude/agents/test-runner.md) | Haiku | Runs `tools/check.sh` (all checks or some) and reports the PASS/FAIL lines, plus the failing tests' expected and actual lines | Edit files, fix anything, run git commands that change things, touch apps or devices |
| [`release-checker`](../.claude/agents/release-checker.md) | Haiku | Runs `tools/release.sh <tag> "<notes>" --yes` for a tag **the user has approved**, or `--status <tag>`, and returns the summary | Choose or create tags itself, retry, work around a failed check, edit files or settings |
| [`flash-worker`](../.claude/agents/flash-worker.md) | Haiku, handing the work to DeepSeek Flash | Runs `tools/flash.sh "<task>"`: a separate, headless Claude Code (`--bare`) on DeepSeek's API does one well-defined job that copies a pattern (`lib/` code filling in a design Claude made, tests from a case list, doc and status updates, renames, analyzer fixes, drafts) and reports the changed files | Commit, release, run git commands that change things, decide anything, or work on protocol, connection or platform code |

How they're used:
- Claude Code uses `test-runner` after code changes and before commits and releases. Once you say "tag m11.2", it runs `tools/release.sh <tag> "<notes>" --yes` itself in the background (since M11; `release-checker` is used only if you ask for it). You can also ask for them by name ("use the test-runner").
- Claude Code runs `tools/flash.sh` directly (in the background) for every job from Claude's briefs, up to the review gate each brief names (the split and the gates are in [project-notes.md](project-notes.md#how-we-work)), then reviews the diff and runs `test-runner` before committing. The `flash-worker` agent does the same thing and is kept for when you ask for it by name. It needs `DEEPSEEK_API_KEY` set (a Windows user environment variable) and bills DeepSeek, not the Claude subscription. `FLASH_MODEL` picks another DeepSeek model.
- The judgment work stays with the main model: writing code and tests, fixing failures, and the hands-on checks with screenshots (`tv-dev.sh`, `emulator.sh`), where most real bugs were found.
- To use a different model, change the `model:` line in an agent's file (`haiku`, `sonnet`, `opus`).
- The agent files are plain instructions around the scripts. Another company's coding agent can't load them, but it can follow the same scripts and this document.

## DeepSeek Flash helper: set up, check, remove

`tools/flash.sh` sends pattern-copying work to DeepSeek Flash so it doesn't use the Claude subscription. The main Claude Code session stays on the subscription. Only the separate process that [`tools/flash.sh`](../tools/flash.sh) starts talks to DeepSeek, and only while it runs: nothing is installed, and Claude Code's sign-in and settings aren't changed.

How it fits together: Claude Code (subscription) → `tools/flash.sh` (run directly; or through the `flash-worker` agent if asked by name) → `claude --bare -p` with `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic` → DeepSeek Flash edits files in the working tree. `--bare` never reads the Claude sign-in, so this process can't use the subscription by mistake. What it may do is set in the script, and Claude Code enforces it rather than relying on the model to obey:
- **Tools:** `--bare` offers only Read, Edit (which also creates files) and Bash. Read is limited to the repository. Bash is limited to formatting, analysis and tests (`dart`, `flutter`, `tools/check.sh`, `tools/review.sh`), read-only `git status`, `log`, `diff`, `show`, `grep`, `ls-files` and `merge-base`, `ls` and `wc`. Git commands that change anything (`worktree` included), `rm`, `gh`, `tools/release.sh`, sub-agents and the web are blocked.
- **Files it can't change:** `.github/`, `codemagic.yaml`, `firebase/`, `.claude/`, `kenney-audio/`, every `docs/PRD*` file (the PRDs and the owner's backups: PRD changes are judgment calls, so the main session makes them), `tools/release.sh`, `tools/flash.sh` and `tools/flash_usage.dart`. Editing or creating them is refused.
- **Files it can't read:** anything outside the repository (so `%USERPROFILE%\.thumbparty\` and other sign-ins stay private), except the folders a job names with `--read`, and in the repository or those folders any signing key, service account or `.env` file, in case one is ever put there. Whatever it reads is sent to DeepSeek.
- **Reading outside folders, per job:** `--read <folder>` (repeatable) lets that one job read a folder outside the repository, such as the DeepSeek workspace's sounds or shader notes, instead of pasting excerpts into the brief. It can't change anything there: writes are refused by a deny rule, and the script's after-run checks only cover the repository. The script refuses the home folder and anything above it, the repository itself, and folders that hold keys or sign-ins (`~/.thumbparty`, `~/.ssh`, `~/.android`, `~/.config`, `~/.gnupg`, `~/.aws`, `~/AppData`), or anything inside them.
- **Not a sandbox:** it can run tests, and a test is code, so a model that deliberately misbehaved could get around these rules. They stop mistakes, not a hostile model.
- **Checked again afterwards:** the script compares those files before and after the run. If any changed anyway, it ends with `PROTECTED FILES CHANGED` and exit code 3.
- **Only the files the job names:** `--allow <path>` (repeatable; a folder covers everything in it) lists what the job may change, and the worker is told. Any other file the run changes, creates or deletes ends the job with `CHANGED FILES OUTSIDE --allow` and exit code 4. Without `--allow` the job is read-only. Files that were already changed before the run don't count.
- **Checks run for you:** `--check <names>` runs `tools/check.sh <names>` after the worker finishes (e.g. `--check puzzle`); a failure gives exit code 5.
- **Briefs as options:** `--brief <file>` reads the brief's `allow:`, `check:`, `report:` and `pub:` header lines as the options above, and the task becomes "read the brief" ([briefs/README.md](briefs/README.md) has the templates). The script reads `DEEPSEEK_API_KEY` from the Windows user environment itself when the shell doesn't have it; it never prints it.
- **Paperwork in the report:** with `--report`, a job that changes files ends its report with a draft commit message (printed at the end of the run), a STATUS row and a Delete list. The worker can't delete files, so the script deletes the listed ones that are inside `--allow`, before the checks; anything else on the list is refused and named.
- **Dependencies:** `--pub` (or `pub: yes` in the brief) lets the worker run `flutter pub get` and change `pubspec.lock`, for a brief that adds a dependency.
- **A worktree per job:** by default the job runs in a worktree of its own in `<repo>-jobs/` next to the checkout: a copy of the checkout as it is, uncommitted and untracked files included (not `kenney-audio/`), with its packages resolved. You and Claude can keep working in the checkout, and jobs on separate files can run side by side. At the end the job's changes are applied back to the checkout and the worktree is removed; if the same files changed in the checkout meanwhile, nothing is applied, and the patch and the worktree are kept (exit 6). `--here` runs in the checkout instead, the old way.
- **What it knows about the project:** `--bare` skips Claude Code's project notes, so the script gives it a short set of rules and points it to [project-notes.md](project-notes.md).

It ends by printing the files this run changed, their `git diff --stat`, the check results and `flash: result <code>`: 0 when everything passed, otherwise the first that applies of 3 (protected file), 4 (outside `--allow`), the worker's own exit code, 5 (a check failed), 6 (the changes couldn't be applied back); 2 for bad arguments, a missing key or a failed worktree setup.

**Token use.** After the worker's answer it prints a usage line (turns, seconds, input, cache and output tokens), and every job adds one line to `~/.thumbparty/flash-usage.tsv` (`FLASH_USAGE_LOG` moves it): the time, the result code, those numbers, the files changed and the task's first line. [`tools/flash_usage.dart`](../tools/flash_usage.dart) reads the run's JSON result; the cost figure in it is left out, because it's worked out at Anthropic's prices, not DeepSeek's (DeepSeek's own dashboard has the bill). To compare with the main session, look at `/usage` in Claude Code.

```bash
tools/flash.sh --brief docs/briefs/m12/s3-g1.md
tools/flash.sh --allow packages/puzzle_game/test/rules_test.dart --check puzzle "<spec>"
```

Whatever Flash works on is sent to DeepSeek's servers. Keep unreleased designs and anything private away from it.

**Set up on a computer** (once per computer; the agent and script come with the repository):
1. Have Git Bash and the `claude` CLI (`claude --version` in Git Bash).
2. Create an API key at [platform.deepseek.com](https://platform.deepseek.com) and add some credit.
3. Save it as a user environment variable, then open a new terminal and restart Claude Code so they see it:
   ```powershell
   [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', '<key>', 'User')
   ```
   macOS or Linux: `export DEEPSEEK_API_KEY=<key>` in `~/.zshrc` or `~/.bashrc`.
4. Optional: `FLASH_MODEL` picks another DeepSeek model (default `deepseek-v4-flash`; DeepSeek maps names it doesn't know to Flash).

**Check it:**
```bash
tools/flash.sh --dry-run "test"     # prints the command; doesn't call DeepSeek
tools/flash.sh "Reply with OK"      # prints OK, and git status shows nothing new
```
Then, in Claude Code: "use the flash-worker to <a job>" (or let Claude Code decide; it runs `tools/flash.sh` itself), and review the diff.

**Turn it off on a computer** (the agent then answers "DEEPSEEK_API_KEY isn't set" and does nothing):
```powershell
[Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', $null, 'User')
```
Open a new terminal and restart Claude Code afterwards. Delete the key at platform.deepseek.com too if it won't be used again.

**Remove it from the repository:** revert the commit that added it (`git log --oneline -- tools/flash.sh` finds it, then `git revert <commit>`), or delete the `flash-worker` branch if it was never merged.

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
| DeepSeek API key (for `flash-worker`) | the `DEEPSEEK_API_KEY` user environment variable | `tools/flash.sh` only; everything else works without it | set it again ([DeepSeek Flash helper](#deepseek-flash-helper-set-up-check-remove)), or leave it unset to not use the helper |
| Claude Code's notes for this project | `~/.claude/projects/<folder name>/memory/` | Claude remembering the project state and your preferences | copy the `memory` folder into the matching folder on the new computer. The folder name comes from the repository's path (`C--Users-singh-game-controller` for `C:\Users\singh\game-controller`), so it changes if the path does. The same rules, open items and lessons are kept in [project-notes.md](project-notes.md), so nothing important is lost without the folder |

**First steps on the new computer:**
1. Install the tools in "What you need", and the rest of the toolchain from [building.md](building.md).
2. `git clone https://github.com/devtestman187/game-controller.git`, then `cd game-controller` and `flutter pub get`.
3. `gh auth login`.
4. `tools/check.sh`: everything should pass.
5. `tools/release.sh --status <the latest tag>`: shows that GitHub access works, without releasing anything.
