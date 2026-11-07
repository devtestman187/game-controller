job: m12 s9c G4 — make the host-mode phone tests wait for what they expect, not a fixed time
stop: after G4.
read: controller_app/test/host_lifecycle_test.dart · controller_app/test/host_mode_test.dart · controller_app/test/support (host_app.dart, pump_app.dart) · docs/coding-guidelines.md (tests)

why: three times on Nov 7 (s7b's check with the emulator running, s9b's check with another job running) two tests failed only when the PC was busy: `host_lifecycle_test` "a round hidden longer than the grace is abandoned: back to the game picker" (no `PuzzleScreen`) and `host_mode_test` "a phone hosting plays its own game…" (no `JoinScreen`). Both pass alone. The puzzle files load asynchronously, so a fixed number of pumps can end before the screen is up. CI would hit the same.

do: in those two files (and any helper they share), replace each wait for a screen that depends on real async work (the puzzle library load, the host's start, the in-process pairing) with a helper that pumps in small steps until the finder matches, with a generous limit (say 5 s of fake time and a real-time cap via `tester.runAsync` if the work is real I/O), failing with a clear message naming what it waited for. Keep every expectation's value; change only how long the test waits.
tests: no test added or removed; all expectations unchanged. Prove it: run the two files 5 times each in a row while `flutter test` of another package runs at the same time (any heavy package, e.g. packages/puzzle_game), and report the results.
in the report: the helper, the waits replaced (file:line), the 5× results under load.
rules: tests only; no lib change · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s9c-report.md · controller_app/test
check: format analyze phone
report: docs/briefs/m12/s9c-report.md
