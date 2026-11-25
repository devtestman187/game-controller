# Review: wave1 jobs n9e and n8a

## Summary

- Verdict: needs Claude
- Counts: must 1 · should 3 · could 2
- n8a self-check A4 answers "Yes, stayed inside allow:" (n8a-report.md:29), but its Hand-over (line 40) says the mine.sh churn step reverted 22 files outside allow, three of them tracked generated files. The claim hides a breach.
- n9e stopped correctly: its brief's premise is false, because `pauseQuit` already rests on `good` too (pause_menu_widgets.dart:73-77, toy_button.dart:235). The owner must pick option (a) or (b).
- n8a's failing-first test run is not evidenced: no run-findings.md exists, and n8a-report.md:39 says it was not measured.
- Checked and matching: the home_contract.dart class doc against JOBS.md:5, and the HomeText strings against APP-START.md:36-60.

## Findings

- **must** docs/briefs/m16/wave2-789/n8a-report.md:29 The A4 self-check says "Yes" to staying inside allow:, but line 40 says mine.sh ran `git checkout --` on 22 files outside allow (docs/design PNGs, site/shots, three tv_test_app generated files) → answer A4 as a breach in the report, have Claude check whether those uncommitted edits are lost, and have the churn revert (tools/churn.sh:6) skip paths the job did not touch.
- **should** controller_app/lib/src/home/home_prefs.dart:48 `set(bool show)` names a boolean as a verb, against the "booleans read as questions" rule (docs/coding-guidelines.md:50) → rename the parameter to `shouldShow`.
- **should** controller_app/lib/src/home/home_contract.dart:28 `join`, `play` and `display` on HomeAnchors are public with no dartdoc (docs/coding-guidelines.md:92) → add a one-line dartdoc to each key saying which button it marks.
- **should** controller_app/lib/src/home/home_prefs.dart:38 `showTipsProvider` is public with no dartdoc (docs/coding-guidelines.md:92; device.dart:15 has one) → add a dartdoc saying what it holds and that it is saved under `showTips`.
- **could** controller_app/lib/src/home/home_text.dart:55 The 15 public constants have only the class dartdoc, while the guideline asks for each public member → add a dartdoc per string, or say in the class doc that each constant is the APP-START text verbatim.
- **could** controller_app/test/home_contract_test.dart:1-27 No test checks brief item 3's rule "no whole word TV in any string" → add a test over the HomeText values, using a `\bTV\b` pattern, to this file (it is in n8a's allow:).

## Decisions to confirm

- controller_app/lib/src/home/home_contract.dart:4-31 Three public types (HomeRole, HomeFind, HomeAnchors) share one file, as the brief named it. Guideline §3 (docs/coding-guidelines.md:45) allows this only for small types that make sense together; confirm the exception applies, or split the file.
- controller_app/lib/src/home/home_prefs.dart:48-50 `set` awaits the save, unlike controls.dart:19-21, which the brief named as the pattern. Chosen so the tests can await it (n8a-report.md:20). Safe; confirm the deviation.
- controller_app/lib/src/home/home_contract.dart:26 Anchors are plain `GlobalKey()` with no state type (n8a-report.md:22). Fine for rectangle lookups; a wiring job that needs `currentState` must change the type.
- docs/briefs/m16/wave2-789/n9e-report.md:15-22 n9e stopped with no change, which is right: Resume is already `good` (host_button.dart:136 → toy_button.dart:235), and Quit is too (pause_menu_widgets.dart:73-77 passes no fill). Owner picks (a) keep both `good`, or (b) Quit paper with an explicit fill.

## Could not check

- No docs/briefs/m16/wave2-789/run-findings.md exists, so there is no runner evidence on whether n8a's tests fail on the old code. The new files' API did not exist before, so the tests could only fail to compile; not run here.
- Whether the 22 reverted files lost uncommitted edits: in this worktree, `git status` still shows the three tv_test_app generated files as modified, so the revert ran in n8a's own worktree. The docs/design and site/shots files could not be checked here.
- Part B (game code) does not apply: the diff has no game code.
- The analyzer and tests were not run by this review (read-only job). n8a-report.md:34-35 says mine.sh passed after two fixes; that is not verified here.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

(no commit: review only; this job changes no code)

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

wave1 review: needs Claude. n8a: 1 must (A4 self-check vs 22 reverted files), 3 should, 2 could on the Home contract; open: failing-first not measured, reverted files to recover. n9e: stopped correctly; owner to pick (a) or (b).

## Delete

- none
