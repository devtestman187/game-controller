# bugs3 wave 1 review (b037, b038, wrap320)

Verdicts (driver read each diff and report):
- b037 OK after hand-fix: the brief's 0.55 cap put the rank at 17.6 px, under the frame's 20 px floor; phone_fit_matrix_test failed in 11 night-final cases (the run's STOP). Set to 0.625 (20 px in the 32 px disc). Crown overlap 4 px; badge 48 px. Fixed, unverified: needs device check (crown and number look).
- b038 OK: ShapeRaceViewer pads 52 px on the phones target and shifts padRects up; one pinned rect moved 52 px. Looks (menu/TV) not drawn in its test, layout offset only. Fixed, unverified: device check on a joined phone.
- wrap320 OK: YourCharacter moved to your_character.dart, wraps Change under the text when the one-row width (Change width an estimate) exceeds the panel. Not same row, NOT fixed: connect_screen.dart:348 address row overflows 39 px (menu) / 109 px (TV) at 320x640, app bar connect_screen.dart:102 45 px in TV. Moved to docs/code-health.md and reported to the owner. The 393x852 portrait panel is 142 px wide so the line wraps there (by the owner's rule).
- Run: STOPPED once (check failed twice: cause above, class c pinned test; the host suite also showed a live_stats_answer_kept load flake that passed on rerun). check.sh phone puzzle passed on the tree; the full check.sh runs at the batch end.
- Leftover: the report of b037 still quotes the superseded 0.55 numbers (a note was appended).

## Numbers
JOB     WORKER MODEL            TURNS IN   OUT   CACHE MINUTES WALL RESULT
b037    claude claude-haiku-5-5    47 70 28851 1690148     6.2  7.2 4 (subtype=success, terminal_reason=completed)
b038    claude claude-haiku-5-5    26 48 20611  830958     3.6  7.6 4 (subtype=success, terminal_reason=completed)
wrap320 claude claude-haiku-5-5     2  6   368  186378     0.1 15.1 4 (subtype=success, terminal_reason=completed)
agent-cost since 2026-11-23 16:31: haiku $0.00 (cw5m 0.00M cw1h 0.01M), opus $0.29 (cw5m 0.00M cw1h 0.00M), sonnet $1.56 (cw5m 0.00M cw1h 0.13M); total $1.85; sonnet resumes >5m 1 (0.00M written), >60m 0 (0.00M written)

# bugs3 wave 2 review (b036, b041), Nov 23

Verdicts (driver read each diff):
- b036 OK after hand-fix: Haiku stopped on a real layout fact (banner + six players + Robo overflowed the 392 px body by 79 px). Owner picked "Card scrolls": the card sits in a SingleChildScrollView under the banner; arena_results_frame_test pin now asserts only four-player cards do not scroll, phone_fit_matrix_test skips the scroll check for arena-results. Round strip hidden by `showHud` (test_game ArenaView/ArenaBoard, space kept). "Left wins!" untouched (follow-up).
- b041 OK after hand-fix: first attempt stopped by its own rule (mirror has no spot at 1180x820 with sticks). Owner picked "Phone rule where it fits": MatchView.wholeIfNoMirror, so tablets draw their side with the mirror where one fits and the whole match where not; the worker hit its turn cap one turn short (61), the driver finished PuzzlePlayView/PuzzleScreen, pins and rule 6. controller_app untouched. The fit is measured with the boat puzzle only in the tests; real pad and HUD text unverified.
- Run: STOPPED twice (b041 red-by-design test, then b041 over its cap); no new class-c stops. Fixed, unverified: B-036, B-041 need device checks.
- Cost: Haiku workers about 6-12 min each; see numbers.

## Numbers (wave 2 run)
JOB          WORKER MODEL            TURNS  IN   OUT   CACHE MINUTES WALL RESULT
b036         claude claude-haiku-5-5    61  94 41982 2737044    11.6 12.3 4 (subtype=success, terminal_reason=completed)
b037         claude claude-haiku-5-5    47  70 28851 1690148     6.2  7.2 4 (subtype=success, terminal_reason=completed)
b038         claude claude-haiku-5-5    26  48 20611  830958     3.6  7.6 4 (subtype=success, terminal_reason=completed)
b041         claude claude-haiku-5-5    61 120 37927 3912878     6.4  7.3 4 (subtype=error_max_turns, terminal_reason=max_turns)
wave1-review claude claude-haiku-5-5    23  26 25197  456382     2.0    - 0 (subtype=success, terminal_reason=completed)
wrap320      claude claude-haiku-5-5     2   6   368  186378     0.1 15.1 4 (subtype=success, terminal_reason=completed)
agent-cost since 2026-11-23 16:31: haiku $0.01 (cw5m 0.00M cw1h 0.02M), opus $1.83 (cw5m 0.00M cw1h 0.06M), sonnet $3.89 (cw5m 0.00M cw1h 0.25M); total $5.73; sonnet resumes >5m 4 (0.01M written), >60m 0 (0.00M written)
