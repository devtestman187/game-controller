## Summary

Verdict: small fixes (no lib change in the job; lib is clean in the worktree).
Counts: must 0 · should 4 · could 6.
1. The right-side tests (present_phone_test.dart:84-88) have no failing mutation on record, so they are unproven.
2. The job's helpers `board` and `frame` are copied from present_wiring_test.dart:17-31 instead of shared.
3. Only the `sunny` look is tested (present_phone_test.dart:71), and the report's A6 line admits it.

## Findings

- **should** packages/puzzle_game/test/present_phone_test.dart:19 `board` and `frame` (line 31) are copied verbatim from present_wiring_test.dart:17-31 → move both into one file under test/support/ and import it from both tests.
- **should** packages/puzzle_game/test/present_phone_test.dart:84 the two "shows the right side" tests are never shown to fail; the report's mutation removes `present: s.present` at match_painter.dart:193 only, which never tests a present drawn on the wrong board → add a temporary mutation that passes `present` to every board, record which tests fail, then restore.
- **should** packages/puzzle_game/test/present_phone_test.dart:71 `look: sunny` is the only look; review-rules A6 requires UI sizes under the menu and TV looks → loop the tests over both looks, or record the gap as open in the status row.
- **should** docs/briefs/m17/race1b/f2-report.md:25 self-check A1 says "the phones target only (a phone on 'Show on this device' / joined phone)", but no test uses a host setup (the test builds `MatchView` with `LayoutTarget.phones`) → say "draws the phones target only; host setups not tested".
- **could** packages/puzzle_game/test/present_phone_test.dart:43 the doc says the helper returns "the bytes … whose colour differs", but it returns a count of differing pixels → "The number of pixels of [bytes] whose colour differs from [plain]'s."
- **could** packages/puzzle_game/test/present_phone_test.dart:46 `at += 4` is a bare magic number → a named `rgbaBytesPerPixel = 4` used in the loop and the doc.
- **could** packages/puzzle_game/test/present_phone_test.dart:30 and :52 "with [present] out (or none)" is ambiguous (out = drawn or absent?) → "with no present when [present] is null".
- **could** packages/puzzle_game/test/present_phone_test.dart:77 and :84 `$size` prints "Size(852.0, 393.0)", so the six test names differ only by numbers and one says "a phone at Size(...)" → name the group by `iphone`, `portrait`, `phone169`.
- **could** packages/puzzle_game/test/present_phone_test.dart:41 `showing(side)` only wraps `PuzzleCamera.side(side)` → call `PuzzleCamera.side` directly.
- **could** docs/briefs/m17/race1b/f2-report.md:14 "exact counts were not printed" → print the changed-pixel count for each size and the two expectations (guidelines §9 asks for every computed value).

## Decisions to confirm

- Portrait `Size(390, 844)` is a literal in the test (present_phone_test.dart:16) because the brief's "iphone about 390x844" does not match mirror_helpers' `iphone` (852x393, landscape). Confirm the literal stays, or add a named portrait size to mirror_helpers.
- Helpers were copied, not shared (see finding 2). Confirm whether copying is accepted.
- `sunny` only (see finding 3). Confirm whether a second look is in this job or a later one.
- `MatchView` is used instead of the brief's `PuzzleMatch` + `MatchPainter` (brief item 1). The phone path is the one the app takes, so this looks right; confirm it is accepted as a brief change.

## Could not check

- Brief item 2 (mutation): not re-run here (I may not edit lib). The report's result is taken as stated.
- Runner evidence: run-findings.md has no entry for f2 (its one line is about f1), so no "passes on the old code" finding from the runner.
- Tests were not run by me; the "6 tests pass" and "mine.sh OK" lines are the worker's claims.
- Whether a phone can show both sides (`camera.side == null` with a split frame, match_painter.dart:170-171) is reachable in the app; no test covers it, and the present would be drawn on each side's painter at line 193.
- A3 combinations (pause, "Get ready", host away, leaving) are not judgeable from a draw-only test; the report says they are not covered, which is accurate.
- The brief said "Report only … nothing else", but the task asks for the three closing sections below; they are included.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

review: wave4 f2 (phone-path present), no lib change

Reviewed the f2 job (present_phone_test.dart, c478bb6d) against the coding
guidelines, review rules, its brief and report. No must findings. Four should
findings: duplicated test helpers, right-side tests without mutation evidence,
a single look, and an overstated A1 self-check. This review changes no code.

## Status row

race1b wave4 f2 reviewed: 0 must, 4 should, 6 could (small fixes). Open: helpers shared, right-side mutation, second look, A1 wording.

## Delete

- none
