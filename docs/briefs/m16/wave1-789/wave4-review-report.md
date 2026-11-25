## Summary
Verdict: needs Claude
Counts: 3 must, 3 should, 1 could
Top 3:
1. connect_narrow_test.dart:60 skips every overflow at 568x320 TV, not only the top bar's.
2. The f2 brief's fix is not done: the filter is narrowed, controller_top_bar.dart is untouched, the 12 px overflow ships.
3. slider_semantics_test.dart:73-74 searches the whole tree for the value (contains-style), not each slider's own node.

## Findings
- **must** controller_app/test/connect_narrow_test.dart:60 `if (!knownTopBarOverflow) overflows.add(...)` drops every overflow at 568x320 in the TV look, including one from another widget (the old filter matched 'controller_top_bar.dart' by text) → keep the text match and apply it only inside the 568x320 TV case.
- **must** controller_app/test/connect_narrow_test.dart:56-57 The f2 brief's items 1 and 2 are not done: the filter is narrowed rather than removed, no commit touches controller_app/lib/src/ui/controller_top_bar.dart, so the 12 px RenderFlex overflow stays in the TV look; the comment cites code-health.md, which has no pad top-bar entry (docs/code-health.md:295 covers the connect row only) → make the Row shrink as brief item 2 says and remove the filter, or get the owner's decision to keep the overflow (see Decisions to confirm).
- **must** controller_app/test/slider_semantics_test.dart:73-74 (same pattern at :53-54) `walk.where((node) => node.value == shown), isNotEmpty` passes if any node on screen shows that text, so a wrong slider value passes when the text appears elsewhere; the brief asked for per-slider equality and no contains → read the slider's own node (getSemantics on its key for the dialogs, a descendant Semantics for the settings rows) and compare with equals.
- **should** controller_app/test/slider_semantics_test.dart:48-49 The doc comment says the slider's own node reports no value in the dialog, but the brief's driver facts say getSemantics returned the right value for the gyro and stick dialogs → state the real reason, or use getSemantics in the dialogs.
- **should** controller_app/test/slider_semantics_test.dart:42 `line.substring(line.indexOf(': ') + 2)` returns a wrong, non-empty string when ': ' is missing (indexOf gives -1, so substring(1)) and that passes the isNotEmpty check → expect the separator before cutting.
- **should** docs/briefs/m16/wave1-789/f2-report.md:1 No worker self-check (review-rules part A, items 1–6) exists for f2 or f3: f2-report.md:1 and f3-report.md:1 are driver notes, and run.log:141 shows the f2 worker ended after 1 turn → have the worker answer A1–A6 for each job before it counts as done.
- **could** controller_app/test/slider_semantics_test.dart:45 `String _wholeLine(String line) => line;` is an identity function passed as a parameter → pass nothing and use the line as it is.

## Decisions to confirm
- f2 (e46a3d8c): the driver narrowed the filter to the one case and left the 12 px overflow in the TV look, instead of the brief's fix (brief items 1–2, review open question 1). Why: the worker's fix shrank the 48 dp touch targets and the phone suite hung (f2-report.md:1, run.log:148). Claude or the owner should confirm the overflow may ship.
- f3 (8c9d9f24): the 300 ms pumps were replaced by pumpAndSettle at slider_semantics_test.dart:89 and :106. The brief does not ask for it and f3-report.md does not say so; confirm no animation keeps the pump from settling.
- f3: the dialog values are read from the whole accessibility walk (:53-54, :73-74) rather than the slider's own node. f3-report.md does not mention this choice; it is the weaker check in the must finding above.

## Could not check
- Test results: no test was run (this review changes nothing). f3-report.md's "6 tests pass" and the brief's item 4 (other bar tests stay green) are unverified.
- Tests-first for f2: run.log:15 and :30 ("connect_narrow_test.dart fails on the old code", 18:12) predate the f2 start at run.log:135 (19:10), so they cannot be attributed to f2; no failing run with the filter removed is in the logs.
- run-findings.md ("volume_semantics_test.dart passes on the old code") names packages/party_host/test/volume_semantics_test.dart, which neither f2 nor f3 touches (run.log:35 ties it to n9c); not counted here.
- Whether the 320x640 manual row and the app bar still overflow, as the comment at connect_identity_gap_test.dart:77-79 says: not run.
- The brief's diff command gives two ranges and git rejects it; I read the commits e46a3d8c and 8c9d9f24 with git show. 13a328ac is a driver note only.

## Commit message — a draft
review: wave4 (f2, f3) findings, no code changed

Review of the wave 4 jobs f2 (top bar, by hand in e46a3d8c) and f3 (slider
semantics, 8c9d9f24) against the guidelines, the review rules and their briefs.
Three must findings: the f2 connect test now hides every overflow at 568x320 TV,
the f2 top-bar fix is not done, and the f3 dialog check searches the whole tree
instead of comparing each slider. Findings only; the jobs' code is unchanged.

## Status row
wave1-789 wave4 review: done (review of f2 and f3, 3 must, 3 should, 1 could); open: the 3 must findings and the f2 top-bar fix, for Claude to decide.

## Delete
- none
