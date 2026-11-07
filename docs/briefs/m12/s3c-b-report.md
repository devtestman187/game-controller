# s3c-b G4 — report

Job: [s3c-b.md](s3c-b.md), item 3c-b at gate G4: the measuring tools. Plan: [s3c-b-g1-plan.md](s3c-b-g1-plan.md),
§1–§6 in §7's order, **minus plan files 10–12** (`DelayStats`, `RatingScheduler`, `HostType`): the first two already
live in `session_stats.dart`, and `HostType` was left where it is (moving it is a later tools job's). Contract:
[m12-sessions.md](../../design/m12-sessions.md) §1, §2, §4, §6 — where it and the plan disagree, the contract was
followed and the deviation is listed below.

## What each file does

**Item 1 — the client measures what it shows** (`packages/connection`)

- `lib/src/client_viewer.dart` (new): one object per phone that listed `Capability.view`. `inputSent(InputStateMessage)`
  records the send time (skipping messages without `sentAtMs`); `withSamples(MetricsMessage)` drains `ViewerStats` into
  a copy of every outgoing batch (`stages` + `view`), so the host receives them on the wire that already exists.
- `lib/src/controller_client.dart`: builds `_viewer` only when the pairing identity has `view`, exposes `viewerStats`,
  routes every `_send` through `_viewer?.inputSent`, and makes the clock public as `nowMs` (the old private `_now`,
  now the clock the frames' `arrivedAtMs` is taken on). `sendMetrics` sends `_viewer?.withSamples(batch) ?? batch`, so
  a phone without the capability sends byte-identical batches.
- `bin/sim_token_file.dart` (new): the token read/write helpers moved verbatim out of `sim_controller.dart` (no change
  in behaviour; the file was over the 300 aim before the new flag and options).
- `bin/sim_view.dart` (new): `SimView` — a draw-less viewer for the sim. Listens to `client.view`, feeds
  `ViewerTiming`/`ViewerStats`/`PlayoutBuffer`, draws at 16667 µs from the timing's `renderAtMs`, and prints the
  summary at the end. `SimView.of` throws `ArgumentError.value` when the client has no `viewerStats` (no capability).
- `bin/sim_controller.dart`: `--view` adds `Capability.view`, starts a `SimView` and prints its summary before
  disposing; the token helpers and usage text were updated around it.
- `test/client_view_test.dart`: grows the two-channel `FakeHost` cases — a frame acked by an input the phone sent
  yields `stages['touch_to_frame']`, `view` counts ride along in `sendMetrics`, a queued batch keeps its sample across a
  reconnect (`metricsWaiting == 1`, no double drain), and a phone without `view` adds nothing.

**Item 2 — host settings and the rate** (`packages/game_kit`)

- `lib/src/hosting_settings.dart`: `startFrameRateHz = int.fromEnvironment('FRAME_RATE_HZ', defaultValue: 0)`,
  `HostingSettings.fromFrameRate(int hz)` (0 → the default 60, 20–60 kept, anything else `ArgumentError.value`) and
  `HostingSettings.fromEnvironment()` (release builds get the defaults, debug builds honour the define).
- `lib/src/game_session.dart`: `GameSession(..., {HostingSettings? settings})` with
  `settings = settings ?? HostingSettings.fromEnvironment()`, and `ViewStartMessage(hz: this.settings.frameRateHz)`
  (the parameter shadows the field, so the `this.` is required). No call site in `test_game`/`puzzle_game` changes:
  both pass no settings, so every game gets the define.
- `test/hosting_settings_test.dart` (new): 4 tests — `fromFrameRate` 0/20/30/60 kept and 19/61/−1 rejected, the playout
  default untouched, `startFrameRateHz == 0` in tests, and `fromEnvironment()` equalling the defaults.

**Item 3 — the report** (`packages/metrics`)

- `lib/src/session.dart`: `_Player` accumulates `viewFrames`/`viewGaps`/`viewLate` from every batch's `view` (counts
  are the player's, not the mode's, so they carry across segments, `m12 §6`; negatives clamped by `max(0, …)`).
  `summary()` was split into `_playerJson`/`_modesJson`/`_switches`/`_segmentJson` — the JSON is byte-identical.
- `lib/src/report.dart`: `ModeRow` gains nullable `touchMedianMs`, `touchP95Ms`, `jitterMedianMs`, `jitterP95Ms`,
  `viewFrames`, `viewGaps`, `viewLate`; `csvHeader` gains the seven matching columns; `rowsOf` is now one
  `_PlayerRows` per player (reading `stages['sent_to_received']`, `['touch_to_frame']`, `['frame_jitter']` and the
  player's `view`).
- `lib/src/report_table.dart` (new): `GroupStats` (touch median/p95, jitter median/p95, viewer sums) and the three
  compact columns `touch ms`, `jitter ms`, `frames/gaps/late` in both group tables. Also holds `_headers`/`_cells`,
  `table`, `enjoyment`, `report()` and `csv()` (deviation below).
- `lib/metrics.dart`: exports `report_table.dart`.
- `test/view_report_test.dart` (new): the row's seven values, the table's headers and its compact cells, the CSV's
  seven trailing fields, the no-view row (nulls, `- - -`, empty CSV cells), the cross-segment sums for the session
  counts, and a phone that never views having no `view` key.
- `test/metrics_test.dart`: only the CSV-length block changed (values below), same 612 lines.

**Item 4 — the debug start** (`tv_test_app`)

- `lib/src/debug_start.dart` (new): `const String startGame = String.fromEnvironment('START_GAME')` and
  `debugStartScreen(String game)` → `GameScreen` for `arena`, a waiting-then-`PuzzleScreen` for `shape_race`, null
  (home screen) otherwise; only in `kDebugMode`. The shape race waits for the first controller and the first easy
  puzzle, then puts that player on the left.
- `lib/main.dart`: `TvTestApp({super.key, this.game = startGame})`, `home: debugStartScreen(game) ?? const HomeScreen()`.
- `test/support/pump_app.dart`: `pumpApp(..., String game = '', bool settle = true)` — games never settle, so the two
  game tests use `settle: false`.
- `test/debug_start_test.dart` (new): no define → home screen; `arena` → `GameScreen` and no home; `shape_race` → the
  waiting screen, then a controller arriving builds the puzzle with the right level, id and side.

**Item 5 — the smoke step** (`tools`)

- `tools/tv-dev.sh`: `start --hz 20|30|60 --game arena|shape_race` → `--dart-define=FRAME_RATE_HZ=…` /
  `START_GAME=…`; bad values print the usage and exit 2; when the app is already running it says to `stop` first
  (the defines cannot reach a running app). The header gained sample commands and `usage()` reads it.
- `tools/smoke.sh`: new `sim_view_pid` in the cleanup trap, `start_tv` forwards its arguments, `wait_tv_stopped`
  polls `tv-dev.sh status`, and a last `frames` step (Q7): SKIP when this run didn't start the TV app, otherwise stop
  it, `start_tv --game arena`, re-read port/code from `tv-dev.sh status`, run
  `sim_controller --view --stream --seconds …` in the background, proof = `Touch to frame: … ms median`, print the
  three summary lines indented. Runs after the emulator block so it cannot disturb it.

**Item 6 — the docs** (`docs/dev-tools.md`)

- The smoke table's duration, the tv-dev sample commands and the new start-option bullet, the smoke sample output
  (`TV app in the arena…`, `PASS frames`, the summary lines), a bullet on what the frames step does and when it SKIPs,
  `--keep` leaving the app in the arena, and `sim-view.log` in the output folder.

## Line counts (flag at 300; lib hard limit 400, tests 500)

| File | Lines | Note |
|---|---|---|
| `packages/connection/bin/sim_controller.dart` | 241 | was 266; helpers moved out |
| `packages/connection/bin/sim_token_file.dart` | 49 | new, all moved |
| `packages/connection/bin/sim_view.dart` | 141 | new |
| `packages/connection/lib/src/client_viewer.dart` | 43 | new |
| `packages/connection/lib/src/controller_client.dart` | 398 | was 379; **under 400 but over the 300 aim** |
| `packages/connection/test/client_view_test.dart` | 152 | new, 9 cases (5 bodies run per transport) |
| `packages/game_kit/lib/src/game_session.dart` | 277 | was 272 |
| `packages/game_kit/lib/src/hosting_settings.dart` | 64 | was 40 |
| `packages/game_kit/test/hosting_settings_test.dart` | 29 | new |
| `packages/metrics/lib/metrics.dart` | 14 | was 13 |
| `packages/metrics/lib/src/report.dart` | 245 | was 351; table code moved out |
| `packages/metrics/lib/src/report_table.dart` | 209 | new (table code + `report`/`csv`) |
| `packages/metrics/lib/src/session.dart` | 379 | was 356; **over the 300 aim** |
| `packages/metrics/test/metrics_test.dart` | 612 | **over the 500 test limit — unchanged, pre-existing** |
| `packages/metrics/test/view_report_test.dart` | 126 | new |
| `tv_test_app/lib/main.dart` | 55 | was 50 |
| `tv_test_app/lib/src/debug_start.dart` | 60 | new |
| `tv_test_app/test/debug_start_test.dart` | 56 | new |
| `tv_test_app/test/support/pump_app.dart` | 97 | was 87 |
| `tools/smoke.sh` | 416 | was 378; **over 300 — script, Q8 accepted** |
| `tools/tv-dev.sh` | 134 | was 108 |
| `docs/dev-tools.md` | 412 | was 404; docs, already tech debt |

No pubspec or `pubspec.lock` change: nothing new was needed (the sim already had `connection` and the metrics tests the
packages they use).

`git status` also lists `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
`generated_plugins.cmake` — a `flutter` tool run rewrote their line endings; `git diff --numstat` shows no content
change, and this job edited nothing there.

## Checks (all run by `tools/check.sh`)

`tools/check.sh format analyze protocol connection metrics kit arena puzzle host phone tv` → **all PASS**, 85 s.
Test counts, before → after:

| Check | Before | After |
|---|---|---|
| format / analyze | PASS | PASS |
| protocol | 102 | 102 |
| connection | 223 | 232 (+9, `client_view_test.dart`) |
| metrics | 39 | 45 (+6, `view_report_test.dart`) |
| kit | 25 | 29 (+4, `hosting_settings_test.dart`) |
| arena | 39 | 39 |
| puzzle | 78 | 78 |
| host | 54 | 54 |
| phone | 275 | 275 |
| tv | 23 | 27 (+4, `debug_start_test.dart`) |
| total | 858 | 881 |

`tools/review.sh`: one **FAIL**, `packages/metrics/test/metrics_test.dart:1 612 lines (test limit 500)` — pre-existing,
confirmed identical to `HEAD` (`git show HEAD:… | wc -l` = 612), and this job kept the file at 612. The 8 NOTEs are
numeric literals in pre-existing or moved code (`session.dart` 60000/1000, `report_table.dart` 100, `report.dart`,
`_row` at 54 lines) and `smoke.sh`/`tv-dev.sh` wait values; nothing FAILs on the new lines.

## A real `tools/smoke.sh` run

**Not run here.** This sandbox refuses commands that start the TV app (the `flutter run` inside `tv-dev.sh`), so the
frames step has no real output to quote. Claude runs it. Two things to look at on that run: the step's wall time (the
plan guesses 45–90 s, docs say "about a minute longer") and whether `Touch to frame: … ms median` appears at all — the
proof line comes from the sim's own summary, like the other steps.

## Old → new test expectations

All in `packages/metrics/test/metrics_test.dart` (the CSV assertions at `:291-298`), the seven new columns being
appended after `open_minutes`:

- `expect(ModeRow.csvHeader, endsWith(',open_minutes'))` → `endsWith(',view_late')`. The plan said the old assertion
  still holds; it cannot, the new cells follow the old last one. This is a **plan error**, see Question 6.
- `hasLength(26)` → `hasLength(33)`. 26 + 7 viewer columns.
- `fields.last` = `'0.50'` → `fields[25]` = `'0.50'` (`fields.last` is now `view_late`, empty in that fixture).
- The assertion that the viewer cells are empty for a row without them moved to `view_report_test.dart` (which owns
  the new fixtures); keeping it in `metrics_test.dart` would have grown the file past 612.

Every value the new tests assert was computed from the fixtures:

- `view_report_test.dart`: the row reads touch `41`/`62`, jitter `3`/`9`, view `720`/`3`/`5` from
  `stages.touch_to_frame {n:2,median:41,p95:62}`, `stages.frame_jitter {n:2,median:3,p95:9}` and
  `view {frames:720,gaps:3,late:5}`; the table cells are `41/62  3/9  720/3/5`; the CSV has 33 fields and
  `sublist(26) == ['41','62','3','9','720','3','5']`; without `view`/stages the row is null and the cells are `- - -`.
  For the session sums: batches of `{frames:700,gaps:2,late:3}` and `{frames:20,gaps:1,late:2}` with a repeat of index
  1 → `{'frames': 720, 'gaps': 3, 'late': 5}` (the repeat adds nothing).
- `client_view_test.dart`: the fake clock is 1000 ms; an input sent at +40 and acking frame 7 gives
  `stages['touch_to_frame'] == [40]` and `view == (frames: 1, gaps: 0, late: 0)`; the pairing-time state (sentAtMs 25)
  gives `[25]`; after the reconnect `metricsWaiting == 1`, the resent batch still has `[40]` and `frames: 1`; a phone
  without `view` gives `stages` empty and `view` null.
- `hosting_settings_test.dart`: `fromFrameRate(0).frameRateHz == 60`, 20/30/60 kept, 19/61/−1 throw `ArgumentError`;
  `maxPlayoutFrames` stays 2; `startFrameRateHz` is 0 under `dart test` (no define); `fromEnvironment()` equals the
  defaults.
- `debug_start_test.dart`: no define → `''` → `debugStartScreen` null for `puzzle` and non-null for `arena`/
  `shape_race`; `arena` shows the "No controller connected. Pair a phone on the main screen." text; `shape_race` waits,
  then `phoneInfo('p9', 1)` builds `PuzzleScreen` with `Level.easy`, `testPuzzles().ofLevel(Level.easy).first.id` and
  `teams == {'p9': PuzzleSide.left}`.

## Deviations (all to be reviewed)

1. **`report_table.dart` also holds `enjoyment`, `report()` and `csv()`.** The plan kept them in `report.dart`, but
   `report()`/`csv()` build `table(...)` and `GroupStats` now lives in `report_table.dart`; `report.dart` importing it
   while `report_table.dart` imports `report.dart` for `ModeRow` is a cycle. Moving the three functions down is the
   smaller change (`report.dart` 245, `report_table.dart` 209, both under 300); the public API is unchanged.
2. **`debugStartScreen` takes the game string.** `startGame` is a `const String.fromEnvironment`, which a test cannot
   vary per case, so `TvTestApp(game: …)` defaults to it and `main()` stays one line. `reassemble`-style overrides or a
   provider were the alternatives and are heavier.
3. **`SimView.summary()` prints three lines, not the plan's two.** Contract §6 asks for both `touch_to_frame` and
   `frame_jitter`; the plan's two lines omitted jitter. The contract wins.
4. **The plan's `endsWith(',open_minutes')` assertion is wrong** (Question 6 above): the new columns come after it.
5. `'arena'`/`'shape_race'` are string literals in `debug_start.dart`: the game modules expose non-const
   `String get id`, which cannot be switch-case constants.

## Suggestions (not acted on)

- `controller_client.dart` is at 398 of 400. The next line added to it must be accompanied by another split (a
  `client_view_glue` or moving `nowMs`/`viewerStats` if they grow).
- `metrics_test.dart` at 612 needs its own split job (it is 500+ today); this job kept it from growing.
- `smoke.sh` at 416 is close to the plan's ~400; its emulator block (~90 lines) is the natural split if it grows again.

## Commit message

m12 s3c-b: client viewer stats, sim --view, report viewer columns

The client measures touch-to-frame and frame jitter for phones that list
view, the sim shows and measures frames without a screen, the report and CSV
carry touch/jitter/view values per mode row and per group, HostingSettings
honours FRAME_RATE_HZ, tv_test_app starts in a game with START_GAME, and
smoke gains the frames step. 858 to 881 tests.

## Status row

**s3c-b** done: client viewer stats and `nowMs`, sim `--view` with its summary, report/CSV touch/jitter/view columns, `FRAME_RATE_HZ`, `START_GAME` and tv-dev flags, smoke `frames` step; 881 tests.

## Delete

- none
