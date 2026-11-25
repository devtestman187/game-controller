# Review of wave 3 (c0b): hudRects plumbing

## Summary
Verdict: small fixes
Counts: must 0 · should 3 · could 3
1. **should** docs/briefs/m16/m165/c0b-report.md:18 the 640x360 computed room is wrong (300 px, not 308 px).
2. **should** docs/briefs/m16/m165/c0b-report.md:1 the report has no review-rules part A self-check (guidelines §11).
3. **should** docs/briefs/m16/m165/c0b-report.md:3 tests-first was skipped, and the report admits it.

## Findings
- **should** docs/briefs/m16/m165/c0b-report.md:18 The computed room for 640x360 is written as 640x300, but the room below the 52 px bar is 640x308, and 308/540 = 0.57037037 is the scale the report and the test use → change "640x300" to "640x308".
- **should** docs/briefs/m16/m165/c0b-report.md:1 The report has no answer to the review-rules part A self-check (every host setup, kept state, combinations, folder, stop, every look), which guidelines §11 requires one line each for → add the six lines, each with the test that shows it (for example A1: puzzle_module_test.dart phone vs screen; host_overrides shows empty in both branches).
- **should** docs/briefs/m16/m165/c0b-report.md:3 Brief step 1 (tests first, seen failing before the lib change) was not followed; the new tests (frame_view_test.dart:299-319, puzzle_module_test.dart:314-320, puzzle_pad_clearance_test.dart:129,148) are only shown to fail by compile error on the old code, so none is shown to fail for its own reason → the owner decides whether to accept this; if accepted, record it as a deviation in the status row.
- **could** packages/puzzle_game/lib/src/match_view.dart:163 The mirror-place call passes `padRects` to `PuzzleCamera.mirrorPlace` but not `hudRects`, so the whole-match mirror fit ignores the HUD rects (the chain from MatchView to PlayView to PhoneHud is otherwise complete) → confirm with b1 whether that is intended; the brief says no camera maths change in c0b.
- **could** controller_app/lib/src/host/host_overrides.dart:76 and :82 No test shows that the app's HostPad hudRects is empty in both branches; the brief asked for empty but no test pins it → add one in b1, when the lists are filled.
- **could** packages/party_host/lib/src/providers.dart:378 The file is at 378 lines, 2 short of the 380-line cap for a touched lib file; the next job that touches it should move the HostPad typedef out or split the file.

## Decisions to confirm
- puzzle_module.dart:151-153: hudRects shift up by phoneBarClearPx on a phone, as padRects does (c0b-report.md:8). Right if the app's bar sits above the game on a phone, as the report says; the test (puzzle_module_test.dart:314-320) pins 100 → 48.
- puzzle_pad_scale.dart:25-28: the HUD is asked about the same device box as the pad rects (c0b-report.md:10). Same box keeps both consistent; b1 must expect the same box.
- providers.dart:161 and host_overrides.dart:76-82: hudRects is always empty in the app for now (c0b-report.md:12). Intended per the brief; b1 fills it.

## Could not check
- Tests and analyze: not run, since this job is read-only. The report's claim "tools/mine.sh ... tests OK" is unverified.
- The red-first claim for the new tests: the old code was not run (the brief forbids changes), so the compile-error failures are inferred from the diff, not seen.
- The run-findings.md entry about c0b's report (no Summary block in the first 40 lines) is a format note; it is not a "passes on the old code" entry, so it is not counted above.
- Visual look (menu and TV) is not affected by this change (no widget size or paint change in the diff); not checked in a device run.

## Commit message
Review only: no code change to commit. If the owner accepts the wave, the commit is the c0b job's own commit (7a56815f); no new message is needed.

## Status row
wave3 review of c0b: small fixes found (0 must, 3 should, 3 could); open: c0b report's 640x300 room figure and missing part A self-check; owner decision on tests-first.

## Delete
- none
