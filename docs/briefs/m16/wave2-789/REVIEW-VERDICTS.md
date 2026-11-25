# Verdicts (driver)
## wave 1
- n8a-report.md:29 A4 wording vs reverted churn - invalid (the 22 files are known churn PNGs and generated plugin files the runner drops; no job file touched) - none
- home_prefs.dart set(bool show) - trivial - fixed by hand (shouldShow)
- home_contract.dart anchors, home_prefs showTipsProvider dartdoc - trivial - fixed by hand
- home_text.dart per-constant dartdoc - minor - code-health
- no whole word TV test on HomeText - minor - covered by the TV-word guard test at the end of the run
- n9e (Resume already `good`, Quit also `good`) - decision: keep (a), host card needs no change; the phone Start pill in the player colour is job n9e2
- n9b1 not reviewed (parked, applied after the review brief was cut)
## wave1-n9b1 (test touch_targets_test.dart)
- :94 bare 0.01 - must - fixed in n9b2 (touchRoundingSlackDp)
- seenBelow48 run-order dependence - should - fixed in n9b2 (map empty, check removed)
- Settings measured over Connect; portrait pad asserts nothing; n9b1-report self-check lines; chip cited line; main() 51 lines - minor - docs/code-health.md (not done: recorded here)
- decision list (568x320 TV exclusion wider than the pad; hosts covered) - accepted: phone only, host setups out of scope
## wave2 (n8b0 n9sr n8c; review file wave2-n8c-review-report.md)
- n8c-report.md:20 tests-first admitted not done - must(doc) - f1 item 3 states it plainly
- n8c-report.md:1 no self-check, format/analyze results - must(doc) - f1 item 3
- n8c-report.md:15 wrong 124/76 values - should - f1
- coach_marks.dart:133 anchor read only in build - should - f1 item 1
- coach_marks_test.dart missing box-side/arrow, unmount, once-guard tests - should - f1 item 2
- LayoutBuilder shadows context - could - f1 (builder now uses its constraints); constructor dartdoc - trivial - f1
- coach_marks.dart 352 lines, pumpMarks 6 params - minor - code-health
- decision: no anchor found makes onDone fire with nothing shown - n8d1 must not mark tips seen unless the marks were mounted (wire CoachMarks only while every anchor is laid out)
- decision: 568x320 TV look box over the anchor without arrow - accepted
## wave3 (n8b1 n9b2 n9b3): review at the next pause/end
## wave 3 review (wave2-review-report: n8b0 n9sr; file name is the wave-2 number) - final
- n9sr: round label only on the one-board painter, split and phone HUDs show none - should - OWNER QUESTION (n9sr-report Q1: is the label wanted on the split/phone screens); parked in REPORT.md
- n9sr: no PuzzlePlayView test for the both-set rule - minor - docs/code-health.md
- n9sr/n8b0 report wording (draft says unchanged/owner decision/clean) - trivial - reports left; n8b0 flow tests (host_mode_test, host_start_log_test) are run by the full check at the end
## wave 4 (f1 n8d2 n8b2 reviews)
- coach_marks.dart:134 item 1 behaviour-neutral - minor - test (e) exists; no fix
- coach_marks_test.dart:265 tap-after-Skip test taps the box - must - f3
- coach_marks_test.dart:238 test name wrong - should - f3
- f1-report "6 tests" vs 5, n8c-report PASS lines, n8d2 churn wording, settings_tips_row doc wording - trivial/minor - code-health
- settings_screen.dart:96 ShowTipsRow outside a _Section card - minor - docs/code-health.md (placement is the owner's taste; decision: keep)
- phone_home_screen.dart:115 SystemNavigator.pop from the widget (guideline 1) - must - f2
- phone_home_screen_test.dart:44 over 120 columns, :245 inverted reason - trivial - f2 (format and reason)
- dispose-cancels-timer test, live-hosting guards test, report counts - should - f2 (tests) / code-health
## wave 5 (n8d1 n8b3a n8e0)
- phone_home_screen.dart:164 onDone saves false when no anchor was laid out - must - f2
- phone_home_marks_test.dart:76-82 and :84-91 pass on the old code - must - f3
- tap-under-marks assertions, inverted reason :182 - should - f3 (reason) / code-health
- tools/mine.sh:286 churn_revert touches files dirty before the job - should - tooling note in REPORT.md and kit Proposed lesson
## wave 6 (f2 f3 n8b3; review file wave6-review-report.md)
- launch_home_test.dart:55 and :108 pass on the old code - must - f5 (with the hosting-live test, should :1)
- run.log:255 n8b3 committed with 5 known red tests - invalid as a finding (f4 repaired them in the next wave; full controller_app suite is green at the f4 commit)
- launch_route.dart:17 with no TV discovered the pad connects to the remembered address (connection.dart:197-199) against the Q7 A text - OWNER QUESTION (non-blocking): keep (a failed connect then goes to Home) or route to Home at once when the remembered host is not found live
- TV-look pass in launch_home_test (the phone never shows the TV look) - minor - code-health
- n8b3-report counts, A1-A6 lines, toConnect default undocumented - trivial - toConnect default is recorded in REPORT.md
- docs/dev-tools.md:345 - trivial - fixed by hand
## wave 7 (f4 n8e2 n8e3)
- f4-report.md:5 no part A self-check lines - must(doc) - minor: noted in REPORT.md; f4 was a repair; no new job
- phone_home_screen.dart:139-146 demo branches untested - should - f6
- host_gyro_test cause unverified - minor - REPORT.md: cause (launch restore timing) is the worker's claim, restoreMode itself is covered by gyro_mode_test.dart
- site_shots.dart:238 comment - trivial - code-health
