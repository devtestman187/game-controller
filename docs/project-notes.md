# Project notes

How this project is run, what's still open, and the lessons learned along the way. It's the shared, backed-up copy of the working notes Claude Code keeps between sessions. The milestone status table is in the [README](../README.md#status); requirements are in [PRD-v2.md](PRD-v2.md); each milestone's tests and results are in [checklists/](checklists).

## How we work

- **One milestone at a time.** Claude builds a milestone from the PRD, commits and pushes it, writes its device tests into `docs/checklists/mN.md`, then stops. The next milestone starts only when the owner has run the device tests and says so ("Record M9 as done", "start M10"). "Continue" alone doesn't count as confirmation.
- **Tags only on the owner's word.** A tag publishes builds to Play, TestFlight and a public GitHub Release, so Claude tags only when asked ("tag m10.1"). Fixes found in device testing go out as point releases (`m10.1`, `m10.2`).
- **Every release has tester notes.** The tag's message is the notes, in plain words for testers ("Shape Race: the right stick now turns pieces…"), never empty; even "Minor update for testing" is fine. They go to Play "What's new", TestFlight "What to Test" and the GitHub Release.
- **Device feedback becomes a recorded change.** When a device test finds a problem, the fix is written into the PRD and the milestone's checklist ("Changes from device testing"), with the tester's words quoted.
- **Android testing is on hold.** Android phone and tablet checks stay marked *pending*, not skipped. The Android TV and Windows checks go ahead.
- **Use the scripts and helper agents.** `tools/check.sh` before committing code (through the `test-runner` agent in Claude Code), `tools/release.sh` to release (Claude runs it itself, in the background, only after the owner approves the tag, e.g. "tag m11.2"; the `release-checker` agent is kept for when it's asked for by name: as a separate agent it cost more and drew Claude Code's "Blind Apply" security flag), `tools/flash.sh` for the flash-worker's jobs (below), and `tools/tv-dev.sh` and `tools/emulator.sh` for hands-on checks ([dev-tools.md](dev-tools.md)).
- **Claude orchestrates; the flash-worker writes the code** (owner, Nov 6, 2026: "I want you to function more as an orchestrator, architect and designer. Let flash-worker take more of a load."). It runs on DeepSeek Flash, outside the Claude subscription, through `tools/flash.sh` (run directly, in the background).
  - *Claude:* milestone scope and design (`docs/design/mN.md`), contracts (public types, signatures, doc comments, message formats), briefs with test cases, every review, every PRD edit, commits, pushes and releases. Claude writes code itself only as a last resort (see *Failures*) and for one-line fixes.
  - *Flash-worker:* everything else, protocol, connection and platform code included (owner, Nov 6: "Let flash worker implement. But you perform code reviews at set stages"). It follows [coding-guidelines.md](coding-guidelines.md) on every job.
  - *Source of truth:* Claude. The worker may suggest or ask in its report; nothing it suggests is done until Claude approves it in a later brief.
  - *Review gates:* larger jobs are split at gates (G1 plan, G2 contract and tests, G3 first slice, G4 complete; [design/m12.md](design/m12.md#5a-review-gates)). The worker stops at the gate its brief names. The next job starts only after Claude has reviewed the diff and the checks and written the corrections into the next brief (owner, Nov 6: "Only on your approval and implementation of suggestions should it continue"). Gates follow risk: protocol, connection or new design get every gate; pure moves and cleanups go straight to G4. A split gets a G1 plan when the worker designs it; when Claude's brief gives the move map, it goes straight to G4, with `tools/review.sh --strings` and unchanged test counts as the proof.
  - *Survey first (G0):* before Claude writes a contract, a read-only job answers Claude's questions about the code with file:line facts, sizes and conflicts ([briefs/templates/survey.md](briefs/templates/survey.md)). Claude designs from the survey instead of reading the code.
  - *Briefs:* one complete spec per job ([briefs/templates/job.md](briefs/templates/job.md)): the gate, the files (`allow:`), the contract, the behaviour and edge cases from the PRD, the test cases as rules with expected values, and the checks (`check:`). `tools/flash.sh --brief <file>` reads those header lines. No back and forth inside a job.
  - *Bugs from device testing* (owner, Nov 7: "reduce your usage for unnecessary things"): (1) the owner pastes the report and logs in chat (a short "did / expected / happened" is enough); (2) Claude writes a triage brief ([briefs/templates/triage.md](briefs/templates/triage.md)) quoting only the log lines that matter, never the whole log, and naming the area of code; (3) the read-only triage job returns, per bug, the cause with file:line, its confidence, the fix and the failing test; (4) Claude checks it against the code, asks the owner what only the owner knows, and writes the fix brief; (5) the worker writes the failing test first, then the fix; (6) the owner confirms on the next build, and the fix goes into the checklist's "Changes from device testing" with the owner's words. A bug whose cause is plain from the report skips triage. Later: a folder the phone can save to that syncs to this PC, so big logs reach the worker without passing through Claude.
  - *Failures:* up to 3 tries per job, each a fresh brief saying what was wrong. Then Claude splits the job smaller and sends it again; Claude writes it only if that fails too, and notes it here.
  - *Review by risk:* first a read-only review job runs the checklist over the diff ([briefs/templates/review.md](briefs/templates/review.md)), with `tools/review.sh` and its `--strings` check; Claude then checks its findings and reads the risky code itself. Contracts, protocol, connection, security and platform code: the whole diff. Screens and game logic: the review job's findings, `/code-review` and the tests. Docs, data and ticks: the file list and the checks. Claude trusts the diff, not the worker's summary.
  - *Paperwork:* each job's report ends with a draft commit message, a STATUS row and the files to delete; `flash.sh` deletes the listed files that are inside `allow:`. Claude approves and commits.
  - *Parallel jobs:* each job runs in a worktree of its own (`flash.sh` makes it and applies the changes back), so Claude can work while it runs, and jobs on separate files can run at once.
  - *Measuring:* `tools/flash.sh` logs each job's tokens to `~/.thumbparty/flash-usage.tsv`; compare with Claude Code's `/usage` after each step. The aim is the worker writing 80% or more of the lines.
  - *Privacy:* briefs, designs and contracts may go to DeepSeek (owner, Nov 6; the repository is public). Secrets and the owner's private files never do.

### Never commit

- The owner's local backups `docs/PRD - Copy.md`, `docs/PRD-old.md`, `docs/PRD-old-2.md`, and the `kenney-audio/` source folder. They're untracked on purpose. Stage files by name (`git add path/to/file`), never `git add -A` or a whole folder, and check `git status` before committing.
- Real Firebase values in the docs: [release.md](release.md) keeps placeholders. The real ones are GitHub variables.
- Secrets of any kind. They live in GitHub secrets, Codemagic and the Play upload key folder ([dev-tools.md](dev-tools.md#moving-development-to-another-computer)).

## Current work

- **M12 (phone-hosted play) started Nov 6, 2026** on branch `m12`, from the design in [design/m12.md](design/m12.md). The owner chose to start it before running the M11 device tests ("Start M12 work carry over M11 open items as tech debt").
- **`demo-video` is frozen** (owner, Nov 6): no more commits and no merge into `main`. Its demo-director code stays on that branch only.

## Tech debt

Carried into M12, not blocking it:
- **M11 device tests** ([checklists/m11.md](checklists/m11.md)): 13 of 18 items open, and all 8 of PRD v2's M11 acceptance tests, including the m11.3 checks (Bubble Pop sounds, active play time). M12's device tests repeat the M11 checks phone hosting touches (join, pause, results, 4 players).
- **The `docs/protocol.md` read-through**, best done once M12's `view` messages are in.

Found by `tools/review.sh --all` (Nov 6, 2026) and **cleared the same day** by cleanup jobs c1, c1b, c2 and c3 (owner: "Start the cleanup"; briefs `docs/briefs/m12/c*-g4.md`): `game_host.dart` split into five files; real waits gone from the connection tests, and the "nothing was sent" checks now read the wire; the phone app's providers and widget tests split; the long screen members split into named widgets; the puzzle's `Random` required; the two empty catches explained or counted.

Left for later:
- `connection/test/m9_test.dart:37` ("a host never sends a message the controller did not list") checks `host.send` results only; the wire check c1b added (`test/wire_phone.dart`) would fit it.
- `tools/review.sh` reads a `labels: {` map entry as a member (a FAIL in `puzzle_game/lib/src/play_view.dart`), and `play_view.dart`'s `_tick` is 61 lines.
- `docs/dev-tools.md` is 400 lines: the DeepSeek Flash part (about 60 lines) could be a doc of its own. Its `smoke.sh` sample output is hand-written; replace it with a real run.
- Extracted widgets go in plain sibling files from now on, not `part` files (c3 used `part` for three host screens; fine as it is).
- `connection`: `host_connection.dart` is 394 lines, `controller_client.dart` and `host_server.dart` 379 (after s3a split controller_client from 400). Split whichever one a step next adds to, before adding; `client_messages.dart`'s `onData` is 46 lines, one case per message type.
- **Game rules files over the 400 hard limit** (the only `review.sh` FAILs): `test_game/lib/src/arena.dart` 487 (695 before s3b moved the snapshot out), `puzzle_game/lib/src/game.dart` 732, `puzzle_game/lib/src/view.dart` 439. s3b keeps them from growing; splitting the rules is a cleanup job of its own (pure moves, as c1–c3).
- **`tools/review.sh`** is 399 lines with a 76-line `--strings` branch: move that branch into its own function or script.
- **UI spacing:** paddings and sizes are bare numbers (most of the script's `number` notes). A small spacing scale for the host and phone apps belongs with the look-and-sound milestone, which restyles the same screens.

Broken on this PC, left for later (owner, Nov 6: "log what's broken here and move on"). None of them can make `tools/smoke.sh` pass wrongly:
- **The emulator's window crashes at start** (both AVDs, every GPU mode). Smoke runs it headless, so its results are unaffected; you can't watch the phone live or record from the window. Try: update or reinstall the emulator in Android Studio's SDK Manager. Details under "The Android 12 emulator" below.
- **The Flutter tool crashes on temp folders when Claude runs `flutter run`** (sandbox on or off; maybe because the Claude app is packaged). The TV app keeps running and hosting; only its log goes quiet. So smoke proves steps from the controller's side only, retries the TV start once (both failing is a false failure), and Claude can't hot-reload or read the TV log, or test TV sounds. Not yet tried from the owner's own terminal: if it works there, one owner run restores the TV-side checks.
- **Smoke's phone-hello step is skipped** while the TV log is quiet. The phone's player badge already proves the TV took its hello; what's unchecked is that the TV read the phone's details (platform, version) right.

Not debt (checked Nov 6): the `debugPrint` in both `logProvider`s copies log lines to the console in debug builds only, and the `print`s in `tv_test_app/integration_test/sound_test.dart` are that on-device test's output.

## Open items

Carried from earlier milestones, still to do:
- **Android checks** (on hold): the v1 Android phone tests, the M7 tablet tests, the M8 Android install by another person, the Android TV rename and pairing checks, the Play-installed TV app with store phones, and the TV launcher banner.
- **Public TestFlight link:** https://testflight.apple.com/join/afaU2DHU (owner, Nov 7, 2026), in the tester guide (`site/index.html`). The external group is `Testers`. **Owner's decision, Nov 7: builds go to internal testing first; never send them to `Testers` automatically.** After each release, ask the owner whether to promote the build to external testing, and promote only on a yes (docs/release.md, "Each release", step 5). `codemagic.yaml` keeps no `beta_groups`.
- **Phone screenshots** for the stores show the PC's old name in the connection chip. Retake them after the PC is renamed: build the Windows TV app, pair the `m7_android12` emulator, capture at 2400×1080 and pad to 2400×1200 (`assets/branding/screenshots/`).
- **M10 extra checks** kept for later ([checklists/m10.md](checklists/m10.md)): old with new, Puzzle settings with the remote, Stats export, and the three optional checks carried from M9.
- **m11.3** (built): the "Bubble Pop" sounds (`tools/audio/`) and stats that count active play time only (`activeMs`). Device checks in [checklists/m11.md](checklists/m11.md) ("m11.3 checks"). The untracked `kenney-audio/` folder at the repository root is no longer needed; the owner decides whether to delete it.
- **Look-and-sound milestone, planned between M12 and M13** (owner still thinking; not in the PRD yet): brighter colours, Canvas outlines and shadows, then the "Toy Box Toon" shader (Arena first), the 3 extra sounds with looping, and a mute or volume setting. Source: the DeepSeek workspace's `game-controller-shaders/DESIGN.md` and `thumb-party-audio/`.
- **Party ideas** (owner still thinking; not in the PRD): chaos events with a cat, power-ups, points, party nights with end-of-night awards, and on-device leaderboards. Written down in [party-ideas.md](party-ideas.md).
- **Potential enhancements** (owner, Nov 7, 2026: "Don't act on these yet"; not in the PRD, not in priority order): internet play (invites first, open games later), more TV platforms, games streamed from the phone to the TV, more game types, and controller modes per game. Written down in [enhancements.md](enhancements.md).

## Testing recipes

The scripts and their safety rules are in [dev-tools.md](dev-tools.md#checking-on-screens-the-tv-app-and-the-phone-app): `tools/tv-dev.sh` and `tools/tv-window.ps1` for the Windows TV app, `tools/emulator.sh` for the phone app on the emulator. What they're built on, and what to keep in mind:

### The Windows TV app, without disturbing a copy that's already running

The owner often has release copies of the TV app open (from the Downloads folder). They own port 45780, and phones may be paired with them.
- `tools/tv-dev.sh start` runs a development copy and prints its port and pairing code. If 45780 is taken it picks another port, read from the log line `[host] Listening on port 63356 (pairing code 6423)`.
- Only that copy is ever stopped: its path ends in `tv_test_app\build\windows\x64\runner\Debug\ThumbPartyTV.exe`. Never stop processes by name alone.
- The development copy shares this PC's saved pairings and network name, so when no release copy is running, the owner's phones can join it. Keep checks short and stop it afterwards.
- Debug runs save their stats sessions to a `sessions-debug` folder, so test sessions don't mix with real ones.
- The keyboard plays as another player: arrows, Space (A), X and Z.
- `tools/tv-window.ps1` drives the window with Windows APIs (`SetForegroundWindow`, `keybd_event`, `PrintWindow`); sending keys with `SendKeys` didn't work. PowerShell scripts need `-ExecutionPolicy Bypass` on this PC.
- The simulated controller needs no phone: `cd packages\connection; dart run connection:sim_controller --code <code>` (`--demo`, `--stream`, `--metrics` for more).

### The Android 12 emulator

- **Since Nov 6, 2026 the emulator's window crashes at start on this PC** ("Android Emulator closed unexpectedly", after "Failed to load opengl32sw … Falling back to system OpenGL"), for both AVDs and every GPU mode; the crash dialog then waits, which looks like a hang. Headless works: `tools/emulator.sh start` now boots with `-no-window -gpu swiftshader_indirect -no-snapshot` (about 25 s; `EMULATOR_FLAGS` replaces those). A headless emulator is invisible: stop it with `tools/emulator.sh stop`. The demo videos (Nov 5) changed `m7_android12` (host GPU, 2 GB, a 2400×1080 landscape panel) after its quick-boot snapshot was saved, so cold boots only. For the window again, try updating or reinstalling the emulator package in Android Studio's SDK Manager.
- The emulator's phone app remembers the last TV it paired with and reconnects on launch, which can join the owner's running TV app. **Always clear its data first** (`tools/emulator.sh launch` and `install` do: `adb shell pm clear com.thumbparty.app`), then connect to your own TV app at `10.0.2.2:<port>` (10.0.2.2 is the PC from inside the emulator).
- In Git Bash, `MSYS_NO_PATHCONV=1` stops Git Bash rewriting `/sdcard/...` paths, and `adb install` needs a Windows path. The script handles both.
- `tools/emulator.sh ui` lists labelled controls through Android's accessibility tree (`uiautomator dump`), which works with Flutter apps, so `tap-name` finds buttons by name.
- `adb shell input tap` is a very short tap: a good test that quick taps aren't lost. `adb shell input swipe x y x y <ms>` holds for that long.
- The Connect screen closes itself once connected, so pressing Back afterwards leaves the app.
- Every time the development TV app restarts it may get a new port; reconnect the phone to it.
- Setup and the full check: [building.md](building.md), "Android 12 emulator check".

### The Android TV

- Install with `adb connect <TV IP>:5555` (accept the prompt on the TV), then `adb install`. The connection drops when the TV sleeps; turn wireless debugging on again if needed.
- Files saved by the TV app (logs, exported stats) are in `/sdcard/Android/data/com.thumbparty.tv/files`.
- The TV app keeps the screen awake while a controller is connected (the TV's 10-minute sleep used to drop controllers).

## Lessons learned

**Releases**
- A tag with the same name as a branch (`m12` on branch `m12`) can't be pushed by `tools/release.sh`: `git push origin m12` is ambiguous and fails. Tag by hand and push `refs/tags/<tag>` (docs/release.md), then `tools/release.sh --status <tag>`, which reports once rather than waiting. Even then Codemagic can't check the tag out ("Failed to set the repository head"), so the iPhone build fails: never name a tag after a branch; milestone branches should be `mN-work` or similar (Nov 7, 2026: `m12` failed on TestFlight, `m12.1` went out).

**Flutter and Dart**
- Don't run two Flutter builds at once: they share a build cache and collide.
- Don't pipe a build or test through `| tail`: the pipe hides the exit code, so a failed build looks successful. `tools/check.sh` keeps the exit codes.
- A `late final` field that uses `ref` must be set in `initState`. If it's first used in `dispose`, it throws "Using ref when unmounted".
- A provider that watches another provider is rebuilt when that one changes, which cancels any timers it started. This silently stopped the analog sticks on a tablet (M8).
- Widget tests: stream events arrive a frame late (pump twice), `ListView` builds lazily (scroll to an item before finding it), and assets loaded outside the test clock need overriding. `pumpAndSettle` never finishes while a spinner turns.
- A widget's `autofocus` is ignored if something above it already holds the focus; move the focus with a `FocusNode` instead (the results' Play again, M10).
- Games read each phone's buttons once a frame. A quick tap whose press and release arrive between two frames was lost until the host kept every press held for at least 50 ms (M10).
- When a screen is replaced (Play again), the new one starts before the old one is disposed: clean-up in `dispose` must not undo what the new one set up (M10).

**Platforms**
- iOS: Flutter's `landscapeLeft` and `landscapeRight` are the reverse of iOS's, so the orientation lock needs the platform (M3).
- iPad apps must list all four orientations or App Store Connect rejects the upload (error 90474). The orientation-lock API kept an iPhone's pairing keyboard sideways, so it was removed (M8).
- Some Android tablets have a portrait natural orientation, others landscape, which changes the gyro's axes (M8).
- `VibrationAttributes` needs Android 13; Android 12 needs a fallback. The Android 12 emulator check caught this crash; the build's lint didn't (M7).
- The Pixel Tablet has no vibration motor, and no iPad does: controls flash on press instead.

**Releases and stores**
- The TV app is its own Play app, so its testing track is plain `alpha`, not `tv:alpha` (M8).
- Play only accepts a version code once: every upload needs a new commit (the build number is the commit count).
- After a release, the Play Store app may need a refresh before testers see the update.
- A TestFlight invite for a tester must be sent as a tester, not as a developer team member.

**Working on this PC**
- In Git Bash, multi-line edits with `perl` or `sed` that contain `||` or `${...}` can mangle files. Use an editor or a script file for anything non-trivial.
- Python isn't installed. Use Dart or bash for scripts.
- The Google Cloud CLI is installed for the stats report: `dart run metrics:report --firestore <project> --token "$(gcloud auth print-access-token)"`.
