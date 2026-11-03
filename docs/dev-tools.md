# Developer tools

Two scripts replace the most repeated manual steps:

| Script | What it does | Takes |
| --- | --- | --- |
| [`tools/check.sh`](../tools/check.sh) | Every automated check (format, analyze, all seven test suites), one line each | about 3 minutes |
| [`tools/release.sh`](../tools/release.sh) | Tags a release with tester notes, pushes it, waits for the Play, TestFlight and Windows builds, and prints a summary | about 20 to 40 minutes, mostly waiting |
| [`tools/tv-dev.sh`](../tools/tv-dev.sh) | Starts and stops a development copy of the Windows TV app, and prints its port and pairing code | a few seconds (a few minutes for the first build) |
| [`tools/tv-window.ps1`](../tools/tv-window.ps1) | Screenshots, clicks and keys in that copy's window | instant |
| [`tools/emulator.sh`](../tools/emulator.sh) | Runs the phone app on the Android emulator: install with cleared data, connect to a TV app, list what's on screen, tap, screenshot | about a minute to boot |
| [`tools/audio/`](../tools/audio/README.md) | `render.py`, which generates the game's sound effects, and how to encode them | a few seconds |

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
- Claude Code runs `tools/flash.sh` directly (in the background) by default for work that copies an existing pattern (the split is in [project-notes.md](project-notes.md#how-we-work)), then reviews the diff and runs `test-runner` before committing. The `flash-worker` agent does the same thing and is kept for when you ask for it by name. It needs `DEEPSEEK_API_KEY` set (a Windows user environment variable) and bills DeepSeek, not the Claude subscription. `FLASH_MODEL` picks another DeepSeek model.
- The judgment work stays with the main model: writing code and tests, fixing failures, and the hands-on checks with screenshots (`tv-dev.sh`, `emulator.sh`), where most real bugs were found.
- To use a different model, change the `model:` line in an agent's file (`haiku`, `sonnet`, `opus`).
- The agent files are plain instructions around the scripts. Another company's coding agent can't load them, but it can follow the same scripts and this document.

## DeepSeek Flash helper: set up, check, remove

`tools/flash.sh` sends pattern-copying work to DeepSeek Flash so it doesn't use the Claude subscription. The main Claude Code session stays on the subscription. Only the separate process that [`tools/flash.sh`](../tools/flash.sh) starts talks to DeepSeek, and only while it runs: nothing is installed, and Claude Code's sign-in and settings aren't changed.

How it fits together: Claude Code (subscription) → `tools/flash.sh` (run directly; or through the `flash-worker` agent if asked by name) → `claude --bare -p` with `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic` → DeepSeek Flash edits files in the working tree. `--bare` never reads the Claude sign-in, so this process can't use the subscription by mistake. What it may do is set in the script, and Claude Code enforces it rather than relying on the model to obey:
- **Tools:** `--bare` offers only Read, Edit (which also creates files) and Bash. Read is limited to the repository. Bash is limited to formatting, analysis and tests (`dart`, `flutter`, `tools/check.sh`), read-only `git status`, `log`, `grep` and `ls-files`, and `ls`. Git commands that change anything, `rm`, `gh`, `tools/release.sh`, sub-agents and the web are blocked.
- **Files it can't change:** `.github/`, `codemagic.yaml`, `firebase/`, `.claude/`, `kenney-audio/`, every `docs/PRD*` file (the PRDs and the owner's backups: PRD changes are judgment calls, so the main session makes them), `tools/release.sh`, `tools/flash.sh` and `tools/flash_usage.dart`. Editing or creating them is refused.
- **Files it can't read:** anything outside the repository (so `%USERPROFILE%\.thumbparty\` and other sign-ins stay private), and inside it any signing key, service account or `.env` file, in case one is ever put there. Whatever it reads is sent to DeepSeek.
- **Not a sandbox:** it can run tests, and a test is code, so a model that deliberately misbehaved could get around these rules. They stop mistakes, not a hostile model.
- **Checked again afterwards:** the script compares those files before and after the run. If any changed anyway, it ends with `PROTECTED FILES CHANGED` and exit code 3.
- **Only the files the job names:** `--allow <path>` (repeatable; a folder covers everything in it) lists what the job may change, and the worker is told. Any other file the run changes, creates or deletes ends the job with `CHANGED FILES OUTSIDE --allow` and exit code 4. Without `--allow` the job is read-only. Files that were already changed before the run don't count.
- **Checks run for you:** `--check <names>` runs `tools/check.sh <names>` after the worker finishes (e.g. `--check puzzle`); a failure gives exit code 5.
- **What it knows about the project:** `--bare` skips Claude Code's project notes, so the script gives it a short set of rules and points it to [project-notes.md](project-notes.md).

It ends by printing the files this run changed, their `git diff --stat`, the check results and `flash: result <code>`: 0 when everything passed, otherwise the first that applies of 3 (protected file), 4 (outside `--allow`), the worker's own exit code, 5 (a check failed); 2 for bad arguments or a missing key.

**Token use.** After the worker's answer it prints a usage line (turns, seconds, input, cache and output tokens), and every job adds one line to `~/.thumbparty/flash-usage.tsv` (`FLASH_USAGE_LOG` moves it): the time, the result code, those numbers, the files changed and the task's first line. [`tools/flash_usage.dart`](../tools/flash_usage.dart) reads the run's JSON result; the cost figure in it is left out, because it's worked out at Anthropic's prices, not DeepSeek's (DeepSeek's own dashboard has the bill). To compare with the main session, look at `/usage` in Claude Code.

```bash
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
