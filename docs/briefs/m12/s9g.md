job: m12 s9g G4 — the host-mode phone tests: no real I/O in the puzzle load
stop: after G4.
read: docs/briefs/m12/s9c-report.md · controller_app/test/{host_mode_test,host_lifecycle_test}.dart · controller_app/test/support/{host_app,pump_app}.dart · packages/puzzle_game/lib/src/{library,puzzle_module}.dart · packages/party_host/lib/src/providers.dart (`puzzleLibraryProvider`) · docs/coding-guidelines.md (tests)

why: after s9c, `host_mode_test` "a phone hosting plays its own game: the pad, the menus, and a solo Shape Race" still failed once in a full `tools/check.sh` on a quiet PC ("The puzzle screen did not show within 5 s", host_mode_test.dart:79); it passes alone 4/4 and on a rerun. The full phone suite runs its files in parallel, and the puzzle library still loads through real file/asset reads, which `until`'s 5 ms of real time per step can't wait out under load.

do: load the puzzle files once per test file before any test runs (a `setUpAll` that awaits the real load, or the parsed library from `puzzle_game`'s files), and override `puzzleLibraryProvider` (or the one the host screens read) with that ready value in the host-mode harness, so no test in these files waits on I/O mid-test. If other real async work remains on the path to `PuzzleScreen` (the in-process pairing, the session file), say what it is and give it the same treatment where the harness allows. Keep every expectation; change only how the harness supplies the data.
tests: none added or removed. Prove it: run the full `tools/check.sh phone` 5 times in a row and report each result (all must pass), plus the two files 5 times under the s9c load command.
in the report: what was loaded ahead and where, any other real async work found, the 10 runs.
rules: tests only; no lib change unless a provider can't be overridden (then say why first) · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s9g-report.md · controller_app/test
check: format analyze phone
report: docs/briefs/m12/s9g-report.md
