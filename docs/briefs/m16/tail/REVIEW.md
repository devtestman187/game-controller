# m16 tail: the run's review (cbfe93da..53040dfe)

## Summary
- Verdict: **one fix batch** (finding 1 needs the lobby check named under Open questions before its job is written).
- Counts: must 0 · should 5 · could 7.
- Wave (numbers = bullet order in Findings; phone-pinned unless noted): job A = 1, 2, 3 (controller_top_bar.dart, pad_mode_view.dart, stick_widgets.dart, bar_start_test.dart); job B = 5, 9, 10 (mirror_corner_proof_test.dart, mirror_proof_test.dart, right_pad_rects_test.dart, a support file); job C = 8 (host_frame_wiring_test.dart); doc job = 4 (s1-report.md, no phone). Left for when touched, because they share a file with A or B: 6 (joined_view.dart, mirror_proof_test.dart), 7 (controller_top_bar.dart), 11 (bar_start_test.dart), 12 (controller_screen.dart).
- Hand-fixes: none (`run.log` has no HAND-FIX line). Tests-first: m1 exempt by its brief; s1's `bar_start_test.dart` fails on the old code (run.log 11:30:19); s2's 8 count pins failed before the lib change (s2-report).
- Reports: `m1-report.md`, `s1-report.md`, `s2-report.md` exist. No per-job `*-review-report.md`, no STATUS.md, no REVIEW-VERDICTS.md. run-findings.md (one line, s1 has no Summary) still holds.
- Unverified fixes, to mark "Fixed, unverified: needs device check": the Start-in-bar change (s1) and the rightPadRects change (s2). Neither was run on a phone; the host_frame_wiring pin (644, 6, 740, 50) was copied from a failing run.
- Top five:
  1. Hosting phone: the bar's Start follows the round phase, the pad's Start follows `showsGameProvider`, which is true for the whole hosting session, so the lobby may show no Start.
  2. No test covers "Show on this device" or the hosting branch of the bar, the A1 host setups.
  3. No test covers Start over the pause menu, a dropped link, or "Get ready" (A3).
  4. s1-report.md has no Summary and no part-A self-check.
  5. The mirror-corner test prints its table with stdout, which the no-print rule forbids in tests.
- Questions only the owner can answer: the PRD wording of "Start stays on screen" (s1); whether 16/18 at 956x440 (option A) instead of 17/18 is acceptable; which mirror count is the target (game box or whole screen); whether a device check of the bar Start is wanted before the next build.

## Findings
- **should** `controller_app/lib/src/ui/controller_top_bar.dart:26-36` and `controller_app/lib/src/ui/pad_mode_view.dart:40` / `stick_widgets.dart:68`: a hosting phone's bar keys on `roundPhase` (line 26-33) while the pad pill keys on `showsGameProvider`, which `hosting.dart:45` sets true at start and `hosting.dart:63` clears only at stop; in the lobby (phase none) the pad hides Start and `_ControllerTopBar` has none → gate the bar and the pad on one signal (or confirm the lobby layout hides Start) and add a hosting-lobby test. (from: s1)
- **should** `controller_app/test/bar_start_test.dart:45-111`: no test for "Show on this device" (`controls` false, `controller_top_bar.dart:68`) or for the hosting branch (`controller_top_bar.dart:26-33`), so finding 1 is untested → add both cases. (from: s1, review-rules A1)
- **should** `controller_app/test/bar_start_test.dart:45-111`: no test for Start over the pause menu, a dropped link, or "Get ready" (A3 pairs; the s1 report does not list them as untested) → add the pairs or write "not tested" in the report. (from: s1, review-rules A3)
- **should** `docs/briefs/m16/tail/s1-report.md:1-32`: the report has no `## Summary` and no part-A self-check (review-rules A asks one line per item) → add both. (from: s1; run-findings.md)
- **should** `controller_app/test/mirror_corner_proof_test.dart:223-244`: the test writes its table with `stdout.writeln`, which the no-print rule forbids in tests → move the table writing to a `tools/` script or keep only the assertions and record the numbers in the report. (from: m1)
- **could** `controller_app/lib/src/ui/joined_view.dart:86-87` and `controller_app/test/mirror_proof_test.dart:233`: "since Nov 26" dates a code comment and will go stale → say "since the game bar took Start (m16 tail s1)". (across jobs)
- **could** `controller_app/lib/src/ui/controller_top_bar.dart:90`: the 96x44 size is SmallButton's default (`pad_widgets.dart:278`), not passed explicitly as the s1 brief asked; the test guards it, but a default change would silently resize the bar button → pass `size: Size(96, 44)` at the call. (from: s1)
- **could** `controller_app/test/host_frame_wiring_test.dart:208`: the pin `Rect.fromLTRB(644, 6, 740, 50)` was copied from a failing run; derive it from the bar's padding and `topBarHeightPx` so the pin says why. (from: s1)
- **could** `controller_app/test/right_pad_rects_test.dart` (`startOf`), `controller_app/test/mirror_proof_test.dart:235-238`, and `controller_app/test/mirror_corner_proof_test.dart:72-81`: three jobs recompute the right-hand and Start geometry → one helper in `test/support/`. (across jobs)
- **could** `controller_app/test/mirror_corner_proof_test.dart:28` (and the same path in `mirror_proof_test.dart`): the relative `../packages/puzzle_game/puzzles` path is hard-coded in two tests → one constant in a shared support file. (across jobs)
- **could** `controller_app/test/bar_start_test.dart:65`: `pump(Duration(seconds: 2))` is a fixed wait with no reason stated → pump until the mode's pad is built, or name the wait in a comment. (from: s1)
- **could** `controller_app/lib/src/ui/controller_screen.dart` (367 lines, limit 380): s1 added two imports; the next job that touches it must split the file first. (across jobs)

## Open questions
1. Is "Start stays on screen in every mode" in the PRD? s1 found it nowhere in controller_app. Suggested: if it is in the PRD, reword it to "Start stays on the pad outside a game and in the bar over one".
2. Accept option A's 16/18 at 956x440 against today's 17/18? Suggested: accept only if the owner also accepts that the spot sits beside the bar; otherwise keep today's spot (m1-report.md, GATE line).
3. Which mirror count is the target: the game-box count (m1: 17/18 today, 16/18 option A, 1/18 both at 667x375) or the whole-screen count (s2 and REPORT.md:75: 14/18, 3/18)? Suggested: the game box, since that is what the game draws. m1 matched REPORT.md by its numbers and did not open the file (m1-report.md:119).
4. Does a hosting phone's lobby layout already hide Start? This decides finding 1. Suggested: gate both on one signal regardless of the answer.
5. Should the bar Start get a device check at 568x320 before the next build? Suggested: yes; the s1 and s2 changes are tested only.

## Numbers against targets
- Bar Start touch target (s1 brief): at least 96 x 44 at 568x320, 667x375, 956x440, menu and TV looks. Met by the 14 tests in `bar_start_test.dart` (report: all pass); not measured on a device.
- Mirror, option A, game box (m1, sticks): 956x440 placed 16/18 against today's 17/18 (one fewer); 667x375 1/18 against 1/18. The brief gives no target to compare with, and STATUS.md does not exist.
- Mirror, whole-screen count after s2 (`mirror_proof_test` measure): 956x440 14/18, 667x375 3/18. Before s2 was not captured (s2-report), so the effect of dropping Start from `rightPadRects` on placement is unmeasured.
- Strip room at 956x440: 118.6 px (s2). No target stated.

## Could not check
- Whether the hosting lobby layout hides Start (finding 1): needs the TV's layout messages, not readable here.
- Any device behaviour: nothing was run; the touch target and the HUD are checked by tests only.
- The PRD rule text (open question 1): not searched outside controller_app.
- I ran no checks: read-only review, and the job reports' results are taken as stated.

## Commit message
docs: m16 tail run review, one findings list

Reads the run's commits (cbfe93da..53040dfe) as one change against the
coding guidelines and review rules. Five should and seven could findings
are listed in docs/briefs/m16/tail/REVIEW.md, with a three-job fix wave
and the open questions for the owner. No code changed.

## Status row
m16 tail run review: done, one fix batch (5 should, 7 could); open: hosting-lobby Start gate (finding 1, needs the lobby check), two Start-in-bar changes need a device check, owner questions 1-5.

## Delete
- none
