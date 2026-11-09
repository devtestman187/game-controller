job: M13 full review R3: the apps. controller_app (phone screens, the pad, settings, joined view, phone host) and tv_test_app (home, test screens, start-up). Read-only
stop: after the review. Change no file but the report, and fix nothing. Write only inside this job's folder.
read: docs/review-rules.md (parts A to D: the rules for this review) · docs/coding-guidelines.md · docs/design/look-and-sound.md (all, with the "Decided at step N" blocks) · docs/PRD-v2.md L1–L6 and T15 · docs/briefs/m13/STATUS.md and the step briefs and reports it lists · docs/design/m12-host-touch.md · docs/design/m12-phone-layout.md (if present) · docs/design/m12-joined-view.md §0
diff: `git diff d06f88a HEAD -- controller_app tv_test_app` (M13 was cut from m12 at d06f88a; ignore tv_test_app/windows/flutter/generated_*). Read the tests as well as lib: a test that would still pass if its rule broke is a finding.

do:
1. **Part A:** for each M13 job in your area, is its self-check true?
2. **Part B** over the diff, B1–B8, focused on:
   - D11: the pad's sizes, hit areas and opacity unchanged from d06f88a (compare FaceGeometry, dpadArms, the stick, SmallButton sizes and their tests line by line);
   - the start-up: scope, theme, shader load with its timeout, the font licences, the Look setting applied at the set moments;
   - the phone host's prefs swap (lookPrefsProvider), so the Look and sound settings are this phone's whether it hosts or joins;
   - the sky held on ControllerScreen;
   - the joined phone never playing lobby music or the countdown;
   - the TV at 960 × 540 and 1280 × 720 (the header, two controllers in view);
   - no colour literal left in either app's lib.
3. **The combination table (A3)** for every state your area touches (hosting or joined × palette × effects × the pad's modes × opacity). For each pair: "tested by <test name>", or "not tested" and what the code does.
4. **Part C:** only for your area, and only what would cost much more to fix later than now. Weigh it against M14 G1–G8 (points shown on joined phones, the scoreboard) and streaming to a TV.
5. **PRD coverage:** for L3 (phones and TV) and L5's settings rows, say whether each sentence is done, with the file or test that shows it, or what's missing.
6. Run `tools/review.sh` on the range and copy every FAIL.
format: docs/review-rules.md part D, at most 140 lines.
check:
report: docs/briefs/m13/m13-review-r3-report.md
allow: docs/briefs/m13/m13-review-r3-report.md
