# s9g report — the host-mode tests read the puzzle files once, before any test (G4)

**Done.** Tests only: `controller_app/test`, no `lib/` change, no test added or removed, no
expectation touched. Both host-mode test files now read the puzzle library once in `setUpAll`, in
the real event loop, and the harness hands the app that ready library instead of letting a test
body start the reads mid-run. The 10 proof runs (5 full phone suites, 5 + 5 turns of the two files
under the s9c load command) all pass.

## What was loaded ahead, and where

`controller_app/test/support/host_app.dart`:

- `loadPuzzles()` (line 28) reads `PuzzleLibrary.load()` once and keeps it in `_puzzles`. It runs
  in `setUpAll`, which the test framework runs outside the test's fake clock, so the asset reads
  finish before the first test starts. It calls `TestWidgetsFlutterBinding.ensureInitialized()`
  first: `testWidgets` only does that when its own body starts, and `rootBundle` needs the binding.
- `pumpHostApp` (line 40) now takes the library from `_puzzles`; the throwaway
  `ProviderContainer().read(puzzleLibraryProvider.future)` per test is gone (it was real asset
  I/O in every test body: 9 in `host_mode_test`, 5 in `host_lifecycle_test`, so 14 reads per run
  of the pair).
- `puzzleLibraryProvider` is overridden with the ready value — `overrideWith((ref) => puzzles)`,
  as `packages/party_host/test/support/host_harness.dart:44` and
  `tv_test_app/test/support/pump_app.dart:60` already do — instead of `(ref) async => puzzles`.
  The async closure made the screens see `AsyncLoading` for at least one turn (a new future per
  container); now `ShapeRaceScreen`, `JoinScreen`'s title and `PuzzleScreen` read `AsyncData` on
  their first build and have nothing to wait for.

`controller_app/test/host_mode_test.dart` and `host_lifecycle_test.dart`: `setUpAll(loadPuzzles)`
as the first line of `main()`.

Proof that the preloaded path is the one these two files use: I temporarily replaced the fallback
in `pumpHostApp` with `fail('TEMP fallback used')`, ran both files — 14/14 still passed, so
neither test reached the fallback — and ran `diagnostics_test` — its 3 hosting tests failed, so it
is the only other file on the fallback. The temporary edit is reverted (the fallback is back).

The fallback (`_puzzles ?? await tester.runAsync(PuzzleLibrary.load)`) stays so
`diagnostics_test`, which uses the same harness but was not in this brief, keeps working unchanged.
See Q1.

## Other real async work found on the path to `PuzzleScreen`

- **The own player's pairing — kept, and it cannot move to `setUpAll`.** `HostingNotifier.start()`
  → `PhoneHost.start()` → `LiveHostService.start()`: creates the sessions folder
  (`_stats.start(await _directories.sessions())`, real file I/O in the test's temp folder), starts
  the server, reads the addresses, advertises; then `client.connect(...)` over `InProcessLink`,
  which is non-sync `StreamController`s in this process (microtasks only, no socket, no timer). A
  host is built inside the widget tree for each test, so no file-level setup can do it; the
  harness already waits for it in `hostReady` (`until(host.client.snapshot.isConnected)`), which
  gives the real event loop 5 ms per step.
- **The session file — kept, off the path.** `LiveStats` writes the session at its one-minute
  checkpoint and at session end (`host.dispose` in each test's teardown). Nothing on the way to
  `PuzzleScreen` waits on it.
- **The game module's own puzzle load — still real, and not reachable from a test.**
  `packages/puzzle_game/lib/src/puzzle_module.dart:142` `_puzzleLoad` is a private module-level
  `Future<PuzzleLibrary>?` that `_LoadedPuzzle.build` (line 155) starts the first time a viewer
  draws. It is a second read of the same asset files, started inside the round (after
  `PuzzleScreen` is up), and it has no provider, constructor or interface seam — no test can
  prewarm or override it, and changing that is a `lib/` change, which the brief rules out unless a
  provider can't be overridden. It gates only the board: the viewer shows `SizedBox.shrink()`
  until it loads, while the pad's "A Pick up" layout comes from `PuzzleSession`
  (`puzzle_session.dart:121`), and no test in these two files expects the board. So no test here
  waits on it. See Q2.
- **Not I/O, but the other real-time window on the path: the press.** `ServerGameHost.minPressMs`
  is 50 ms of the host's real clock (`server_game_host.dart:33`); a press the menus don't read
  inside that window is gone. The two `pressA` calls that join and start have no wait between them
  (`host_mode_test.dart:77-78`, `host_lifecycle_test.dart:117-118`), so if the first is lost the
  second joins instead of starting and the old failure ("The puzzle screen did not show within
  5 s") comes back. That is not the puzzle load, and this job left it as it is (see Q3).

## Runs

1. Full phone suite, `tools/check.sh phone`, final code — PASS 6/6: 329 tests each, at 14:30:03
   (sanity run, 18 s), then 14:30:25 (17 s), 14:30:44 (18 s), 14:31:04 (18 s), 14:31:24 (19 s),
   14:31:44 (20 s).
2. The two files, 5 times each, under the s9c load command from `controller_app`
   (`flutter test --concurrency=16 test/<file> ../packages/connection/test`, so the connection
   package's 251 real-socket tests run in 16 parallel suites alongside):
   - `host_lifecycle_test`: PASS 5/5 at 14:32:08, 14:32:27, 14:32:46, 14:33:05, 14:33:24; each
     `00:11 +256: All tests passed!` (5 host + 251 connection).
   - `host_mode_test`: PASS 5/5 at 14:33:44, 14:34:04, 14:34:24, 14:34:44, 14:35:04; each
     `00:11 +260: All tests passed!` (9 + 251).
3. Both files together, `flutter test test/host_mode_test.dart test/host_lifecycle_test.dart` —
   `+14: All tests passed!` (5 s), and again `+14` with the fallback replaced by `fail(...)` (see
   above).
4. Final `tools/check.sh format analyze phone` — PASS, PASS, PASS, 329 tests (14:35:37).
5. `tools/review.sh` — 0 fail, 0 note.

I did not reproduce the Nov 7 failure before the change: the workspace was quiet and the flake
needs load. What the change proves is the premise it was written for — no test in these two files
starts a real read of the puzzle files while it runs — and 10 loaded runs passed.

## Values

No test value changed: 329 phone tests before and after; `host_mode_test` 9 tests,
`host_lifecycle_test` 5, `connection` 251 (hence +260 and +256). Reads removed from test bodies:
14 per run of the pair (9 + 5), replaced by 2 (one per file, in `setUpAll`).

## Files changed

- `controller_app/test/support/host_app.dart` — `_puzzles` + `loadPuzzles()`; `pumpHostApp` uses
  the preloaded library (with the old real-loop load as its fallback); the
  `puzzleLibraryProvider` override is now the ready value instead of an async closure.
- `controller_app/test/host_mode_test.dart` — `setUpAll(loadPuzzles)` and a two-line comment.
- `controller_app/test/host_lifecycle_test.dart` — the same.

## Questions and suggestions

1. **Q1 — the fallback in `pumpHostApp`.** `_puzzles ?? await tester.runAsync(PuzzleLibrary.load)`
   keeps `diagnostics_test` (not in this brief) working as it was, but it also means a file that
   forgets `setUpAll` silently pays the old cost. The other way is to fail in `pumpHostApp` when
   nothing is preloaded and add `setUpAll(loadPuzzles)` to `diagnostics_test` too. I took the
   no-new-file route because the brief named two files; say which you want.
2. **Q2 — the module's own load.** `_puzzleLoad` in `puzzle_game` is the last real read on the
   round's path and the only one no test can reach. A lib change could give it a seam (a provider
   or an injected loader in `ShapeRaceViewer`); the brief bans that unless a provider can't be
   overridden, and this one isn't a provider at all, so I left it and report it.
3. **Q3 — the press chain.** If the flake returns, look at `pressA` twice with no wait between
   (join, then start) and at `minPressMs` = 50 ms real against slow frames: that loses a press
   regardless of the puzzle files. s9c's suggestion 3 asked for every press to wait for its
   observable result; these two files could do it without changing an expectation (wait for the
   joined label, then press again). That is a separate brief.
4. **Suggestion.** If Q1 goes the strict way, `diagnostics_test` gains one line and every host
   test file reads the puzzles the same way.

## Commit message

tests: read the puzzle files once per host test file (s9g)

The two host-mode test files read the puzzle library in every test
body (asset I/O in the test's fake-clock zone) and overrode
puzzleLibraryProvider with an async closure, so the host screens
waited a turn on AsyncLoading before their lists.
loadPuzzles() now reads them once in setUpAll, in the real event loop,
and pumpHostApp hands the app the ready PuzzleLibrary with a sync
override; a file that skips setUpAll still gets the old load.
No test, expectation or value changed; 5x phone suite and 5x each file
under load pass.

## Status row

| 9 Docs and device tests | … **s9g done** (`s9g.md`): both host-mode test files read the puzzle library once in `setUpAll` (`loadPuzzles()` in `test/support/host_app.dart`) and `pumpHostApp` overrides `puzzleLibraryProvider` with the ready library, so no test waits on the puzzle files mid-run; 5× the full phone suite (329 tests) and 5× each file under the s9c load command pass, no expectation changed. Open: the game module's own private puzzle load (`_puzzleLoad`, needs a lib seam), s9f, and the PRD M12 acceptance tests copied into the checklist |

## Delete

- none
