# wave4 review: n8d2 and f1 (read-only)

## Summary
- Verdict: **needs Claude**
- Counts: must 2, should 6, could 3
- 1. Item 1 (the LayoutBuilder re-read) changes nothing a test can see, and the held-back test (e) for the moved anchor is not in the commit.
- 2. The "tap after Skip" test (coach_marks_test.dart:265) passes with the once-only guards removed.
- 3. The f784fe27 message says "add 6 tests"; the diff adds 5. ShowTipsRow sits outside the Settings cards, in a column the brief did not name.

## Findings
- **must** controller_app/lib/src/home/coach_marks.dart:134 Item 1 is behaviour-neutral: the `build` read it replaces already ran on every size change (via `MediaQuery.sizeOf`) and every parent rebuild, so no test can fail without it, yet f784fe27 presents it as the fix → keep it only with test (e) that fails without it, or drop item 1 and say so in the message.
- **must** controller_app/test/coach_marks_test.dart:265 The "tap after Skip" test taps the step-2 box, not Skip, and asserts only counts, so it passes with the `_finish` guard (coach_marks.dart:124-128) or the `_advance` guard (:113) removed → after Skip, tap Skip again and then the box; expect skipped 1 and done 0.
- **should** docs/briefs/m16/wave2-789/f1-report.md:68 The commit message says "add 6 tests"; the diff adds 5 (`testWidgets(` count 8 → 13 in coach_marks_test.dart) → correct the message to five (the commit is made; amend or note it).
- **should** controller_app/test/coach_marks_test.dart:238 The name says "before the anchor is read", but `pumpMarks(settle: false)` has already run the post-frame read (coach_marks.dart:84), so the test never reaches the `mounted` guard (:91) and passes without it → rename it to what it checks, or unmount while a read is pending.
- **should** controller_app/lib/src/ui/settings_tips_row.dart:7 The doc says the marks show "the next time Home is idle", but nothing in lib reads `showTipsProvider` and `CoachMarks` is mounted nowhere → say the flag is saved and Home does not read it yet; same wording at settings_tips_test.dart:8.
- **should** controller_app/lib/src/ui/settings_screen.dart:96 `ShowTipsRow` is outside any `_Section` card (every other section is one: settings_sections.dart:11, :26, :164, :209, :263) and sits in the motion column, not "where the other app switches are" (n8d2 brief, do item 2); the spacer makes it two body lines where the brief read says at most two in total → Claude to pick the card and column (n8d2 Q1 and Q2), then put the row in a `_Section`.
- **should** docs/briefs/m16/wave2-789/n8c-report.md:31 The requested n8c format and analyze PASS results (f1 brief item 3) are not stated; the report says they "cannot be cited" → re-run format and analyze on the n8c files, or cite a log that exists in the worktree.
- **should** docs/briefs/m16/wave2-789/n8d2-report.md:35 `mine.sh`'s churn step reverted three `tv_test_app/windows/flutter/` files outside every job's allow list (run.log:109 confirms the runner dropped them); the report says their local changes "are gone" → the owner checks those three files; the churn step must not touch files outside the job's allow.
- **could** controller_app/lib/src/home/coach_marks.dart:34 The `CoachStep` constructor doc repeats the class doc on line 32 and says what, not why → drop it, or say why the anchor is a GlobalKey.
- **could** docs/briefs/m16/wave2-789/n8c-report.md:16 "coach_marks.dart:149" cites the scrim colour line; the hole is inflated at coach_marks.dart:153 → change the reference to :153.
- **could** docs/briefs/m16/wave2-789/n8d2-report.md:9 It says the 48 dp check is in the "menu-look default test"; settings_tips_test.dart:18 sits inside the loop over both looks (line 10) → say both looks.

## Decisions to confirm
- Test (e) held back and item 1 committed without a failing test (f1-report.md "Blocked"; Q1 on the mechanism): the owner should pick the mechanism before the anchor re-read is called done.
- Removing the read from `build` as "redundant" (coach_marks.dart:134-140): correct by my reading, but it is the reason item 1 has no visible effect.
- `ShowTipsRow` placement and its missing card (settings_screen.dart:96): disclosed as n8d2 Q1 and Q2; the brief did not name a column.
- The 2 body lines plus import in settings_screen.dart, against "one line" (do item 2) and "at most 2 lines" (read): disclosed in n8d2-report.md.
- Test (e) text lives only in f1-report.md, in no test file; the owner should know it is not in the repo.

## Could not check
- `docs/briefs/m16/wave2-789/run-findings.md` does not exist, so no "passes on the old code" entries were read.
- No test was run by me (read-only job). The base-code red/green results and the 29 and 22 test counts are the workers' claims only.
- run.log:68 says "tests-first ok: coach_marks_test.dart fails on the old code" for n8c, while n8c-report.md says tests-first was not done. I could not see what "old code" meant; a whole-file compile failure would also count.
- run.log:108 and :110 say "result 4" for n8d2 and f1; the meaning is not in my extract, so I did not judge it.
- The three `tv_test_app` files still show as modified in this worktree (git status), so I could not tell whether their content was lost.
- `flash-n8c.log` and `flash-n8d2.log` are not in the wave folder; I did not read them.
- I judged against the worker extract, not the full docs/coding-guidelines.md and docs/review-rules.md.
- Checked and clean: `coach_marks.dart` is 357 lines, its `build` about 55 lines; `coach_marks_test.dart` is 331 lines; `controller_app/pubspec.lock` is not modified.

## Commit message — a draft
docs: wave4 review of n8d2 and f1 (findings only)

Review of the n8d2 Show tips switch and the f1 coach marks fixes against
their briefs, the coding guidelines and the review rules. Two must findings:
item 1 of f1 changes no observable behaviour and its test (e) is absent,
and the post-Skip test passes without the once-only guards. Six should and
three could findings are listed in wave4-review-report.md. No code changed.

## Status row
wave4 review (n8d2, f1): reviewed, verdict needs Claude (2 must, 6 should, 3 could). Open: test (e) and the mechanism for a moved anchor; the post-Skip test; the "add 6 tests" message; the Settings card and placement; the churn revert of three tv_test_app files.

## Delete
- none