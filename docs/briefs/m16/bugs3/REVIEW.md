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
