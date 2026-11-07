# s9c report — the host-mode phone tests wait for what they expect (G4)

**Done.** Tests only: three files under `controller_app/test`, no `lib/` change, no test added or
removed, and every expectation kept as it was. The two waits that failed on Nov 7 now wait for the
screen (or the puzzle list) to arrive, up to 5 s of the test's clock, instead of a fixed number of
pumps.

## What was racing

`pressA`/`pressFace` pumps a fixed 4 × 16 ms, gives the real event loop 80 ms, then settles. The
input has to travel the in-process link to the host, and the host's menus read it on their own
`Timer.periodic` tick, which only advances when the test pumps fake time. The puzzle list also
waits for `puzzleLibraryProvider`'s `AsyncData`. On a busy PC the input arrives after those pumps,
so the menu's tick never sees the press, and the next `expect(find.byType(...), findsOneWidget)`
fails: `PuzzleScreen` in `host_lifecycle_test` (the round did not start) and `JoinScreen` in
`host_mode_test` (the pad press that opens it was lost).

## The helper (`test/support/host_app.dart`)

- `_waitLimit = Duration(seconds: 5)` — the fake-time budget of a wait (s9c).
- `_frameStep = Duration(milliseconds: 16)` — the test's clock one step moves.
- `_hostWorkStep = Duration(milliseconds: 5)` — the real time each step gives the host's event
  loop, via `tester.runAsync`, before the pump.
- `until` (line 104) now loops until `done()` or `_waitLimit` of fake time (312 steps of 16 ms),
  re-checking once after the last pump. The old loop was 200 fixed iterations (3.2 s fake); the
  longer budget only affects how long a failing wait takes.
- `untilShown(tester, finder, what)` (line 118) waits for `finder.evaluate().isNotEmpty` and fails
  with `"<what> did not show within 5 s"`, e.g. "The join screen did not show within 5 s". It is
  built on `until`, so the wait feeds real time and fake time to each other the same way.

No wall-clock cap: the loop is bounded by the 312 steps, and adding a `Stopwatch` cap of 5 s real
would abort exactly on the busy PC the brief is about (312 pumps can cost more than 5 s of real
time when the machine is loaded). The real-time side is capped per step at 5 ms of `runAsync`,
about 1.56 s of real waiting across the whole budget. See Q1.

## Waits replaced

`controller_app/test/host_lifecycle_test.dart`, "a round hidden longer than the grace is
abandoned" (the four `pressA` calls at old lines 110–113):

- :113 `untilShown(ShapeRaceScreen)` — after the first press.
- :114 `untilShown(Key('random-easy'))` — the list needs `puzzleLibraryProvider`'s data.
- :116 `untilShown(JoinScreen)` — after the press that picks the puzzle.
- :119 `untilShown(PuzzleScreen)` — after join and start. The `expect(PuzzleScreen,
  findsOneWidget)` at :120 is unchanged.

`controller_app/test/host_mode_test.dart`, "a phone hosting plays its own game…":

- :67 `untilShown(ShapeRaceScreen)`, :69 `untilShown(Key('random-easy'))` — the old fixed pumps
  before the two expectations at :68 and :70.
- :75 `untilShown(JoinScreen)` — the failing wait on Nov 7 (old line 71).
- :79 `untilShown(PuzzleScreen)` — before reading the widget at :80.

Untouched: `GamesScreen` after `enterHostMode` (it is pushed synchronously after `hosting.start()`,
and `enterHostMode` already waits for the own player to pair), the picker after an abandon, the
`ConnectScreen`/`HostScreen` switches after a stop (`until(!host.live)` already covers those), and
every bar/badge expectation.

## Runs

- `flutter test test/host_lifecycle_test.dart test/host_mode_test.dart` — 14 tests, pass.
- Five times each in a row, no load: lifecycle 5/5 pass (11:49:17–11:49:58), host_mode 5/5 pass
  (11:49:58–11:50:50).
- Five times each in a row **under load**, final code: each run was
  `flutter test --concurrency=16 test/<file> ../packages/connection/test`, which starts the
  connection package's 251 tests (real sockets, 16 suites at once) alongside the host file:
  - lifecycle 5/5 pass (12:01:26–12:02:50), each run `00:11 +256: All tests passed!` (5 host + 251
    connection).
  - host_mode 5/5 pass (12:02:52–12:04:16), each run `00:11 +260: All tests passed!` (9 + 251).
  - Same commands before the last edit (making the constants private) also gave 5/5 each.
- `tools/check.sh format analyze phone`: PASS, PASS, PASS (329 tests).
- `tools/review.sh`: 0 fail, 0 note.
- The full phone suite was also run 8 times while checking for other flakes; all passed. One run
  earlier in the session printed `+328 -1` but its log was discarded (`>/dev/null`), and I could
  not learn which test failed. I have not seen it since in 8 runs.

Things I could not do as the brief asks, and why (Q2):

- The load was not a separate `flutter test` process: this sandbox refuses background processes
  (`&`, `xargs -P`, `bash -c`, `cmd`, PowerShell all need approval). Instead the connection
  package's tests run in the same `flutter test` invocation with `--concurrency=16`, so they run as
  parallel worker processes of the same runner and overlap the host file (the host file finishes at
  ~3–5 s in an ~11 s run).
- I picked `packages/connection` rather than `packages/puzzle_game`: run from `controller_app`,
  four of puzzle_game's tests fail because they need that package's asset bundle (the puzzle files
  load from `rootBundle`). Connection is pure Dart and its 251 tests passed from here.

## Values

- 5 s / 16 ms = 312 wait steps; 312 × 5 ms = 1.56 s of real `runAsync` time at most.
- `until`'s old budget: 200 × 16 ms = 3.2 s fake; new: 5 s fake.
- Test counts: lifecycle file 5, host_mode file 9, connection package 251.

## Files changed

- `controller_app/test/support/host_app.dart` — the wait constants, `until` bounded by them, and
  `untilShown`.
- `controller_app/test/host_lifecycle_test.dart` — four waits added in the abandon test (one
  comment extended); expectations untouched.
- `controller_app/test/host_mode_test.dart` — four waits in the solo-host test; expectations
  untouched.

## Questions and suggestions

1. Q1 — Is a fake-time-only budget right, or does the brief's "real-time cap" mean a wall-clock
   limit in the helper too? I chose fake time only so a slow PC cannot trip the cap it is meant to
   survive; the per-step `runAsync` delay is the real-time knob. If you want a wall-clock cap, a
   generous one (30 s) would only catch a runner that stops pumping.
2. Q2 — Is the load setup acceptable as proof (connection package tests in the same runner, all
   suites in parallel, instead of a second `flutter test` process)? The sandbox does not allow
   starting one.
3. Suggestion — `pressFace` still has literal 16 ms/80 ms waits. Under the same busy-PC pressure
   they can lose a press whenever the *first* press of a chain is the thing expected; the new
   `untilShown` calls catch that for these two files, but other host tests (hosting_test,
   diagnostics_test) still rely on fixed pumps. A follow-up could make every press wait for its
   observable result.
4. Suggestion — the unexplained `+328 -1` full-suite run deserves a rerun on CI with the log kept;
   it was not reproducible in 8 later runs.

## Commit message

tests: wait for the host's screens instead of fixed pumps (s9c)

The two host tests raced the puzzle library's load, the host menus' tick and
the own player's pairing: on a busy PC a fixed number of pumps ended before
the screen was up (no PuzzleScreen, no JoinScreen).
until() now runs up to 5 s of the test's clock with a short real turn per
step, and untilShown() waits for a finder, failing with the screen's name.
Both files wait for Shape Race, the puzzle list, the join screen and the
puzzle before pressing on. No test, expectation or value changed.

## Status row

| 9 Docs and device tests | … **s9c done** (`s9c.md`): `until`/`untilShown` in `test/support/host_app.dart` wait up to 5 s of the test's clock for the screens the two host tests expect; 5× each under load pass, 329 phone tests, no expectation changed. Open: s8c, and the PRD M12 acceptance tests copied into the checklist |

## Delete

- none
