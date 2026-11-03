# Demo video runbook (for an AI agent)

Nov 3, 2026. A step-by-step procedure that an AI agent with access to the owner's Windows PC follows to:
1. check that **m11.3** (the "Bubble Pop" sounds and the active-time fix for the stats) is already released;
2. build the scripted demo pipeline;
3. generate scripted stats sessions;
4. capture all footage;
5. produce the demo video described in [demo-video.md](demo-video.md).

No human plays, films or edits. The owner only answers the STOP gates.

**Scope (owner, Nov 3, 2026):** the 2:30 master and the 60-second recruiter cut. The 45 s, vertical and pairing cutdowns are optional and come later, from the same edit list (5.5).

**Time budget:** about 10 to 15 hours of machine time in all: about 2.5 hours for the 18 stats sessions, plus the captures, retakes and renders.

**STOP gates, in order:**
1. 2.1: the demo build runs full screen with its own data.
2. 2.4 Step A: the touch test clip.
3. 3.2: the first recorded race take.
4. 3.4: the footage review.
5. 5.6: the final review.

Small STOPs also appear where something fails or needs the owner once, such as Do Not Disturb in 3.1.

**Access the harness needs:**
- **Write access** to:
  - `C:\Users\singh\game-controller` (the repository);
  - `C:\Users\singh\thumbparty-demo` (the work folder);
  - `C:\Users\singh\AppData\Roaming\obs-studio` (OBS settings, 2.6);
  - `C:\Users\singh\AppData\Roaming\Code\User` (VS Code settings for the editor shots, 3.3);
  - the harness's own workspace, for preview copies.
- **Network access**, and the owner's git sign-in, to push the `demo-video` branch.

The owner may grant full access instead. The ground rules below still apply either way.

**How to use this file:**
- Do the phases in order. Inside a phase, do the steps in order.
- Every step says what to do, which command to run, what to expect, and when it's done.
- A **STOP** line means: report to the owner and wait for their written answer before going on.
- If a command's output differs from the "Expect" line, stop and report what happened. Don't improvise a workaround that changes the plan.
- [demo-video.md](demo-video.md) is the creative spec (script, storyboard, edit rules). This file is the procedure. If they disagree, this file wins for *how*, and demo-video.md wins for *what appears on screen*.

---

## 0. Ground rules

These come from the project's working rules ([project-notes.md](project-notes.md)). They apply to every step.

1. **Shell.** Run bash commands in **Git Bash** (`C:\Program Files\Git\bin\bash.exe`). Run PowerShell commands in **Windows PowerShell 5.1**; PowerShell scripts need `-ExecutionPolicy Bypass`. Every command below says which shell.
2. **Repository:** `C:\Users\singh\game-controller` (Git Bash: `/c/Users/singh/game-controller`). Work only on the branch `demo-video` (created in Phase 1). Commit only when a step says so. After each phase, push the branch (`git push -u origin demo-video`) as a backup. Never commit to, push to, merge into or rebase `main`; the owner merges the branch later. Never commit the files listed under "Never commit" in project-notes.md, or anything in `C:\Users\singh\thumbparty-demo\`.
3. **Never stop processes by name.** The owner may have release copies of `ThumbPartyTV.exe` running from Downloads, and phones paired with them. Stop only processes you started, by the PID you recorded. The same goes for emulators (stop with `tools/emulator.sh stop` or `adb -s <serial> emu kill`), OBS and scrcpy.
4. **Checks:** run `tools/check.sh` (Git Bash) after every code change. It runs format, analyze and the seven test suites, one line each. Every line must say ok before a commit.
5. **No releases.** Never create or push tags, never run `tools/release.sh`, never change app versions. Nothing in this runbook ships to testers.
6. **Big files** (footage, renders, sessions, tools you download) go in `C:\Users\singh\thumbparty-demo\` (Git Bash: `/c/Users/singh/thumbparty-demo`). That's the **work folder**, outside the repository. Code and small configs go in the repository under `tools/demo/`.
7. **Owner's data is off limits.**
   - Don't modify, move or delete anything in `%APPDATA%\Thumb Party\Thumb Party TV\` yourself.
   - The demo build itself adds the `sessions-demo` folder and its own `demo.`-prefixed keys to `shared_preferences.json`. Nothing else may change.
   - Back up `shared_preferences.json` before the first demo run (2.1 step 8) and before Phase 3 (step 3.1).
   - **Before every start of the demo TV app**, list running `ThumbPartyTV.exe` processes (`tasklist //FI "IMAGENAME eq ThumbPartyTV.exe"`). If any is running that you didn't start (by PID), **STOP** and ask the owner to close it. Two copies would share the settings file and could overwrite each other's saves. Never close it yourself.
8. **Secrets:** none are needed. Never print `DEEPSEEK_API_KEY` or any token.

---

## Environment (E)

### E1. What is already installed (verified Nov 3, 2026)
| Tool | Path | Notes |
| --- | --- | --- |
| Git Bash | `C:\Program Files\Git\bin\bash.exe` | |
| Flutter and Dart | `C:\src\flutter\bin\flutter`, `C:\src\flutter\bin\dart` (on PATH) | Use only this SDK |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` (`C:\Users\singh\AppData\Local\Android\Sdk`) | |
| adb | `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` (on PATH) | |
| Android emulator | `%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe`, version 37.2.13 | Has the gRPC bridge and `lib\emulator_controller.proto` |
| AVD `m7_android12` | `C:\Users\singh\.android\avd\m7_android12.avd` | Phone, Android 12 (API 31), AOSP image (`adb root` works), 1080×2400, 420 dpi, accelerometer and gyroscope on, `hw.gpu.enabled=no` (launch with `-gpu host`) |
| AVD `m8_pixel_tablet` | `C:\Users\singh\.android\avd\m8_pixel_tablet.avd` | Tablet, Android 12, 2560×1600, 320 dpi |
| ffmpeg and ffprobe | `C:\Users\singh\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe`, `...\Links\ffprobe.exe` | Version 9.0.2 (Gyan full build). **Not on Git Bash's PATH.** Add it with the line below |
| GitHub CLI | `C:\Program Files\GitHub CLI\gh.exe` | Signed in as the owner |
| winget | on PATH | Used to install what's missing |
| Windows Terminal | `wt.exe` (on PATH) | Terminal shots |
| Microsoft Edge | `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe` | **Not on PATH**: always use the full path |
| VS Code | `C:\Users\singh\AppData\Local\Programs\Microsoft VS Code\Code.exe`, command `C:\Users\singh\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd` | Version 1.143.1, installed Nov 3, 2026 for the editor shots (user install, fresh settings). `code` is on the user PATH in new shells; otherwise use the full path |
| Project scripts | `tools/check.sh`, `tools/tv-dev.sh`, `tools/tv-window.ps1`, `tools/emulator.sh` | Documented in [dev-tools.md](dev-tools.md) |
| Bubble Pop sounds | `C:\Users\singh\Documents\deepseek-harness\default-workspace\thumb-party-audio\` | `final\palette-b-bubble-pop\*.ogg`, `INSTALL.md`, `render.py` |

In every Git Bash session for this runbook, first run:
```bash
export PATH="/c/Users/singh/AppData/Local/Microsoft/WinGet/Links:$PATH"
export WORK=/c/Users/singh/thumbparty-demo
export REPO=/c/Users/singh/game-controller
```

**Hardware:** Intel i5-8350U, Intel UHD Graphics 620, 16 GB RAM, one 1920×1080 display. This is a modest machine. The capture plan keeps the load down: hardware encoding (Intel Quick Sync), the phone recorded at reduced size, and one emulator at a time.

### E2. Programs installed on Nov 3, 2026: check them
Python, OBS Studio and scrcpy were installed with winget on Nov 3, 2026 and are on the user PATH for new shells:

| Program | Version | Path |
| --- | --- | --- |
| Python | 3.12.10 | `C:\Users\singh\AppData\Local\Programs\Python\Python312\python.exe`; launcher `C:\Users\singh\AppData\Local\Programs\Python\Launcher\py.exe` |
| OBS Studio | 33.0.0 | `C:\Program Files\obs-studio\bin\64bit\obs64.exe` |
| scrcpy | 5.0.1 | `C:\Users\singh\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v5.0.1\scrcpy.exe` (its folder is on the user PATH) |

Check in a **new** Git Bash window:
```bash
py -3.12 --version                                       # Expect: Python 3.12.10
ls "/c/Program Files/obs-studio/bin/64bit/obs64.exe"     # Expect: the path is printed
scrcpy --version | head -1                               # Expect: scrcpy 5.0.1 ...
```
If `py` or `scrcpy` isn't found, the shell started before the install: open a new one, or call them by the full paths above. If a program is missing entirely (a different PC), install it in **PowerShell** and accept the defaults:
```powershell
winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
winget install --id OBSProject.OBSStudio -e --accept-source-agreements --accept-package-agreements
winget install --id Genymobile.scrcpy -e --accept-source-agreements --accept-package-agreements
```
Later steps use scrcpy 5 options (`--no-window`, `--record`, `--max-fps`, `--max-size`, `--no-audio`, `--time-limit`). If `scrcpy --help` doesn't list one of them, **STOP** and report.

**Python** is called only as `py -3.12` (on this PC `python` may still resolve to the Microsoft Store placeholder in older shells). Create the virtual environment for graphics:
```bash
mkdir -p $WORK && cd $WORK
py -3.12 -m venv venv
./venv/Scripts/python.exe -m pip install --upgrade pip
./venv/Scripts/python.exe -m pip install numpy==2.* pillow==11.* matplotlib==3.*
```
Expect: "Successfully installed …". From now on, Python means `$WORK/venv/Scripts/python.exe`, run with `-I`.

### E3. On a different computer
If this runbook runs on another PC, follow [building.md](building.md) for the Flutter toolchain, the Android SDK and the `m7_android12` AVD. Create the tablet AVD with Android Studio's Device Manager: Pixel Tablet, API 31 x86_64 "default" image (not Google Play, so `adb root` works). Then do E2. The paths in E1 change; set `WORK` and `REPO` accordingly, and find ffmpeg with `where ffmpeg` in PowerShell.

### E4. Work folder layout
Create it now (Git Bash):
```bash
mkdir -p $WORK/{footage,logs,sessions,charts,graphics,audio,edit,renders,qa,backup}
```
| Folder | Holds |
| --- | --- |
| `footage/` | Raw captures, named `<shotID>_take<N>_<source>.<ext>`, for example `G3_take2_tv.mkv` and `G3_take2_phone.mp4` |
| `logs/` | The director's event logs and the touch driver's logs, named like the footage (`G3_take2_events.jsonl`, `G3_take2_touch.jsonl`) |
| `sessions/` | The scripted stats dataset (copied from `sessions-demo`) |
| `charts/`, `graphics/` | Rendered PNGs and PNG sequences |
| `audio/` | Music bed, sound cues for graphics |
| `edit/` | The edit decision list and intermediate clips |
| `renders/` | The finished videos |
| `qa/` | Contact sheets and check reports |
| `backup/` | The owner's preferences backup |

---

## Phase 1. Check that m11.3 is in place (don't build it)

m11.3 (the Bubble Pop sounds and the active-time fix for the stats) is built and released **before** this runbook starts, outside it. Appendix A keeps its design for reference only. This phase only checks it. Run in Git Bash:
```bash
cd $REPO && git fetch origin --tags
git tag -l m11.3                                                    # Expect: m11.3
git merge-base --is-ancestor m11.3 origin/main && echo ok           # Expect: ok
grep -c "activeMs" packages/metrics/lib/src/segment.dart            # Expect: 3 or more
grep -c "open_minutes" packages/metrics/lib/src/report.dart         # Expect: 1 or more
cmp assets/audio/snap.ogg "/c/Users/singh/Documents/deepseek-harness/default-workspace/thumb-party-audio/final/palette-b-bubble-pop/snap.ogg" && echo same   # Expect: same
```
If any line differs from its "Expect", **STOP** and tell the owner: "m11.3 isn't in place: <which check failed>". Don't implement it yourself.

Then create the working branch from the current main:
```bash
git checkout main && git pull --ff-only && git checkout -b demo-video
```

## Phase 2. Demo tooling

All tooling lives in the repository so it's versioned:
- **TV app side:** `tv_test_app/lib/src/demo/`.
- **Host scripts (Dart, standard library only, no packages):** `tools/demo/*.dart`, run with `dart run tools/demo/<name>.dart` from the repository root.
- **Graphics (Python):** `tools/demo/graphics/*.py`.
- **Scene scripts:** `tools/demo/scenes/*.json`.
- **Touch layouts:** `tools/demo/layouts/*.json`.

Commit after each step that ends with "commit". Message prefix: `demo:`. No release is needed for any of Phase 2: the demo code is off in store builds.

### 2.1 Build flags and data isolation (TV app)
1. Create `tv_test_app/lib/src/demo/demo_flags.dart`:
   ```dart
   /// On only in builds made with --dart-define=DEMO_DIRECTOR=true (the demo
   /// video pipeline, docs/demo-video-runbook.md). Store builds never set it.
   const bool demoDirector = bool.fromEnvironment('DEMO_DIRECTOR');
   ```
2. **Sessions folder:** in `tv_test_app/lib/src/host_controller.dart` (line ~427, where the folder is `kDebugMode ? 'sessions-debug' : 'sessions'`), use `demoDirector ? 'sessions-demo' : (kDebugMode ? 'sessions-debug' : 'sessions')`.
3. **Preferences:** in the TV app's `main()`, before the first `SharedPreferences.getInstance()`, add `if (demoDirector) SharedPreferences.setPrefix('demo.');`. Demo runs then keep their own pairings, consent and Puzzle settings, and never touch the owner's. Check `shared_preferences` supports `setPrefix` in the version in `pubspec.lock`. If it doesn't, stop and report.
4. **Window:** when `demoDirector`, the TV app starts **borderless, full screen at 1920×1080** on the primary display. Use the existing Windows runner; if there's no full-screen helper, add one in `tv_test_app/windows/runner/` that maximises without borders when the `DEMO_DIRECTOR` define is set. Pass the define through `flutter build` as `--dart-define` and read it in Dart; ask the runner to go full screen through a method channel call from Dart at startup.
5. **No debug UI:** the debug overlay starts off; check that nothing on screen says "debug", "profile" or "demo".
6. Add a test in `tv_test_app/test/` that `demoDirector` is false in the test build.
7. `tools/check.sh` all ok, then commit `demo: DEMO_DIRECTOR flag, separate sessions and preferences`.
8. **Check and STOP.**
   - Build the profile demo app (the first command in 2.5) and start it.
   - Take a screenshot of the whole screen (OBS isn't set up yet; use `tools/tv-window.ps1`, whose screenshot command is in dev-tools.md, or a PowerShell `CopyFromScreen` one-liner).
   - Confirm these, and close the app by its PID:
     - (a) It fills the 1920×1080 screen with no border or title bar.
     - (b) Nothing says debug, profile or demo.
     - (c) `%APPDATA%\Thumb Party\Thumb Party TV\sessions-demo\` exists or is created on the first session, and nothing new appears in `sessions\`.
     - (d) The owner's settings are untouched. The demo build writes its own keys, all starting with `demo.`, into the same `shared_preferences.json`. So compare the file with a copy taken just before the run: every key that doesn't start with `demo.` must still be there with the same value, and no such key may be added.

   Send the owner the screenshot and the four results. Wait for OK before 2.2.

### 2.2 Live game access
The director must read the running game's state. Both views already accept an injected game:
- `PuzzlePlayView` uses `widget.match ?? PuzzleMatch(...)` in `packages/puzzle_game/lib/src/play_view.dart:89`.
- `ArenaView` uses `widget.game ?? ArenaGame()` in `packages/test_game/lib/src/arena_view.dart:66`.

1. In each of those two packages, add a top-level, nullable hook:
   - `void Function(PuzzleMatch match)? onPuzzleMatchCreated;` in play_view.dart;
   - `void Function(ArenaGame game)? onArenaGameCreated;` in arena_view.dart.

   Call each once, right after the game object is created or received, in `initState`. Doc comment: "For the demo director only; null in every normal run."
2. In `tv_test_app/lib/src/demo/`, set both hooks when `demoDirector` is true (in `main()`), storing the latest object in a `DemoLive` singleton (`PuzzleMatch? match; ArenaGame? arena;`), cleared in the views' `dispose` through matching `on…Disposed` hooks.
3. Tests: a widget test that pumps `PuzzlePlayView` with the hook set and checks it's called once with the match. Do the same for `ArenaView`.
4. Checks, then commit `demo: hooks to reach the running game`.

### 2.3 Demo director (TV app, `tv_test_app/lib/src/demo/`)
**Files:**
- `director.dart`: `DemoDirector`, the control server and the scene runner.
- `bot.dart`: `DemoBot`, a protocol bot.
- `steer.dart`: motion. Pure Dart, no Flutter.
- `scene.dart`: scene script parsing.
- `puzzle_brain.dart` and `arena_brain.dart`: the per-game planners.
- `events.dart`: the event log.

**Control server:** when `demoDirector`, start an `HttpServer` on `127.0.0.1:47900` with WebSocket upgrade at `/director`. Messages are JSON, one per frame:
| From the showrunner | Meaning |
| --- | --- |
| `{"t":"hello"}` | Reply `{"t":"state","port":<host port>,"code":"<pairing code>","screen":"<route name>"}` |
| `{"t":"bots","count":N,"mode":"sticks"}` | Create N `DemoBot`s (N 0 to 3) named "Bot 2", "Bot 3", … paired over loopback, like `HostController.addSimulatedController`, but driven by the director, not `runDemoInput`. Reply `{"t":"bots_ready","players":[…]}` when all are paired |
| `{"t":"scene","file":"<absolute path to scene JSON>","take":"G3_take2"}` | Load and run a scene. Events stream back. Reply `{"t":"scene_done","ok":true}` at the end, or `{"ok":false,"why":"…"}` |
| `{"t":"stop"}` | Stop the scene, release every input |
| `{"t":"reset"}` | Stop bots and scenes, go back to the home screen |

| From the director | Meaning |
| --- | --- |
| `{"t":"event","wall":<epoch ms>,"name":"…",…}` | Every scene event, also appended to `<take>_events.jsonl` in the folder given by `--dart-define=DEMO_LOG_DIR=<path>` |
| `{"t":"p1","x":…,"y":…,"buttons":[…],"tilt":[x,y]?}` | The intent for the visible phone (seat P1), 60 times a second. The touch driver turns it into touches |

**Events to log** (at least): `scene_start`, `screen` (route changes), `game_start`, `pickup` (player, piece), `rotate_start` and `rotate_end`, `drop` (player, piece, ok or wrong), `snap`, `wrong`, `help` (to player), `join_big`, `finish` (side, ms), `results`, `haptic` (to player, event), `pause` and `resume`, `scene_end`.
- `game_start` is taken from the first frame the board is drawn: subscribe to the match's first `update`.
- Haptics are logged from `ServerGameHost` haptic sends to each player.

**DemoBot:** wraps a `ControllerClient` with identity name "Bot N", platform `sim`, declaring the `layout` and `status` capabilities. It holds a `GamepadState` that the director sets every frame (60 Hz timer). It sends input only when the state changes, or at least every 100 ms while a stick is off-centre, like the phone app does.

**Steering (`steer.dart`):** one `Steer` per seat. Given the dot's position, a target and the game's move speed, it outputs a left-stick vector each frame:
1. **Path:** a quadratic curve from start to target, with a control point offset sideways by a random 0 to 15% of the distance (seeded).
2. **Speed profile:** ease-in over 150 ms, cruise at stick length 1.0, ease-out starting 1.5 dot-diameters from the target, down to 0.25 near it.
3. **Noise:** add a smooth random wobble of ±0.06 to the stick angle (sum of two sines at 0.7 Hz and 1.9 Hz, random phases).
4. **Reaction delay:** each new goal waits a random 150 to 350 ms before moving.
5. **Overshoot:** 15% of approaches overshoot by 0.3 to 0.6 dot-diameters, then correct.
6. **Rotation:** to reach a target angle, hold X or Y (whichever is shorter). Release when within the game's snap tolerance. 10% of the time release late by 8 to 15° and correct with the other button after 200 ms.
7. **All randomness** comes from one `Random(seed)` per seat. The seed is in the scene file, so takes are repeatable.

**PuzzleBrain:** reads `DemoLive.match`: boards, pieces (`PieceRuntime`: position, angle, carriers, placed), outline targets, players' positions and help calls. It turns goals into steering and buttons.
| Goal | What it does |
| --- | --- |
| `pick(piece)` | Steer to the piece's centre in the tray, press A (80 ms) |
| `place` | Rotate to the target angle while steering to the outline position, press A (80 ms) when within the drop tolerance |
| `wrongDrop(piece)` | Carry it to a spot 1.5 to 2 piece-widths from its outline, drop (it turns red), wait 600 ms, then `pick` and `place` it |
| `carryBigAlone` | Pick the big piece, steer toward its outline at whatever speed the game allows. Logs `help` as the game fires it |
| `joinBigCarry` | Steer to the big piece, press A on it, then steer the same way as the carrier |
| `waitFor(event, timeoutMs)` | Wait until the named event happens |
| `idle(ms)` | Stick centred, no buttons |
| `navigate([...])` | A list of `"up" "down" "left" "right" "a" "b" "start"` presses (120 ms each, 250 ms apart) for menus |
| `pace(finishMs)` | Spread the remaining goals so this seat's side finishes at about `finishMs` after `game_start`, by adding idle time between goals (never by slowing the stick) |

**ArenaBrain:** reads `DemoLive.arena`: player position, goal, walls and hazards (see `packages/test_game/lib/src/arena.dart`).
- Steer to the goal. If the straight line crosses a wall or hazard, steer to the nearest corner waypoint around it first.
- Dash (A) on straight stretches longer than 3 dot-diameters when the dash is ready.
- When stuck (less than 2 px of movement in 1 s), back off 400 ms in the opposite direction.

**Seat P1 (the visible phone):** the same brains plan P1, but the director doesn't set P1's gamepad. It sends `p1` intents to the touch driver. The real phone app then sends the input over the real protocol, and the director reads P1's dot like any other seat. In the scene file, P1 has `"via":"phone"`.

**Scene file format** (`tools/demo/scenes/*.json`):
```json
{
  "game": "puzzle",
  "puzzle": "rocket",
  "seed": 4242,
  "screenStart": "join",
  "teams": {"left": ["P1", "Bot 2"], "right": ["Bot 3", "Bot 4"]},
  "seats": {
    "P1":    {"via": "phone", "mode": "sticks", "goals": [{"pick": "nose"}, {"place": {}}]},
    "Bot 2": {"mode": "sticks", "goals": [{"carryBigAlone": "body"}]},
    "Bot 3": {"mode": "sticks", "goals": [{"pick": "left fin"}, {"wrongDrop": "left fin"}]},
    "Bot 4": {"mode": "sticks", "goals": [{"pick": "window"}, {"place": {}}]}
  },
  "pace": {"left": 52000, "right": 56000},
  "endAfter": "results"
}
```
- Seeds are fixed per scene. The puzzle seed goes to `PuzzleMatch`. If the join screen can't take a seed, add a demo-only way for the director to start the match with a given seed.
- Write these scenes, matching the storyboard shots in demo-video.md section 5:

| Scene | Shots | What happens |
| --- | --- | --- |
| `join.json` | G1 | P1 goes left, the bots join, Bot 3 switches sides, start |
| `race.json` | G2, G5 | Full 2 vs 2 race with a wrong drop; left finishes first at about 52 s |
| `bigpiece.json` | G3 | Bot 2 carries the body alone; the game sends help to P1; P1 joins; they place it |
| `pause.json` | G4 | P1 presses Start, the pause menu shows, Resume |
| `arena_dpad.json`, `arena_gyro.json`, `arena_sticks.json` | M1 to M3 | Arena, P1 alone, 20 s each |
| `menus.json` | R1, R2, C4 | P1 navigates home, then Play, Shape Race, Rocket; and Puzzle settings: Time limit +2 steps, then Reset to defaults |

**Tests** (`tv_test_app/test/demo/`):
- `Steer` reaches a target within tolerance from 20 random starts, at a fixed `dt` of 1/60 s.
- The stick never exceeds length 1.
- The same seed gives the same path.
- A `PuzzleBrain` running the `race.json` goals on a `MemoryGameHost` places every piece before the time limit.
- The scene parser rejects unknown goals with a clear error.

Then checks, and commit `demo: director, bots, scenes`.

### 2.4 Touch driver (`tools/demo/touch_driver.dart`)
It turns P1 intents into multi-touch on the emulator, and gyro intents into sensor values.

**Step A, spike. Do this first and stop if it fails.**
1. Start the phone emulator with GPU acceleration and the console (Git Bash):
   ```bash
   "$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd m7_android12 -gpu host -no-snapshot-save -port 5554 &
   adb -s emulator-5554 wait-for-device; until [ "$(adb -s emulator-5554 shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done
   adb -s emulator-5554 root; adb -s emulator-5554 wait-for-device
   adb -s emulator-5554 shell getevent -lp
   ```
   Find the device whose capabilities list `ABS_MT_POSITION_X` and `ABS_MT_SLOT`. Note its `/dev/input/eventN`, and the max of `ABS_MT_POSITION_X` and `_Y` (often 32767, not the pixel size).
2. Raw input injection: open one persistent stream, `adb -s emulator-5554 exec-in sh -c 'cat > /dev/input/eventN'`, and write binary `input_event` structs. The image is x86_64, so each struct is 24 bytes, little-endian: `tv_sec` int64, `tv_usec` int64 (both 0), `type` uint16, `code` uint16, `value` int32. Use multitouch protocol B:
   - per finger: `EV_ABS ABS_MT_SLOT <slot>`, `EV_ABS ABS_MT_TRACKING_ID <id or -1>`, `EV_ABS ABS_MT_POSITION_X <x>`, `EV_ABS ABS_MT_POSITION_Y <y>`, `EV_ABS ABS_MT_PRESSURE 50`;
   - then `EV_KEY BTN_TOUCH 1/0` when the first finger goes down or the last goes up;
   - then `EV_SYN SYN_REPORT 0`.

   Codes: EV_SYN 0, EV_KEY 1, EV_ABS 3, BTN_TOUCH 0x14a, ABS_MT_SLOT 0x2f, ABS_MT_POSITION_X 0x35, ABS_MT_POSITION_Y 0x36, ABS_MT_TRACKING_ID 0x39, ABS_MT_PRESSURE 0x3a, SYN_REPORT 0. Scale pixels to the raw range: `raw = px * (max + 1) / screenPx` along each axis, taking the current rotation into account (the app runs landscape; work out the mapping in the spike by touching the four corners and reading `getevent`).
3. Spike test: install the app (`tools/emulator.sh install` builds the debug APK if missing), launch, connect it to a TV app started with `tools/tv-dev.sh start` (`tools/emulator.sh connect 10.0.2.2:<port> <code>`), and switch to Sticks mode. Stream two fingers for 10 s at 60 Hz: the left one circling on the left stick, the right one circling on the right stick. Record with `scrcpy -s emulator-5554 --no-window --record $WORK/qa/spike.mp4 --max-fps 60 --max-size 1200 --time-limit 12`.

   **Pass when:** in `spike.mp4`, both sticks move smoothly at the same time, ffprobe reports about 60 fps, and the TV debug overlay (F3) shows both sticks changing.
4. **If raw injection fails** (permission or no movement), use the emulator's gRPC bridge instead:
   - start the emulator with `-grpc 8554 -grpc-use-token`;
   - the service is `android.emulation.control.EmulatorController`, method `sendTouch(TouchEvent{touches: [Touch{x, y, identifier, pressure}]})` in `%LOCALAPPDATA%\Android\Sdk\emulator\lib\emulator_controller.proto`;
   - the token is in `C:\Users\singh\.emulator_console_auth_token`;
   - this needs `protoc` and the Dart `grpc` package in a separate package `tools/demo/grpc_touch/`. Ask the owner before adding it.

   If both fail, **STOP** and report.
5. **STOP** and show the owner `spike.mp4` (path and a contact sheet). Continue after their OK.

**Step B, layouts.** For each mode (D-pad, Gyro, Sticks) on each AVD, record the screen pixel centres and radii of every control: D-pad centre and arm length; left and right stick centres and radius (fixed sticks) or the left and right touch zones (floating); A, B, X, Y, Start and Select.
- Use `tools/emulator.sh ui` (labels with centres) and `tools/emulator.sh shot` to confirm.
- Save as `tools/demo/layouts/m7_android12-<mode>.json` and `m8_pixel_tablet-<mode>.json`, in the form `{"dpad":{"x":…,"y":…,"arm":…},"ls":{…},"rs":{…},"a":{"x":…,"y":…,"r":…},…}`.
- Also record the default button size setting in effect. Layouts depend on it.
- **Screens other than the controller:** for each screen the footage touches, record the centres of the controls it uses in `tools/demo/layouts/<avd>-screens.json`:
  - the **Connect** screen (address field, code field, Connect button);
  - **Settings** (the Button size slider's track ends and thumb, the Floating sticks switch, the Help (puzzle) **Try** button, the scroll area);
  - the **rating prompt** (three faces, each tag, Done or Skip);
  - **Diagnostics** (the scroll area);
  - the mode switch (D-pad, Gyro, Sticks).
- **On-screen keyboard:** tap the address field, then the code field, and record from a screenshot the centre of every key needed to type an address and a 4-digit code: digits 0–9, `.`, `:`, backspace and Enter, on whichever keyboard Android shows for that field. If `.` or `:` are on a second keyboard page, record the page-switch key and the keys on that page. Store them in the same file under `"keyboard": {"address": {...}, "code": {...}}`.

**Step C, the driver:** `dart run tools/demo/touch_driver.dart --serial emulator-5554 --layout tools/demo/layouts/m7_android12-sticks.json --director ws://127.0.0.1:47900/director --log $WORK/logs/<take>_touch.jsonl [--human-model off|stats]`
- It turns each `p1` intent into finger positions:
  - **Sticks:** the left finger goes to `ls.centre + stick * ls.radius * 0.9`. Buttons tap at their centres with the right finger. While a finger is down it keeps the same tracking ID; moving to the next button lifts and re-touches.
  - **D-pad:** the left finger presses the arm for the intent's direction (8 directions; diagonals between arms).
  - **Gyro:** no finger. Send the tilt to the emulator's sensors (Step D).
  - **Menus:** D-pad taps.
- **Generic commands** for everything that isn't play. The showrunner sends them over a local control socket (`127.0.0.1:47901`, one JSON object per line). Each command runs through the same 60 Hz injection, so every touch is real and appears in the touch log:

  | Command | What it does |
  | --- | --- |
  | `{"cmd":"tap","x":…,"y":…,"ms":80}` | Finger down, hold `ms`, up. `x` and `y` may be a layout name instead, e.g. `{"cmd":"tap","at":"settings.floatingSwitch"}` |
  | `{"cmd":"drag","from":[x,y],"to":[x,y],"ms":1500}` | Down at `from`, move along an eased path to `to` over `ms` (ease-in-out), hold 100 ms, up. Used for sliders |
  | `{"cmd":"scroll","in":"diagnostics.scroll","dy":-900,"ms":600}` | A drag inside a scroll area, by `dy` pixels, released with a small fling |
  | `{"cmd":"type","field":"address","text":"10.0.2.2:45780","perKeyMs":[180,260]}` | Tap the field, then tap each character's key on the on-screen keyboard (from the layout's `keyboard` section, switching keyboard pages when needed), waiting a random 180–260 ms between keys (seeded). Ends with Enter only if the text ends in `\n` |
  | `{"cmd":"wait","ms":…}` | Pause |
  | `{"cmd":"mode","to":"sticks"}` | Tap the mode switch button for that mode |

  A command answers `{"ok":true}` when finished, or `{"ok":false,"why":"…"}`. **Never** use `adb shell input` for anything that's filmed: those touches would have no touch markers and wouldn't look typed.
- Every frame is logged: `{"wall":…, "fingers":[{"id":…,"x":…,"y":…}]}`.
- The **human model** (`--human-model stats`, used only in Phase 4) adds imprecision, so the phone's real touch counters have something to count. All draws are seeded from `--seed`. Distances are in mm, converted with the AVD's dpi (420 for the phone, 320 for the tablet): `px = mm × dpi / 25.4`.
  - Each tap lands at its target plus a 2-D Gaussian offset with σ 2.5 mm, and σ 7 mm for 4% of taps ("sloppy").
  - During a hold longer than 300 ms, the finger drifts on a random walk of 0.4 mm per 100 ms. In 6% of holds it drifts 6 to 9 mm outward over 300 ms (to produce slide-offs).
  - After a tap that lands on no control, retap within 250 ms with σ 1.5 mm, 70% of the time. A burst of 4 quick taps on one spot happens in 1% of misses.
  - Stick fingers start where the intent's first vector points, plus σ 3 mm.
  - Mode differences: D-pad uses the base values. For Sticks with button size below 0.75, multiply σ by 1.3.
  - These numbers produce plausible counters, not real behaviour. That's why every stats caption says "scripted test sessions".

**Step D, gyro:**
- Open the emulator console with a TCP socket to `127.0.0.1:5554` and authenticate with `auth <token>` (token from `C:\Users\singh\.emulator_console_auth_token`).
- At 60 Hz, turn the intent's tilt `(x, y)` (each −1 to 1) into angles `roll = x × 35°`, `pitch = y × 35°`.
- Send `sensor set acceleration <ax>:<ay>:<az>` with gravity rotated by those angles (9.81 m/s²), and `sensor set gyroscope <gx>:<gy>:<gz>` with the angle change rate in rad/s.
- **Axes:** the app runs landscape, and the sensor axes follow the device's natural portrait orientation. Find the sign and axis mapping in the spike: tilt "right" must move the dot right in the tilt view.
- Log the angles in the touch log, for the 3D phone graphic.

Then: no unit tests for the injection itself. A test for the human model's maths in `tools/demo/test/` (run with `dart test tools/demo/test` if a pubspec is added; otherwise a `--self-test` flag that prints PASS or FAIL). Commit `demo: touch driver, layouts, gyro sensors`.

### 2.5 Builds for capture
Git Bash, from `$REPO`, on the `demo-video` branch:
```bash
cd $REPO/tv_test_app && flutter build windows --profile --dart-define=DEMO_DIRECTOR=true --dart-define=DEMO_LOG_DIR=C:/Users/singh/thumbparty-demo/logs
# Expect: build\windows\x64\runner\Profile\ThumbPartyTV.exe
cd $REPO/controller_app && flutter build apk --profile
# Expect: build\app\outputs\flutter-apk\app-profile.apk
```
Record the commit hash: `git -C $REPO rev-parse --short HEAD`. Every footage file is captured from builds of one commit; write it into `$WORK/edit/build.txt`.

### 2.6 OBS set-up (scripted, no GUI clicks)
1. Start OBS once, minimised, so it creates its config, then close it with the PID you recorded (step 2.7 starts it the same way):
   ```bash
   "/c/Program Files/obs-studio/bin/64bit/obs64.exe" --minimize-to-tray --disable-shutdown-check --multi &
   ```
   Wait 10 s, then `taskkill //PID <pid>`. Only that PID.
2. Write the obs-websocket config `C:\Users\singh\AppData\Roaming\obs-studio\plugin_config\obs-websocket\config.json` (back up any existing file to `$WORK/backup/` first):
   ```json
   {"alerts_enabled": false, "auth_required": true, "first_load": false, "server_enabled": true, "server_password": "<random 24 chars, saved to $WORK/backup/obs-password.txt>", "server_port": 4455}
   ```
3. In `tools/demo/obs.dart`, implement an obs-websocket v5 client: `dart:io` `WebSocket` and the challenge/salt SHA-256 authentication from the obs-websocket v5 spec. Use `dart:convert` and a small SHA-256 written in Dart, or `crypto` if it's already in the workspace lock file. Check with `grep -n "crypto" pubspec.lock`.
4. On first connect, create everything by request (idempotent: skip what exists):
   - Profile `ThumbPartyDemo` (`CreateProfile`, `SetCurrentProfile`).
   - `SetVideoSettings` base and output 1920×1080, 60/1.
   - `SetProfileParameter`:
     - `Output/Mode` = `Advanced`;
     - `AdvOut/RecEncoder` = `obs_qsv11` (Intel Quick Sync), falling back to `obs_x264` if QSV isn't listed;
     - `AdvOut/RecFormat2` = `mkv`;
     - `AdvOut/RecFilePath` = `C:\Users\singh\thumbparty-demo\footage`;
     - `AdvOut/RecRB` = `false`;
     - rate control CQP 18 for QSV, or CRF 16 for x264, through the encoder's settings.
   - Scene collection `ThumbPartyDemo` with:
     - scene `TV`: input `tv` of kind `window_capture`, window `Thumb Party TV:FLUTTER_RUNNER_WIN32_WINDOW:ThumbPartyTV.exe`, `capture_cursor` false, method Windows Graphics Capture;
     - an input `desktop_audio` of kind `wasapi_output_capture` (default device);
     - scenes `Terminal`, `Editor` and `Browser`: each one `window_capture` (Windows Graphics Capture, `capture_cursor` false) of that program's window: `WindowsTerminal.exe`, `Code.exe` and `msedge.exe`. They're for the 3.3 shots. **Don't capture the whole monitor**: window capture keeps the taskbar, notifications and any other window out of the footage. Set each source to scale to 1920×1080 in its scene (`SetSceneItemTransform`, bounds type `OBS_BOUNDS_SCALE_INNER`).
   - Confirm the exact window strings with `GetInputPropertiesListPropertyItems` for `window`: pick the item containing `ThumbPartyTV.exe` for `TV`, and the matching item for each 3.3 window once it's open. Window titles change, so match on the `.exe` part with the "match priority" setting `window_priority` = 2 (executable).
5. Test: start the profile TV app (2.7), record 10 s, stop, and check with ffprobe: 1920×1080, about 60 fps, an audio stream. Commit `demo: OBS control`. The password file is outside the repository; never commit it.

### 2.7 Showrunner (`tools/demo/showrunner.dart`)
One command runs one shot:
```bash
dart run tools/demo/showrunner.dart --shot G3 --take 2 --scene tools/demo/scenes/bigpiece.json --avd m7_android12 --mode sticks [--phone] [--tv] [--window Terminal|Editor|Browser]
```
It does these steps in order and stops at the first failure, with a clear message:
1. **TV app:** if not running from an earlier shot, start `tv_test_app\build\windows\x64\runner\Profile\ThumbPartyTV.exe` and record its PID in `$WORK/logs/pids.txt`. Wait until `ws://127.0.0.1:47900/director` answers `hello`. Send `reset`.
2. **Emulator** (when `--phone` or the scene has a P1 phone seat): if not running, start it as in 2.4 step A (port 5554 for the phone AVD, 5556 for the tablet AVD), then `adb root`. Install `app-profile.apk` if the installed version differs. Clear data (`adb shell pm clear com.thumbparty.app`), launch, start the touch driver, set the mode with its `mode` command, and pair:
   - **Filmed shots:** through the touch driver: `type` into `address` the text `10.0.2.2:<port>`, then `type` into `code` the 4-digit code, then `tap` Connect. This is how P2 and P4 look on screen.
   - **Unfilmed runs** (the stats sessions in Phase 4, and shots that start after pairing): `tools/emulator.sh connect 10.0.2.2:<port> <code>` (`ANDROID_SERIAL` set) is fine and faster.

   Wait for `P1` on the TV (director `state`).
3. **Bots:** send `bots` with the scene's count and wait for `bots_ready`.
4. **Recorders:**
   - with `--tv`, OBS `SetCurrentProgramScene TV`, then `StartRecord`;
   - with `--phone`, `scrcpy -s <serial> --no-window --record $WORK/footage/<shot>_take<N>_phone.mp4 --max-fps 60 --max-size 1200 --no-audio`;
   - with `--window <name>`, OBS scene `<name>`, then `StartRecord` (3.3 shots; the TV app must not be running, see 3.3).

   Write each recorder's wall-clock start to `$WORK/logs/<shot>_take<N>_recorders.json`.
5. **Touch driver:** already running from step 2. Point it at this take's log path, and at the scene's controller layout for play.
6. **Scene:** send `scene` and wait for `scene_done` (timeout = the scene's `pace` + 30 s).
7. **Stop:** after a 1.5 s tail, OBS `StopRecord` (rename the output to `<shot>_take<N>_tv.mkv`), then stop scrcpy (send it Ctrl+C through its process, or kill by PID) and the touch driver.
8. **Quality checks** (2.8). If they fail, the result is "retake". Retake the shot up to 3 times with the next take number, then stop and report.
9. Print one line: `G3 take 2: ok (tv 63.2 s, phone 63.0 s, events 41)`, or the failure.

Also a `--teardown` flag: stops OBS, scrcpy, the touch driver, the TV app and emulators **by recorded PID or serial only**, and restores nothing (preferences are prefixed, 2.1).

Commit `demo: showrunner`.

### 2.8 Automatic quality checks (`tools/demo/qa.dart`)
For each take:
1. **Format:** `ffprobe` gives 1920×1080 for TV and the expected size for phone, and `avg_frame_rate` ≥ 59 for TV and ≥ 50 for phone.
2. **Stutter:** decode with `ffmpeg -i <file> -vf mpdecimate=hi=64*12:lo=64*5:frac=0.33,showinfo -f null -`. Count dropped (duplicate) frames between `game_start` and `scene_end`. Fail if any run of 3 or more consecutive duplicates happens while the event log shows movement (any P1 or bot stick off-centre).
3. **Story:** the event log contains every event the storyboard needs for this shot:
   - G1: `scene_start`, then 4 joins, then `game_start`.
   - G2: at least 6 `snap` and 1 `wrong`.
   - G3: `help`, then `join_big`, then `snap` of the big piece.
   - G4: `pause`, then `resume`.
   - G5: `finish` (left), then `results`.
   - M1–M3: at least 15 s of movement.
   - R1: `screen` events home, then games, then puzzle list, then join.
4. **Contact sheet:** `ffmpeg -i <file> -vf "fps=2,scale=480:-1,tile=6x5" -frames:v 1 $WORK/qa/<take>_sheet.png`. Look at it (read the image): no debug overlay, no dialogs, correct player count, nothing cut off.
5. Write `$WORK/qa/<take>.json` with every result.

---

## Phase 3. Capture the footage

### 3.1 Before the first capture
1. Back up the owner's preferences: copy `%APPDATA%\Thumb Party\Thumb Party TV\shared_preferences.json` to `$WORK/backup/`. Don't modify the original.
2. Close nothing of the owner's. If a `ThumbPartyTV.exe` you didn't start is running, **STOP** and ask the owner to close it (ground rule 7).
3. Notifications: Windows has no supported command to turn on Do Not Disturb. **STOP** once and ask the owner to turn it on (Settings → System → Notifications → Do not disturb) for the capture sessions. This is a one-time PC setting, not a person in the video. The taskbar needs nothing: the TV app is borderless full screen.
4. Fresh demo state: the demo prefixed preferences start empty, so the TV shows the consent prompt on first launch. Capture X4 first (3.2), then the showrunner answers it ("Not now") through the director's `navigate`.

### 3.2 Shot order
Capture in this order, so state builds up naturally. Each line is one showrunner call. Retakes are automatic (2.7 step 8). Footage IDs match demo-video.md section 3.

| Order | Shot | Scene / action | Recorders |
| --- | --- | --- | --- |
| 1 | X4 | Launch fresh, consent prompt on screen 4 s, then navigate "Not now" | TV |
| 2 | P1 | Home screen with code, no controllers, 6 s | TV |
| 3 | P2 | Emulator launch, Connect screen, address and code typed by the touch driver at 180 to 260 ms per key, connected | TV and phone |
| 4 | P4 | Same as P2 on `m8_pixel_tablet` (stop the phone emulator first: one emulator at a time) | TV and tablet |
| 5 | P3 | Phone paired, then bots join one by one, 1.2 s apart | TV |
| 6 | M1, M2, M3 | `arena_dpad`, `arena_gyro`, `arena_sticks` | TV and phone |
| 7 | M4 | Tablet, Sticks, Arena 12 s | TV and tablet |
| 8 | R1, R2 | `menus.json` (home to Rocket, the labels change at `game_start`) | TV and phone |
| 9 | G1 | `join.json` | TV and phone |
| 10 | G2 and G5 | `race.json`: first **one** take with seed 4242, then **STOP** (below); after the owner's OK, 3 more takes with seeds 4243, 4244, 4245 | TV and phone |
| 11 | G3 | `bigpiece.json`, 3 takes | TV and phone |
| 12 | G4 | `pause.json` | TV and phone |
| 13 | C1–C3 | Phone Settings, all through touch-driver commands: `drag` the Button size slider from default to max to min (1.5 s each); `scroll` through the Gyro and Stick settings; `tap` the Floating sticks switch; `scroll` to and `tap` Help (puzzle) **Try** | Phone |
| 14 | C4 | `menus.json` second part: Puzzle settings, Time limit, Reset to defaults | TV and phone |
| 15 | X1 | Finish a solo puzzle through the director; the rating prompt appears; touch driver: `tap` the happy face, `tap` the "Rotation hard" tag, `tap` Done | Phone |
| 16 | X5 | Phone Diagnostics: `tap` to open it, then `scroll` through it, all with the touch driver | Phone |
| 17 | X2 | Latency screen during 30 s of Arena play by P1 | TV |

**First race take: STOP.** This is the shot the old video got wrong, so check it before capturing the rest.
- Send the owner the take's paths and contact sheet, its quality-check result (2.8), and a 15-second excerpt of the busiest part of the race (`ffmpeg -ss <start> -t 15 -i <tv take> -c copy $WORK/qa/G2_take1_excerpt.mkv`).
- Ask: "Is the movement smooth and the pace right?" If not, tune the director's steering (2.3: speed profile, noise, reaction delays) on the owner's notes, and retake.
- Continue only after an OK.

After all of these, run `--teardown`.

### 3.3 Terminal, editor and browser shots (after Phase 4, which they need)
**Before these shots:**
- Capture X3 first (4.4); it's the last shot that needs the TV app.
- Then **close the demo TV app by its recorded PID** (and any emulator, by serial). The TV app is borderless full screen and would cover every other window.

**How to record them:**
- Each shot records **one program's window** with OBS: the `Terminal`, `Editor` or `Browser` scene from 2.6, through `showrunner --window <name>`. Never the whole monitor.
- Before recording, open the program, maximise its window, and bring it to the front (`SetForegroundWindow`, as `tools/tv-window.ps1` does).
- A typing helper `tools/demo/typer.ps1` types into the focused window at 40 to 70 ms per character, through `keybd_event` (the method `tools/tv-window.ps1` already uses, because `SendKeys` failed on this PC).

**VS Code set-up**, once, before D2 and X7 (a fresh install, so set it up by file, not by clicking):
- Write `C:\Users\singh\AppData\Roaming\Code\User\settings.json` with: `"workbench.colorTheme": "Default Dark Modern"`, `"editor.fontSize": 18`, `"window.zoomLevel": 1`, `"editor.minimap.enabled": false`, `"workbench.startupEditor": "none"`, `"telemetry.telemetryLevel": "off"`, `"update.mode": "none"`, `"workbench.tips.enabled": false`, `"security.workspace.trust.enabled": false`, `"extensions.ignoreRecommendations": true`.
- Back up any existing file to `$WORK/backup/` first. This folder must be writable for the harness; if it isn't, **STOP** and ask.
- Open VS Code once without recording, close any welcome or notification pop-up (Escape), then close it.

**The shots** (`code` = `C:\Users\singh\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd`; `msedge` = `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`):
- **X6** (`Terminal`):
  - Open Windows Terminal: `wt.exe -d C:\Users\singh\game-controller\packages\metrics --title Report`, font size 16, dark theme.
  - Type `dart run metrics:report C:\Users\singh\thumbparty-demo\sessions`, then Enter. Wait for the output, hold 4 s.
  - Then type the same command with ` --csv C:\Users\singh\thumbparty-demo\charts\modes.csv`.
- **X7** (`Editor`):
  - Run `code --new-window C:\Users\singh\thumbparty-demo\sessions\<largest file>.json`.
  - Format the document (Shift+Alt+F), then scroll with PageDown every 0.8 s.
- **D1** (`Terminal`): `bash tools/check.sh` from `$REPO`, recorded until it finishes.
- **D2** (`Editor`):
  - Run `code --new-window C:\Users\singh\game-controller`, with the Explorer tree expanded for `controller_app`, `tv_test_app` and `packages/*`.
  - Open `docs/protocol.md` for 3 s, then `packages/connection/lib/src/latency.dart` for 3 s.
- **D3** (`Browser`):
  - Run `msedge --new-window --start-maximized https://github.com/devtestman187/game-controller/releases/tag/m11.3`.
  - Wait 4 s, then scroll with PageDown twice, 1.5 s apart.
  - Close only that window (by its PID).
- **D4:**
  - `Terminal`: a showrunner log scrolling (`tail -f $WORK/logs/<a showrunner log>` in Git Bash).
  - `Editor`: `code --new-window C:\Users\singh\game-controller\tools\demo\scenes\bigpiece.json`. Two separate recordings.

Close each program you opened (by PID) after its shot. Contact-sheet and review each, as in 2.8 step 4.

### 3.4 Review gate
**STOP.** Send the owner the contact sheets of every chosen take (the paths in `$WORK/qa/`) and a short list: shot, take used, length, problems. Wait for OK, or for retake requests.

---

## Phase 4. Scripted stats sessions

**Needs:** the m11.3 commit (idle fix) in both builds from 2.5.

### 4.1 Plan
| Device (AVD) | Modes | Sessions per mode | Game per session | Settings variants |
| --- | --- | --- | --- | --- |
| `m7_android12` (phone) | D-pad, Gyro, Sticks | 4 | 2 solo Shape Race rounds (random Easy puzzle) + 1 Arena session of 90 s | Sticks: button size 0.75 in sessions 1–2, 0.60 in 3–4; floating off in 1 and 3, on in 2 and 4 |
| `m8_pixel_tablet` | D-pad, Gyro, Sticks | 2 | the same | default settings |

That makes 18 sessions of about 5 minutes of play each. With the 150 s wait between sessions and emulator start-ups, that's about 2.5 hours of unattended running. Every session uses `--human-model stats` with seed `1000 + session number`.

### 4.2 Session procedure (one showrunner mode: `--stats-session <n>`)
1. Start the TV demo build, if it isn't running.
2. Start the AVD for the session, clear the app's data, launch, set the mode and the session's settings through the touch driver. Pair.
3. **Director:** a scene `stats_solo.json`: Play, Shape Race, Any Easy puzzle, solo (P1 joins alone), complete the puzzle, Rematch once, then back to Arena for 90 s, then quit.
   - On the rating prompt: the face is chosen by a seeded draw: good 60%, okay 30%, bad 10%.
   - Tags: one random tag in 30% of cases.
   - Skip in 20% of prompts (the prompt only appears every few games, as in the app).
4. Leave 20 s with no input during the session, at a random point, so active time differs from open time.
5. Force-stop the phone app (`adb shell am force-stop com.thumbparty.app`) and wait **150 s** (the TV ends a session after 2 minutes with nobody connected). Confirm a new file appeared in `%APPDATA%\Thumb Party\Thumb Party TV\sessions-demo\`.
6. Log `stats_session_<n>: ok, file <name>`.

Run all 18 in a loop. Recorders are off (no footage). One emulator at a time: finish the phone sessions, stop that emulator, then start the tablet.

### 4.3 Dataset
1. Copy every file from `%APPDATA%\Thumb Party\Thumb Party TV\sessions-demo\` to `$WORK/sessions/`.
2. `cd $REPO/packages/metrics && dart run metrics:report $WORK/sessions --csv $WORK/charts/modes.csv`.

   Expect: "18 sessions", three mode rows, and device rows for phone and tablet. The `minutes` column (active) is lower than `open min`.
3. Sanity rules. If any fails, **STOP** and report:
   - every mode has at least 10 active minutes;
   - every mode has non-zero empty taps and near misses;
   - Sticks has slide-offs;
   - the input delay column is filled.
4. Save the report text to `$WORK/charts/report.txt`.

### 4.4 Load the dataset into the Stats screen shot
The demo build's Stats screen reads `sessions-demo`, which is this dataset. Capture **X3** now with the showrunner: the Stats screen, scrolled through the per-mode rows, then Export. Then capture **X6** and **X7** (3.3).

---

## Phase 5. Graphics, audio and edit

All graphics are rendered by Python scripts in `tools/demo/graphics/`, run as `$WORK/venv/Scripts/python.exe -I tools/demo/graphics/<name>.py`, writing to `$WORK/graphics/` or `$WORK/charts/`.
- **Style:** background `#12161C`; text `#FFFFFF` and `#AAB2BD`; player colours from `packages/protocol` (`playerColors`); font Segoe UI Semibold (`C:\Windows\Fonts\seguisb.ttf`) and Segoe UI (`segoeui.ttf`).
- **Animated pieces** are PNG sequences at 60 fps.

### 5.1 Graphics list
| Script | Output | Details |
| --- | --- | --- |
| `title.py` | `title_%04d.png` (4 s) | The logo from `assets/branding/` (the largest icon PNG) and "Thumb Party" fade in over 0.3 s; "Your phone is the controller." 0.3 s later; the small disclosure line "Recorded from the real apps. Every player is a script." |
| `caption.py` | `cap_<id>.png` per caption | Every caption from demo-video.md section 4. Bold 54 px on line 1, 34 px on line 2, left at x=96, baseline y=930, on a 0 to 70% black gradient from y=760 down. A JSON list of captions is the input |
| `latency_diagram.py` | `latency_%04d.png` (6 s) | Two lanes (TV at y=420, phone at y=660). Arrows animate in order: ping t0 at 0.3 s, pong t1 at 1.3 s, arrival t2 at 2.3 s. The formula `offset = t1 − (t0 + t2) / 2` appears at 3.3 s; "input.ts → one-way delay" at 4.5 s |
| `heatmap.py` | `heatmap_<mode>.png` | For each mode, sum the sessions' `empty` cell counts (the 6 by 3 grid, keys `"col,row"`). Draw the controller layout from `tools/demo/layouts/m7_android12-<mode>.json` as outlined shapes, then the grid cells coloured by count (sequential palette from `#12161C` to `#FF7A45`) at 70% opacity. Title "Where taps missed: <Mode>"; source line "Scripted test sessions · N sessions · 2 emulated devices · Nov 2026" |
| `mode_bars.py` | `mode_bars.png` | From `modes.csv`: grouped bars per mode for empty, near-miss and slide-off taps per active minute, plus a stacked bar of ratings (good, okay, bad). Same source line |
| `stat_card.py` | `stat_latency.png` | "Median N ms" with N = the `input ms` value of the "By input mode" table in `report.txt` (median of the three rows). Line 2 "Target: under 50 ms". Source line "Emulator on the same PC, scripted sessions". **Not** a Wi-Fi number; there is no real-device data in this plan |
| `haptic.py` | `bzz_%04d.png` (0.8 s) | Three rings expanding from the centre, with "bzz" and the event name |
| `phone3d.py` | `tilt_%04d.png` | A simple phone rectangle in perspective, rotated by the logged roll and pitch from the M2 touch log, frame by frame |
| `touch_markers.py` | `markers_<take>_%04d.png` | For each phone shot, transparent frames with 48 px circles in P1 blue at 60% opacity for every finger in the touch log, plus a 150 ms fading trail. Timed to the phone video by `recorders.json` |
| `cards.py` | `name_card.png`, `end_card.png` | Name card with "Built by <name>" and the role, from `tools/demo/credits.json`, made only when `name` is non-empty (see the defaults table at the end); end card with the logo, `devtestman187.github.io/game-controller`, `github.com/devtestman187/game-controller`, and the text "Google Play · TestFlight · Windows". No store badge images, to avoid trademark terms |
| `frames.py` | `phone_frame.png`, `tablet_frame.png` | Plain rounded rectangles, `#2A3038`, corner radius 48 px |

### 5.2 Audio
- **Music bed:** `lobby.ogg` from the Bubble Pop folder (project-generated, CC0; 19.20 s, made to loop without a gap). Loop it to the video length with `ffmpeg -stream_loop -1 -i lobby.ogg -t <length> -c:a pcm_s16le $WORK/audio/music.wav`.
  - Volume: −20 dB under gameplay, −14 dB under the title and end cards, −24 dB under the metrics section. Fade out over the last 2 s.
  - Add a row to a `CREDITS.txt` in `$WORK/renders/`.
- **Game audio:** the TV recordings' audio tracks, kept at their level.
- **Haptic "bzz":** `rumble.ogg` (Bubble Pop) at −10 dB, 0.3 s, on each haptic graphic.
- **Voice-over:** none, unless the owner decides otherwise (see Questions).
- **Loudness:** final mix to −14 LUFS integrated with `ffmpeg … -af loudnorm=I=-14:TP=-1.5:LRA=11` in two passes.

### 5.3 Edit decision list
Write `$WORK/edit/edl.json`: one entry per storyboard row of demo-video.md section 5, in order:
```json
{"n": 19, "dur": 2.0, "layout": "SPLIT", "tv": {"file": "G2_take3_tv.mkv", "in": "event:snap#1-0.8"},
 "phone": {"file": "G2_take3_phone.mp4", "sync": "game_start"}, "zoom": {"scale": 1.5, "center": "board:left"},
 "caption": "cap_19", "markers": true, "audio": ["tv"]}
```
- **Times:** `in` may be absolute seconds or `event:<name>#<k>±<s>`, resolved from the take's event log and `recorders.json`.
- **Phone sync:** the phone's offset to the TV is set by the frame where the phone's buttons relabel. That's the largest frame difference within ±2 s of `game_start` in the phone video, found with ffmpeg `select='gt(scene,0.2)'`. For menu shots, use the recorders' start times.
- **Layouts** (pixels in a 1920×1080 frame):
  - FULL: TV at 0,0, 1920×1080.
  - SPLIT: TV scaled to 1248×702 at x=48, y=189; phone frame at x=1336, y=300, with the phone video scaled to 536×241 inside it (tablet: 536×335).
  - PIP: TV full, inset 760×342 at x=1112, y=690.
  - QUAD: four 944×531 tiles with 16 px gaps.
  - Zoom: crop the TV video around the named board's centre (from the event log's board rectangles, or the puzzle's `SplitLayout` boxes) and scale back to the layout size.
- **Pace rules from demo-video.md section 2** (checked by `edit.py`): no gameplay speed above 1.5×, no gameplay shot over 4 s without an event inside, 60 fps.

### 5.4 Render
`tools/demo/graphics/edit.py` reads `edl.json` and builds each shot with ffmpeg:
- `-filter_complex` with `scale`, `crop`, `overlay` for frames, markers and captions, and `fade` on captions at 0.2 s;
- encode `libx264 -preset slow -crf 16 -pix_fmt yuv420p -r 60`, audio AAC 48 kHz.

Then concatenate the shots (concat demuxer), mix the music (5.2), apply loudnorm, and write `$WORK/renders/thumb-party-demo-master.mp4`.

### 5.5 Cutdowns
`edit.py --cut recruiter|sizzle|vertical|pairing` builds each cut from the same EDL, with the shot lists in demo-video.md section 7.
- **In scope now:** the master (5.4) and `--cut recruiter` → `thumb-party-demo-60s.mp4`.
- **Later, only if the owner asks:** `sizzle`, `vertical` and `pairing` (`-45s.mp4`, `-vertical.mp4`, `-pairing.mp4`). Build `edit.py` so they work, but don't render them.
- Vertical (1080×1920): phone video scaled to 1080 wide, centred at y=1000; TV tile 1080×608 at y=120; captions at y=1650.
- **Preview copies:** after the final checks, copy the master and the 60 s cut to the harness's own workspace for preview. The originals stay in `$WORK/renders/`.

### 5.6 Final checks
1. `ffprobe` on each render: the expected size, 60 fps, AAC, length within ±1 s of the plan.
2. Loudness: `ffmpeg -i <render> -af ebur128 -f null -` gives an integrated level of −14 ±1 LUFS.
3. Contact sheet of each render at one frame per second (`$WORK/qa/render_<cut>_sheet.png`). Read it: captions readable, nothing overlapping scores, no debug UI, the disclosure line present.
4. Number audit: list every number shown on screen and its source (report.txt row, Latency screen, `tools/check.sh` output for the test count, `git tag | wc -l` for tags). Write it to `$WORK/qa/numbers.md`.
5. Claims audit: nothing from demo-video.md section 4's "Claims to keep accurate" is broken. In particular, no "finds your TV automatically", no phone-only hosting, no M13 features.
6. **STOP.** Send the owner the render paths, the contact sheets, `numbers.md`, and a list of any storyboard shot that couldn't be filled (with the reason). Don't substitute footage.

### 5.7 Clean-up
1. Run `showrunner --teardown`. Check that no process you started is left (the PIDs in `pids.txt`).
2. Compare the owner's `shared_preferences.json` with the backup: it must be unchanged.
3. Commit the tooling changes made since the last commit: `demo: graphics and edit scripts`. Never commit `$WORK`.
4. In `docs/project-notes.md` "Open items", add one line: the demo pipeline exists (`tools/demo/`, runbook `docs/demo-video-runbook.md`) and where the renders are.

---

## Appendix A. m11.3 design (reference only; already done before this runbook)

Kept so the agent understands the `activeMs` and `open_minutes` fields it relies on. **Don't execute these steps.**

### A.1 Sounds (follow `INSTALL.md` §1 to §3 exactly)
1. Copy **only** these ten files from `C:\Users\singh\Documents\deepseek-harness\default-workspace\thumb-party-audio\final\palette-b-bubble-pop\` to `assets\audio\`, overwriting: `hit.ogg success.ogg error.ogg rumble.ogg snap.ogg wrong.ogg tick.ogg pickup.ogg time_up.ogg help.ogg`. **Don't copy** `lobby.ogg`, `countdown.ogg` or `player_joined.ogg`.
   ```bash
   SRC="/c/Users/singh/Documents/deepseek-harness/default-workspace/thumb-party-audio/final/palette-b-bubble-pop"
   for n in hit success error rumble snap wrong tick pickup time_up help; do cp "$SRC/$n.ogg" "$REPO/assets/audio/$n.ogg"; done
   ls "$REPO/assets/audio"   # Expect exactly the ten names, .ogg
   ```
2. In `assets/CREDITS.md`, replace the ten existing `audio/*.ogg` rows with the ten rows in `INSTALL.md` §2. Keep the table's other rows and the rest of the file unchanged.
3. Add the generator to the repository: copy `thumb-party-audio\render.py` to `tools/audio/render.py`. Add a 3-line header comment saying it needs `numpy`, writes WAV masters, and that the shipping `.ogg` files are encoded with the ffmpeg command in INSTALL.md §4. Also copy `INSTALL.md` §4 (the encode and duration-check commands) into `tools/audio/README.md`.
4. Delete the untracked `kenney-audio/` folder at the repository root. It's unused; the old sounds came from it. Check first with `git status --short kenney-audio` (expect `??`).
5. Check durations (Git Bash), comparing each with the table in `thumb-party-audio\README.md`:
   ```bash
   cd $REPO/assets/audio
   for n in tick pickup snap error hit wrong help rumble success time_up; do printf "%-8s " $n; ffprobe -v error -show_entries format=duration -of csv=p=0 $n.ogg; done
   ```
6. Screen check: `tools/tv-dev.sh start` (Git Bash). Expect the TV home screen line **"10 of 10 event sounds loaded"**. Read it with `powershell -ExecutionPolicy Bypass -File tools/tv-window.ps1` (see dev-tools.md for its screenshot command) and look at the image. Then `tools/tv-dev.sh stop`.

### A.2 Idle-time fix: design (implement exactly this)
**Problem:** a mode segment's time (`ms`) runs from the moment the mode starts. Idle time with the app open (phone on the table) inflates the minutes and shrinks every per-minute rate. Oct 31 export: Sticks at 206.9 minutes and 0.2 presses a minute.

**Rule: active time.** A segment's active time counts only the time near player activity.
- **Activity events:**
  - `touchDown`;
  - any change in `held` (a press or a release);
  - `stick` with `touched: true`;
  - `tilt` where the new value differs from the tilt at the previous *activity* by at least `Thresholds.tiltActivity = 0.05` on x or y.
- **Busy:** at least one control is held, or a stick is touched.
- **Counting:** between two moments `a < b` where nothing changed, add:
  - all of `b - a` if busy during it;
  - otherwise `min(b - a, Thresholds.idleGapMs)` if there was an activity event at `a`, with `idleGapMs = 5000`. Five seconds after the last input still counts as playing: looking at the TV, thinking.
  - otherwise `0`.
- The segment starts **inactive**. Time before the first activity counts 0.

**Changes:**
1. `packages/metrics/lib/src/segment.dart`:
   - Add `static const idleGapMs = 5000;` and `static const tiltActivity = 0.05;` to `Thresholds`, with doc comments.
   - Add to `SegmentRecorder`: `int _activeMs = 0; int? _lastActivityMs; bool _busy = false; double? _lastTiltX, _lastTiltY;` and a private `_activity(int atMs)`. It adds the interval since `_lastActivityMs` by the rule above, then sets `_lastActivityMs = atMs`.
   - Call `_activity` from `touchDown`, `held` (before updating `_held`, then recompute `_busy`), `stick` (when touched, and also on the release that ends a touch, then recompute `_busy`) and `tilt` (only when past `tiltActivity`).
   - Add `int activeMs(int atMs)`: `_activeMs` plus the pending interval up to `atMs` by the same rule, without changing state.
   - In `toJson(atMs)`, add `'activeMs': activeMs(atMs)` right after `'touches'`.
   - In `sanitizeSegmentData`, add `if (n(data['activeMs']) case final a?) 'activeMs': a` to the base map. Older phones simply have no key.
2. `packages/metrics/lib/src/session.dart`, in `summary()`:
   - For each segment, active = `s.data['activeMs']` if it's a number, else `s.durationMs` (older phones).
   - Add `modeActiveMs[m]` summed like `modeMs`.
   - In `'modes'`, add `'activeMs': modeActiveMs[m] ?? 0` next to `'ms'`.
   - Keep `'ms'` unchanged.
   - In each segment's entry, add `'activeMs'` next to `'ms'` (same fallback).
3. `packages/metrics/lib/src/report.dart`:
   - Add `final int activeMs;` to `ModeRow`, read from `modes[mode]['activeMs']` with fallback to `ms`.
   - Rename the getter `minutes` to `openMinutes` (from `ms`), and add `minutes` (from `activeMs`).
   - `frustrationPerMin` and every per-minute figure use `minutes` (active).
   - In the group table, the column `minutes` shows the summed active minutes. Add a column `open min` right after it with the summed open minutes.
   - In the CSV, keep every existing column in place and append `open_minutes` at the end of the header and of each row. The `minutes` column now means active minutes.
   - The early-switch rule keeps using `ms` (time since the mode started), unchanged.
4. `tv_test_app/lib/src/ui/stats_screen.dart` uses `ModeRow`, so per-mode figures follow automatically. Check every place it shows minutes per mode: they must show active minutes. The session line ("N min · …", from `durationS`) stays wall time.
5. `docs/protocol.md` §(metrics `data`, the paragraph starting "`data` (defined in `packages/metrics`"): add `activeMs` (time near player activity: inputs, plus up to 5 s after the last one, and all of any hold) after `touches`. Add one sentence: hosts and the report fall back to `ms` when it's missing.
6. `docs/architecture.md`, "Milestone 9" section: one bullet "Active time (m11.3)" summarising the rule.
7. **Tests** in `packages/metrics/test/metrics_test.dart`, in a new `group('active time', …)` modelled on the existing `SegmentRecorder` tests:
   - (a) No input for 60 s gives activeMs 0.
   - (b) One tap at t=1000, read at t=60000, gives 5000.
   - (c) Taps at 1000 and 3000, read at 60000, gives 2000 + 5000 = 7000.
   - (d) Hold `a` from 1000 to 21000, read at 21000, gives 20000; read at 40000 gives 25000.
   - (e) Stick touched from 0 to 30000 with updates every 100 ms, read at 30000, gives 30000.
   - (f) Tilt changes under 0.05 every 100 ms for 60 s gives 0.
   - (g) Tilt steps of 0.1 every 1000 ms for 10 s (from t=0), read at 10000, gives 10000.
   - (h) `toJson` contains `activeMs`, and `sanitizeSegmentData` keeps it and drops a negative one.
   - (i) `summary()` sums `activeMs` per mode and falls back to `ms` for a segment without it.
   - (j) The report's `minutes` uses active time, `openMinutes` the old time, and the CSV header ends with `,open_minutes`.
8. Run `tools/check.sh`. Expect every line ok.

### A.3 Release prep
1. Versions stay **0.11.0** (point releases keep the version; `release.sh` checks that both `pubspec.yaml` files and both `app_info.dart` files agree).
2. Add an "m11.3" section at the end of `docs/checklists/m11.md`, in the same style as its other sections:
   - (a) The TV home screen says "10 of 10 event sounds loaded".
   - (b) The Haptic test plays the new Hit, Success, Error and Rumble.
   - (c) A Shape Race round plays the new pickup, wrong, snap, tick, time-up and help.
   - (d) After 5 minutes with the phone connected and untouched, then 1 minute of play, the Stats screen shows about 1 minute for that mode, not 6.
   - (e) Stats export plus `metrics:report` shows the `open min` column.
3. In `docs/project-notes.md` "Open items": remove the m11.3 item and the "time in a mode counts idle time" idea, and add one line saying m11.3 shipped both (with the date). Update `README.md`'s status row for M11 if it mentions m11.x.
4. Commit (one commit): `m11.3: Bubble Pop sounds; stats count active time only`. End the message with the attribution lines the environment provides, if any.
5. `git push origin main`.
6. **STOP.** Tell the owner the commit is pushed and propose tester notes (500 characters or fewer):
   > "New sounds: every game sound is replaced with the brighter "Bubble Pop" set. Stats now count only the time you're actually playing, so per-minute numbers are no longer diluted by time the app sat open. To test: listen to a Shape Race round and the Haptic test; leave the phone idle for 5 minutes, play 1 minute, and check Stats shows about 1 minute."

   Wait for "tag m11.3".
7. Run `tools/release.sh m11.3 "<the approved notes>" --yes` in the background (Git Bash; it waits for the Play, TestFlight and Windows builds). Report the tag, the GitHub Release link and each build's result.
8. **STOP** for the owner's device check of the m11.3 checklist section. Phase 2 may start in parallel. Phase 4 (stats sessions) must use the m11.3 code.

---

## Questions the owner has already answered
- Stats source: **scripted sessions** (Phase 4), always captioned "scripted test sessions".
- m11.3 (the Bubble Pop sounds and the idle-time fix, one release) is released before this runbook starts.
- Captions only, no voice-over.
- Music: `lobby.ogg`, looped.
- The runbook is run by the owner's DeepSeek harness. It works only on the `demo-video` branch and never releases.
- No humans in any footage. No AI-generated footage of the product or people.

## Defaults used until the owner says otherwise
| Topic | Default in this runbook |
| --- | --- |
| iPhone and iPad footage | None. TestFlight is mentioned in text only |
| Name card (storyboard shot 45) | "Built by Manveer Wasson". Create `tools/demo/credits.json` in Phase 2 as `{"name": "Manveer Wasson", "role": ""}`. Show the role line only if the owner fills in `role`; never invent one |
| Headline latency | The emulator number, captioned as such (no Wi-Fi claim) |
