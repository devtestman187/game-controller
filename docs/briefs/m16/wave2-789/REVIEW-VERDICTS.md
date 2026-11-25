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
