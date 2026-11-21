# Wave 2 review (S2, S7) — findings only

## Summary

Verdict: **small fixes**.

0 must, 2 should, 6 could. Both jobs stayed in `allow:` (`git show --stat`: S2 six paths, S7 three), `dart format
--set-exit-if-changed` on the five changed Dart files reports 0 changed, and every number in s7-report.md's two
tables matches s7-results.json (all 20 records checked: scroll extent, content, way-on rects, smallest type).

- S2's report says the tests assert "chip 48 px inside the 64 px header" (s2-report.md:65); nothing reads the chip's
  height, and the segment is only tested in a plain `Center`, never in a header.
- Two behaviours S2 chose in its Decisions have no test: `delta == 0` hides the `+n` (score_row.dart:117) and
  `maxPoints == 0` draws an empty bar (:128), so a change to either passes.
- S7's "smallest text" counts only text drawn as a `RenderParagraph`; the join screen's badge numbers are painted
  (36 x 0.55 = 19.8 px, so above the 15 px body and the verdicts hold), but the report's sentence is wider than its
  method.

## Findings

- **should** docs/briefs/m16/phonehost1/s2-report.md:65 the report's "what the tests assert" line claims a 48 px chip inside the 64 px header, but `host_frame_screen_test.dart` never reads `roundChipHeightPx` and tests `RoundSegment` only in a bare `Center`, so the chip's fit in the header could regress unnoticed → add a test that a `RoundSegment` in a `HostFrameScreen` header is 48 px tall and the header still 64, or drop the claim.
- **should** packages/party_host/lib/src/ui/score_row.dart:117 the zero-delta rule (Decision 6) and the `maxPoints == 0` empty bar (:128, Decision 5) have no test, so a row that draws "+0" or a bar that divides by zero would still pass → add a card row with `delta: 0` (assert no "+0", no exception) and a card with `maxPoints: 0`.
- **could** packages/party_host/lib/src/ui/round_segment.dart:97 a segment built with `onChanged: null` (Decision 8, "a night already under way") is untested: no test taps or activates a disabled chip and asserts nothing happens → add a test with `onChanged: null` that taps and presses Enter and asserts no callback and no focus.
- **could** packages/party_host/lib/src/ui/round_segment.dart:90 the `Semantics(button: true)` has no `onTap`, and the tap handler sits under `ExcludeSemantics` (:94), so a screen reader (TalkBack on a phone host) finds a button that cannot be activated → pass `onTap: onPressed` (null when disabled) to the `Semantics`.
- **could** packages/party_host/test/host_frame_screen_test.dart:34 the test restates the frame's heights as bare `64`/`84` (and the doubled gutter as `48` at :242), which the guidelines' magic-number rule rules out → use `hostFrameHeaderHeightPx`, `hostFrameFooterHeightPx` and `2 * hostFrameGutterPx`.
- **could** packages/party_host/test/host_frame_screen_test.dart:178 the brief asks for "title left", but the test only checks the title's size and presence, so a centred title would pass → assert the title's rect `left` is `hostFrameGutterPx`.
- **could** docs/briefs/m16/phonehost1/s7-report.md:13 "the smallest text is 10.0 dp" is true only of paragraph text: `measureScreen` walks `RenderParagraph`s (phone_fit_support.dart:333), and the join screen's badge numbers are painted (toy_badge.dart:50), so a smaller painted number would go unreported → say the figure covers paragraph text, or add the painted badge size to the method.
- **could** packages/party_host/test/phone_fit_picker_join_test.dart:71 `tearDownAll` writes the results file whenever `_results` is non-empty, so a run in which one of the 20 cases fails silently replaces the committed JSON with a partial one → write only when all 20 cases ran (check `_results.length`) and leave the old file otherwise.

## Decisions to confirm

- S2's scaffold takes widgets for the footer and its chip is not a `ToyButton` (Decisions 1, 7), so inside the frame a phone look's `ToyButton` still draws 18 px labels under the 20 px floor until DESIGN section 5's "the look picks `frame`" wiring exists (S2 report, open question 5) — S3-S6 will hit it; the owner should say where that wiring lands.
- S2's bar takes all the slack and fills by `points / maxPoints` (Decision 5), while DESIGN rule 4 writes "bar (width = points)" — S4/S6 build on this reading, so confirm it.
- S2 puts the 24 px gutter in the scaffold and makes it a `Scaffold` (Decisions 2, 3): S3-S6 must then drop their own padding and scaffold; confirm that is the contract.
- S2's four open questions (safe area inside the frame, a footer band, a taller winner row, ink vs `onBackground` on the sky) are design calls for S4/S6, not code defects.
- S7 measured the picker's way on as its first game card only; `pickArena` and `pickPartyNight` live in the same list and were not checked — confirm that is enough for S8, and that the join screen with nobody joined (the tighter case) can wait.

## Could not check

- `tools/check.sh` and `tools/review.sh`: not run here (read-only job); the job log says both workers exited 0.
- The `host` suite, and whether S7's always-on test (20 app mounts, one file written into `docs/`) disturbs another test: not run, so that side effect is unverified.
- `run-findings.md`: there is none for `phonehost1`; the log says only that `host_frame_screen_test.dart` fails on the old code and that the picker/join test is exempt.
- A real phone with a screen reader (the Semantics finding) and the two apps at 640x360 (S2's widgets are unused): reasoned from the code, not run.

## Commit message

Add the wave2 review of S2's frame scaffold and S7's picker/join measurements

- S2 and S7 meet their briefs and stay in `allow:`; findings only, no code change.
- Two shoulds: S2's report claims a chip-height assertion the test file does
  not have, and the delta-0 and maxPoints-0 paths of ScoreRow are untested.
- Six coulds: an untested disabled segment, a Semantics button with no tap
  action, bare 64/84/48 in the test, an unasserted "title left", S7's
  paragraph-only "smallest text", and a results file rewritten on a partial run.
- Decisions for the owner: the look's frame wiring under the footer's
  ToyButtons, the bar's fill reading, and the scaffold's gutter/Scaffold contract.

## Status row

Wave 2 reviewed: S2 (HostFrameScreen, ScoreRow + ScoreRowData, RoundSegment + RoundOption, 23 tests, exported, unused) and S7 (picker and join screen measured at five sizes in both layouts, 20 cases, results JSON) are done and pass their tests; open — 2 shoulds and 6 coulds from this review, and the decisions above.

## Delete

- none
