# s3c-b G1 — report

Job: [s3c-b-g1.md](s3c-b-g1.md), a plan only. Plan: [s3c-b-g1-plan.md](s3c-b-g1-plan.md). No code and no other file
changed.

## Files changed

- `docs/briefs/m12/s3c-b-g1-plan.md` (new, 412 lines): the G1 plan for s3c-b G4 — the five items with file:line facts,
  every file with its size now and after in implementation order, the splits for the lib files over 300, slices for
  review, conflicts, and 8 questions each with a proposed answer.
- `docs/briefs/m12/s3c-b-g1-report.md` (new, this file): the report, ending with the three required sections.

## What I checked against the code (and what surprised me)

- `m12-sessions.md:69` still says `controller_client.dart` is 400 lines and must be split before anything is added. It
  is **379**: s3a G4 already split it (`client_host`, `client_messages`, `client_input`, `client_metrics`,
  `client_controls`, `client_types`). Item 1 adds ~13 lines, leaving ~392, i.e. still under the 400 hard limit but with
  no room left. The plan says so and keeps every new type in a new file (`client_viewer.dart`).
- s3c-a's `FrameView` is written against `stats` (the client's `ViewerStats`) and `nowMs` (`ControllerClient.nowMs`).
  **Neither exists today**: the clock is the private `_now` (`controller_client.dart:260`) and there is no viewer
  anywhere. Item 1 of this job is therefore a hard dependency of s3c-a's contract, and the plan adds exactly those two
  names so that brief's call site can be written as drafted.
- The phone app lists metrics, rating, layout and status, but **not** `Capability.view`
  (`controller_app/lib/src/storage.dart:34`). That makes item 1's "no change for a client without `view`" true by
  construction: no viewer object, no `inputSent`, batches byte-identical. When step 6 adds the capability, the same
  code path starts filling `stages`/`view` without an edit in `controller_app`.
- Inputs leave the client from two places (not one): `sendInput` (`controller_client.dart:173`) and the state sent when
  pairing completes (`client_messages.dart:151`). Both go through the private `_send` (`:306`), so the plan records the
  send time there — the cheapest way to make "every input it sends" true, and the state already carries `sentAtMs`, the
  value the host measures against.
- `ViewerStats.drain()` empties itself (`viewer_stats.dart:110-116`), and the client drains into every metrics batch.
  So the sim's "summary at the end" is the whole run only when `--metrics` is off; with both flags it is the tail since
  the last batch. That is Question 3 (proposed: print it with its sample count; the smoke step runs `--view` without
  `--metrics`).
- A frame's wire size is measurable without any protocol or client change: `MessageCodec().encode(frame).length`
  (`protocol/lib/src/codec.dart:35`) is the same text the host sent. The plan uses it for the sim's mean/max bytes.
- `packages/metrics/lib/src/session.dart` (424) and `report.dart` (351) must both grow for item 3. `session.dart` is
  over the 400 hard limit, so it cannot grow at all: the plan moves its three other public types (`DelayStats`,
  `RatingScheduler`, `HostType`) into files of their own first (also fixing the "one public type per file" rule), then
  adds ~8 lines. `report.dart` moves `GroupStats`/`groupBy`/`table` to `report_table.dart` before gaining 7 columns.
- `metrics_test.dart` (612) is over the 500 test limit and must not grow: the new CSV columns go at the **end** of the
  row, after `open_minutes`, so the existing `endsWith(',open_minutes')` assertion (`:291`) still passes and only the
  field count changes (`:294`, 26 → 33) — same line count.
- Item 4's rate does not need a single line in `test_game`, `puzzle_game` or `party_host`: both `GameSession`
  construction sites (after s3b G4, `ArenaView.initState` and the puzzle's play view) pass no settings, so
  `GameSession`'s default reaches them. The catch is that a range-checked, release-aware default can't be `const`, so
  the contract's `this.settings = const HostingSettings()` becomes a nullable parameter (Question 1).
- The `--game` debug start fits in `tv_test_app` (~70 lines, 0 in `party_host`): `PuzzleChoice` and `PuzzleScreen` are
  public (`party_host.dart:32`, `puzzle_screen.dart:21-26,34-46`) and `tv_test_app` already depends on `puzzle_game`
  (`pubspec.yaml:24`), so no `~60 lines in party_host` threshold is reached and the `tv-window.ps1` key sequence stays
  a fallback (it is in the plan anyway, with the caveat that the home screen's Play button focus is unverified).
- `--game shape_race` needs a player before it can build teams ("whoever is connected"), so its first screen waits for
  the first pairing; later joiners watch (teams are final in `PuzzleScreen`). Stated in the plan as a limitation.
- The smoke `frames` step must restart the TV app (the app must be *in* a game, which smoke never is today), and a
  restart ends pairings and truncates the log (`tv-dev.sh:64`). It therefore goes last, re-reads port and code from
  `tv-dev.sh status`, and SKIPs when the run didn't start the TV app itself, so a developer's own copy is never killed.

## Values I computed (for the plan's numbers)

- File sizes: `controller_client.dart` 379 + 13 ≈ 392; `session.dart` 424 − 38 (DelayStats 7-44) − 32
  (RatingScheduler 46-77) − 7 (HostType 79-85) + 8 ≈ 355; `report.dart` 351 − ~140 (moved table code) + ~70 ≈ 280;
  `sim_controller.dart` 266 − 44 (token helpers 223-266) + ~24 ≈ 246; `smoke.sh` 378 + ~22 ≈ 400.
- CSV columns: 26 today (`report.dart:75-78`) + 7 = 33.
- Table columns: 18 today (`report.dart:254-273`) + 3 compact ones (`touch ms`, `jitter ms`, `frames/gaps/late`) = 21.
- Frames step time: dev build already built, `flutter run` attach ~20-40 s + `dart run` ~2-5 s + the sim's 12 s
  (`smoke.sh:67`) + polling ≈ **45-90 s**, so a smoke run goes from ~30 s to ~1.5-2 min.
- Frame rate for a 60 Hz sim draw: 16667 µs, the same period `runStreamInput` uses (`demo_input.dart:76`).

## Questions

Numbered as in the plan (§9), each with the proposed answer there:

1. `GameSession`'s const settings default becomes nullable — ok, or pass settings explicitly from both views?
2. Define names `FRAME_RATE_HZ` / `START_GAME` (matching `BUILD_NUMBER`, `FIRESTORE_PROJECT`)?
3. The sim's summary with `--metrics` on covers only the tail; print as is (with the count), or add run totals to
   `ViewerStats`?
4. No unit test for `SimView` (it would need `test/` importing `../bin/`), the smoke step being its proof — ok?
5. "Per controller" in item 3 = the CSV mode rows + compact group-table columns, no new "By controller" table — ok?
6. `FrameView` taking `ControllerClient`: keep s3c-a's `client.viewerStats!`, or have `FrameView` take the client and
   throw `ArgumentError` like `SimView.of`?
7. The `frames` step restarts the TV app and skips when it didn't start it — ok?
8. `smoke.sh` at ~400 lines: accept, or move its emulator block to `tools/smoke_emulator.sh` in a later tools job?

## Suggestions (not acted on)

- `docs/dev-tools.md` is 404 lines and project-notes already records it as tech debt; this job adds ~12 lines. Splitting
  out the DeepSeek Flash section (~60 lines, `:319-372`) would fix that, but it is a docs job of its own, not this one.
- `dev-tools.md:14` says smoke takes "about 30 seconds"; the frames step makes it "about a minute longer". Worth a real
  run's numbers replacing the hand-written sample output there (project-notes:50 already asks for that).
- `project-notes.md:59` (the flutter tool's temp-folder crash) is why the frames step takes its proof from the sim's own
  line only, like the `ping`/`input`/`metrics` steps today. Nothing new is needed, but a real run of the new step on
  this PC will probably want the same "try twice" treatment the TV start already has.

## Checks

None applicable: this job produces a plan and a report only, so there is no `--check` to run (no code, no format, no
tests). `dart format` on a `.md` file isn't a thing; the plan is plain Markdown at 120 columns like its neighbours.

## Commit message

m12 s3c-b G1: plan the measuring tools

The client's ViewerStats and nowMs, sim --view with a draw-less viewer and its
summary, the report's touch_to_frame/frame_jitter and view counts, the
debug-only FRAME_RATE_HZ/START_GAME defines and tv-dev.sh flags, and smoke's
frames step. Facts with file:line, every file's size, the splits that keep
session.dart and report.dart under the limits, and 8 questions.

## Status row

**s3c-b G1** plan done ([s3c-b-g1-plan.md](s3c-b-g1-plan.md)), no code: client viewer stats, sim `--view`, report columns, debug defines, smoke `frames`; 8 questions for Claude.

## Delete

- none
