# n8c review: coach marks overlay (read-only)

## Summary
- Verdict: needs Claude
- Counts: 2 must, 4 should, 5 could
- 1. The brief says "Tests FIRST"; the report says the tests were written together with the widget, and no red run is shown (n8c-report.md:20).
- 2. The report has no part A self-check and no format, analyze or test results, though the brief lists `check: format analyze` (n8c-report.md:1).
- 3. The report's 568x320 TV values (124 dp below, 76 dp above) do not match the code, which gives 100 and 100; the box is never re-read when an anchor moves on its own (coach_marks.dart:133).

## Findings
- **must** docs/briefs/m16/wave2-789/n8c-report.md:20 The report admits the test file was "written together with the widget", against the brief's "Tests FIRST" (n8c.md item 3) and guideline §9; its claim that the file "could not fail on older code" is not a check → record the red run (tests against an empty or stub CoachMarks) with its output, or state that tests-first was not done.
- **must** docs/briefs/m16/wave2-789/n8c-report.md:1 The report has no part A self-check (six lines, each with its test), and no results for `format` and `analyze` (named in the brief's `check:` line) → add the six lines with their tests and the format and analyze results.
- **should** docs/briefs/m16/wave2-789/n8c-report.md:15 The 568x320 TV step-2 values "124 dp below, 76 dp above" do not match the code: the hole is 128–192 dp (anchor 136–184 inflated by 8, coach_marks.dart:149), so roomBelow = 320−16−192−12 = 100 and roomAbove = 128−16−12 = 100 (coach_marks.dart:221–222) → correct the two values; the box height 135 and its rect do match.
- **should** controller_app/lib/src/home/coach_marks.dart:133 The anchor is read only inside `build` (`_scheduleRead()`), so an anchor that moves without a rebuild of CoachMarks is never re-read; the brief asks for a re-read on layout change and report line 8 says "re-read on every build" → read the anchor on each layout change (for example a listener on the anchor's RenderBox), or state the limit in the report; add a test that moves the anchor.
- **should** controller_app/test/coach_marks_test.dart:186 No test checks the box's side: nothing asserts the box is above the hole when there is no room below, or that the arrow is drawn when there is room (the placement is at coach_marks.dart:223 and :242–246), so a regression there passes → add a step-3 test (bottom-right anchor) asserting the box's bottom is above the anchor's top, and an arrow-present test at 640x360.
- **should** controller_app/test/coach_marks_test.dart:120 No test unmounts CoachMarks while a read is pending; the post-frame callback (coach_marks.dart:82) is guarded only by `mounted` (line 89) and nothing proves that → add a test that pumps a frame, unmounts, pumps again, and expects no exception and no onDone or onSkip call.
- **could** controller_app/lib/src/home/coach_marks.dart:136 `LayoutBuilder` ignores its constraints and shadows `context`; its rebuild does not schedule a read (that happens only in `build`, line 133) → remove the wrapper and return the Stack from `build`.
- **could** controller_app/lib/src/home/coach_marks.dart:34 The public constructors of `CoachStep` and `CoachMarks` (line 51) have no dartdoc → add one line to each.
- **could** controller_app/lib/src/home/coach_marks.dart:352 The file is 352 lines, past the ~300 target (hard limit 400); `_HintBox` (line 311) and the arrow (line 253) are separate responsibilities → split when next touched, or record in code-health.md.
- **could** controller_app/test/coach_marks_test.dart:31 `pumpMarks` takes six parameters (tester plus five named), above the limit of five → group screen, look and text scale into a value object.
- **could** controller_app/lib/src/home/coach_marks.dart:122 The once-only guard in `_finish` is not tested: no test taps again after onDone or after Skip and expects the callback to stay at one → add one test.

## Decisions to confirm
- The 568x320 TV look: the box lies over the lit anchor and the arrow is dropped (coach_marks.dart:241–244; report line 12). The brief asks for an arrow and a box below or above the anchor. Why: there is no room either side, so the hint covers the thing it points at.
- With no anchor found, the tips are silently skipped and `onDone` fires with no tip shown (coach_marks.dart:95–96; test at coach_marks_test.dart:176). Why: a caller that sets a "seen" flag on onDone would mark tips as seen that the user never saw.
- A tap on the scrim advances (coach_marks.dart:142), as the brief says; the report (line 24) notes that an accidental tap advances too.
- The hole's corner radius is `ToySizes.cardCorner` (coach_marks.dart:150), not in the brief or the report. Why: it matches the card corners.
- The 360 dp maximum box width (coach_marks.dart:26) and the 8 dp hole padding (line 19) are chosen values, listed in the report, not from the brief or the PRD.

## Could not check
- I did not run `flutter test`, `dart analyze` or `dart format`: this review changes no code and writes no build output, so the claimed results are unverified. The two must findings rest on the report and the diff alone.
- The `Path.from(sides)` call (coach_marks.dart:290) and the `ToySizes` members `space8`, `space12` and `space16` (toy_look package) were not checked against the Flutter and toy_look APIs.
- Whether the 1.3x text box fits at 320x640 in the TV look was not computed; the report gives no value for it.
- Whether run-findings.md exists for this job: it is not in docs/briefs/m16/wave2-789/, so there are no run findings to check.

## Commit message
docs: n8c review report for coach marks overlay

Read-only review of the n8c job (coach_marks.dart, coach_marks_test.dart)
against the coding guidelines, review rules and the n8c brief. Findings:
2 must, 4 should, 5 could. The job's report has no part A self-check,
no format or analyze results, and no tests-first run; the TV 568x320
values in the report do not match the code. No code changed.

## Status row
wave2 n8c review: done (needs Claude): 2 must, 4 should, 5 could; open: tests-first run, part A self-check, corrected TV values, anchor re-read on layout change, dispose and box-side tests.

## Delete
- none
