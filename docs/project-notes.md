# Project notes

How this project is run, what's still open, and the lessons learned along the way. It's the shared, backed-up copy of the working notes Claude Code keeps between sessions. The milestone status table is in the [README](../README.md#status); requirements are in [PRD-v2.md](PRD-v2.md); each milestone's tests and results are in [checklists/](checklists).

## How we work

- **One milestone at a time.** Claude builds a milestone from the PRD, commits and pushes it, writes its device tests into `docs/checklists/mN.md`, then stops. The next milestone starts only when the owner has run the device tests and says so ("Record M9 as done", "start M10"). "Continue" alone doesn't count as confirmation.
- **Tags only on the owner's word.** A tag publishes builds to Play, TestFlight and a public GitHub Release, so Claude tags only when asked ("tag m10.1"). Fixes found in device testing go out as point releases (`m10.1`, `m10.2`).
- **Every release has tester notes.** The tag's message is the notes, in plain words for testers ("Shape Race: the right stick now turns pieces…"), never empty; even "Minor update for testing" is fine. They go to Play "What's new", TestFlight "What to Test" and the GitHub Release.
- **Device feedback becomes a recorded change.** When a device test finds a problem, the fix is written into the PRD and the milestone's checklist ("Changes from device testing"), with the tester's words quoted.
- **Android testing is on hold.** Android phone and tablet checks stay marked *pending*, not skipped. The Android TV and Windows checks go ahead.
- **Use the scripts and helper agents.** `tools/check.sh` before committing code (through the `test-runner` agent in Claude Code), `tools/release.sh` to release (Claude runs it itself, in the background, only after the owner approves the tag, e.g. "tag m11.2"; the `release-checker` agent is kept for when it's asked for by name: as a separate agent it cost more and drew Claude Code's "Blind Apply" security flag), `tools/flash.sh` for work that copies an existing pattern (through `flash-worker`, below), and `tools/tv-dev.sh` and `tools/emulator.sh` for hands-on checks ([dev-tools.md](dev-tools.md)).
- **Offload as much as is safe to the flash-worker.** It runs on DeepSeek Flash, outside the Claude subscription. Claude decides when to use it, without being asked each time, and runs `tools/flash.sh` directly rather than through the `flash-worker` agent (one fewer hop). Related small jobs go out together as one spec.
  - *Flash-worker:* `lib/` code that copies a pattern Claude has designed (Claude writes the interface and one finished example; the worker fills in puzzle and level data, extra shapes, enum cases, settings fields, UI text); tests from a case list Claude writes; analyzer and format fixes, deprecated-API replacements, renames and doc comments; doc follow-ups (dev-tools.md, these notes, status tables, checklist ticks after the owner reports results); first drafts of tester notes and device checklists; read-only checks that only report; asset wiring.
  - *Claude only:* planning, architecture and milestone scope; every PRD edit; protocol, connection and platform code; game feel and tuning; debugging; reviewing each worker diff and running the checks; commits and releases.
  - *How:* Claude is the worker's single source of truth. Each job is one complete spec (the exact files, the example to copy, the expected behaviour and the check to run), with no back and forth. If the worker gets it wrong, it gets up to two more tries, each a fresh, complete spec saying what was wrong; after that Claude takes over. Claude takes over straight away if the worker finds the code doesn't behave as described (a design question) or changes files outside the job. Claude runs two workers at once only on separate files.
  - *Size:* worth sending are read-only reports, batches of about 5 or more tests or data entries copying one example, and work where the spec can name the cases without Claude working out every value. Claude does it directly for one-line edits, `lib/` changes under about 30 lines, and any job whose spec would have to contain the code. In between, it sends the job only when the design is quick to state and the typing is long (one pattern repeated several times). Trial runs showed a 3-test job and a 15-line `lib/` change cost as much to spec and review as to write, while the read-only report paid off.
  - *More to the worker (after M11, where it wrote about a third of the lines):* (1) A **follow-ups batch** at the end of each step: the small changes each under the size limit go out as one job (wiring a second game to a pattern, extra test-tool options, stats fields, updating old tests to a changed API, version bumps, and first drafts of the README status row, the architecture section and the checklist from Claude's notes, which Claude then edits). (2) **Screens from a skeleton:** Claude writes a new screen's behaviour (state, controller handling, keys, navigation) and empty build helpers with comments saying what each shows; the worker fills in the layout, copying an existing screen, and Claude reviews the whole diff. (3) **Shorter test specs:** each case as a rule and a formula rather than worked-out values; the worker reports every value it computed, and the assertion review checks them.
  - *Draft and review (being tried from the next job after M11):* for screens and self-contained modules with a clear contract (test tools, stats fields, painters, game rules from a precise brief), the worker writes the code as well. Claude writes a brief instead of code: the files, types and signatures, the behaviour and edge cases from the PRD, and the test cases. The worker writes the tests first, then the code, one module per job, and runs the checks. Claude reviews the whole diff (with `/code-review`, or by reading it); the problems it finds go back to the worker as bug fixes (below). Reading a diff costs much less than writing it, so this moves more of the work to the worker; the brief and the tests keep the rework down. Cross-cutting mechanisms (controller ownership, menus and focus, the game host), protocol, connection and platform code, game feel and debugging stay with Claude.
  - *Bug fixes (owner, Nov 3, 2026: "let the flash-worker get a few attempts at fixing a bug before you take over"):* when Claude finds a bug, in a review of a worker's diff or anywhere else, Claude does the diagnosis and the worker does the fix. The fix brief names the file and function, the cause, the behaviour it should have, and a failing test case (a rule and its expected value). The worker writes the test first, checks that it fails, fixes the code and runs the checks. It gets three tries in all, each a fresh, complete brief that says what was still wrong; then Claude takes over. Claude fixes it itself straight away only when the brief would have to contain the fix line for line, when the cause isn't known yet (debugging stays with Claude), or for protocol, connection, platform or cross-cutting code. Claude still reviews the fix and runs the checks.
  - *Measuring:* `tools/flash.sh` logs each job's tokens to `~/.thumbparty/flash-usage.tsv` ([dev-tools.md](dev-tools.md#deepseek-flash-helper-set-up-check-remove)); compare it with Claude Code's `/usage` after a milestone. Don't edit files while a worker runs: the script counts every change in the tree as the worker's.
  - *Review:* every job runs with `--allow` (the files it may change) and `--check` (the checks for them), so stray edits and failing checks are caught by the script. Claude then reviews by risk: for docs, status ticks, format and analyzer fixes, the list of changed files, the diff size and the checks; for tests, the assertions (do they test what the spec says?); for `lib/` code, the whole diff. Claude trusts the diff, not the worker's summary.

### Never commit

- The owner's local backups `docs/PRD - Copy.md`, `docs/PRD-old.md`, `docs/PRD-old-2.md`, and the `kenney-audio/` source folder. They're untracked on purpose. Stage files by name (`git add path/to/file`), never `git add -A` or a whole folder, and check `git status` before committing.
- Real Firebase values in the docs: [release.md](release.md) keeps placeholders. The real ones are GitHub variables.
- Secrets of any kind. They live in GitHub secrets, Codemagic and the Play upload key folder ([dev-tools.md](dev-tools.md#moving-development-to-another-computer)).

## Open items

Carried from earlier milestones, still to do:
- **Android checks** (on hold): the v1 Android phone tests, the M7 tablet tests, the M8 Android install by another person, the Android TV rename and pairing checks, the Play-installed TV app with store phones, and the TV launcher banner.
- **Public TestFlight link:** the external `Testers` group isn't set up yet. When it is, the link goes into the tester guide (`site/`) and the group into `codemagic.yaml`.
- **Phone screenshots** for the stores show the PC's old name in the connection chip. Retake them after the PC is renamed: build the Windows TV app, pair the `m7_android12` emulator, capture at 2400×1080 and pad to 2400×1200 (`assets/branding/screenshots/`).
- **The `docs/protocol.md` read-through** (M9; the owner skipped it then).
- **M10 extra checks** kept for later ([checklists/m10.md](checklists/m10.md)): old with new, Puzzle settings with the remote, Stats export, and the three optional checks carried from M9.
- **M11 device tests** ([checklists/m11.md](checklists/m11.md)): built in 0.11.0 (2 to 4 players, big pieces, pause, and T21: the whole TV app from a controller), waiting for the owner's tests.
- **m11.3** (built): the "Bubble Pop" sounds (`tools/audio/`) and stats that count active play time only (`activeMs`). Device checks in [checklists/m11.md](checklists/m11.md) ("m11.3 checks"). The untracked `kenney-audio/` folder at the repository root is no longer needed; the owner decides whether to delete it.
- **Look-and-sound milestone, planned between M12 and M13** (owner still thinking; not in the PRD yet): brighter colours, Canvas outlines and shadows, then the "Toy Box Toon" shader (Arena first), the 3 extra sounds with looping, and a mute or volume setting. Source: the DeepSeek workspace's `game-controller-shaders/DESIGN.md` and `thumb-party-audio/`.
- **Party ideas** (owner still thinking; not in the PRD): chaos events with a cat, power-ups, points, party nights with end-of-night awards, and on-device leaderboards. Written down in [party-ideas.md](party-ideas.md).

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
