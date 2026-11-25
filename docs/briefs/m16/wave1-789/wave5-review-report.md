## Summary

Verdict: needs Claude.
Counts: must 2, should 2, could 2.
1. The rewritten volume test passes on the old code (run-findings.md:1), so it proves no new behaviour; the brief's exemption needs Claude's sign-off.
2. f4-report.md:29 says the churn revert discarded three generated plugin files, but git status still lists them as modified and the site shots exist; the Hand-over cannot be trusted as written.
3. volume_semantics_test.dart:21 reads RenderObject.debugSemantics, a debug-only render internal, not the public semantics API the brief named.

## Findings

- **must** docs/briefs/m16/wave1-789/run-findings.md:1 and packages/party_host/test/volume_semantics_test.dart:38: the rewritten per-slider, both-looks test passes on the old code, and the brief exempted it from tests-first → add a case that fails on the old code, or record the exemption as accepted in the job's report.
- **must** docs/briefs/m16/wave1-789/f4-report.md:29: the Hand-over says the churn revert discarded `tv_test_app/.../generated_plugin_registrant.cc`, `.h` and `generated_plugins.cmake`, but git status still shows those three as modified and `site/shots/*.png` are present → Claude checks the worktree with the owner and corrects the Hand-over before anyone restores or deletes anything.
- **should** packages/party_host/test/volume_semantics_test.dart:21: the walk reads `renderObject.debugSemantics` (a debug-only internal) instead of the public semantics finder the brief named → use `tester.semantics` to find the slider node, or Claude accepts the internal read as a decision.
- **should** packages/test_game/test/arena_hud_round_test.dart:91: the new "only the clock turns bad" test is added to an existing file, while the COMMON rule says new tests go in a new file → Claude confirms the brief's file choice, or moves the test to a new file.
- **could** packages/party_host/test/volume_semantics_test.dart:55: `handle.dispose()` is not in `addTearDown`, so a failing `expect` leaves semantics enabled for the next look → replace it with `addTearDown(handle.dispose)` after line 42.
- **could** packages/party_host/test/volume_semantics_test.dart:12: the slider's percentage is found by `.first` and `.last` positions in the widget tree, so a layout change breaks the test without a clear message → find the Text by its key or by its `%` value instead.

## Decisions to confirm

- f4: the new Best-colour test sits in arena_hud_round_test.dart (brief named it; COMMON says new tests go in a new file) — see the should finding at line 91.
- f4: the race test passes on the old code by design (the fix does not touch the race clock); it guards the race from the warning colour and is not a regression test for this fix.
- f4: `isHurrying` is a getter on the private `_RoundRow` with no underscore, as the brief's rename says; the clock now has its own `clockStyle` (widgets:201-203).
- f5: tests-first exempt, per the brief; the run-findings entry shows the file passes on the old code (must finding above).
- f5: the slider value comes from `RenderObject.debugSemantics` after the merged key node read empty (f5-report.md:12-13); this is an internal read, not the public API.
- f5: the Night and Sunny palettes are still both tested, and the TV look is added through forEachLook; this matches the brief.

## Could not check

- f4: the "FAILED before the fix" run and the `mine.sh` output are not in run-findings.md (no f4 entry); by reading, the old code set Best to the warning colour while hurrying, so the new test would fail there, but I did not run it.
- f5: `packages/party_host/.dart_tool/f5diag.txt` (f5-report.md:37) does not exist in this worktree, so the scratch file the report says was left behind cannot be confirmed or deleted here.
- Both: format, analyze and the tests were not re-run (read-only job); the report's PASS claims are unverified by me.
- f4: whether the churn revert removed site/shots/*.png cannot be told from git status alone; the files exist now.

## Commit message — a draft

Review: wave 5 jobs f4 and f5 (findings only)

This review changes no code. It records two must findings: the volume
semantics test passes on the old code, and the f4 report's hand-over
about reverted files does not match git status. It also lists the
should and could findings for Claude to act on.

## Status row

M16 wave1-789 wave5 review: done — f4 and f5 reviewed against their briefs and the guidelines. Open: 2 must (f5 test passes on old code; f4 hand-over vs git status), 2 should, 2 could; Claude to act.

## Delete

- none
