# Run review: wave2-789 (read-only)

## Summary

- Verdict: **needs Claude's design** (the SystemNavigator exit, the moved-anchor mechanism and the round label need a choice; the rest is one fix batch).
- Counts: must 5 · should 16 · could 13 (34 in total; see Findings).
- The five that matter most:
  1. `phone_home_screen.dart:164` the tips are saved as seen when no anchor was laid out (`coach_marks.dart:93-95`, `:115`).
  2. `phone_home_screen.dart:119` `SystemNavigator.pop()` sits in the widget, against guideline §1; the brief asked for a platform-channel test.
  3. `phone_home_marks_test.dart:76-91` two "shows none" tests pass on the old code (no positive control).
  4. `phone_home_marks_test.dart:33,161` and `phone_home_screen_test.dart:44` are over 120 columns, so `format` fails.
  5. `coach_marks.dart:137-140` the moved-anchor re-read has no effect and test (e) is not in the repo (f1 Blocked).
- Numbers that miss a target: 60 phone-host offenders below 48 dp in `knownBelow48Host` (`touch_targets_host_test.dart`); the footer, back, "i" and pause controls are 48 px in the frame (n9b3-report.md:49).
- Questions only the owner can answer: where the round label shows (split and phone screens); whether `reconnecting`/`pairing`/`waitingForCode` count as idle; the ShowTipsRow card and column; the search-timer decision for a dropped link; the 48 px frame controls.
- Hand-fix lines in run.log: 4 (n9b1, n8c, n8b1+n9b2, n8b2). Each has a report; n8c admits no tests-first run.
- Dropped as fixed in final code: the `showTipsProvider` doc/no-reader finding (phone_home_screen.dart:147 reads it now), the `set(bool show)` rename (`shouldShow`), the bare `0.01` and `seenBelow48` in touch_targets_test.dart, the n8c box values and self-check, and the home_contract dartdocs.

## Findings

- **must** controller_app/lib/src/home/phone_home_screen.dart:164 `seen` is wired to onDone and saves `showTips` false even when every anchor lacked a render box (coach_marks.dart:93-95 and :115 call onDone with nothing shown) → show the marks only when all three anchors are laid out, or have `seen` ignore onDone while no step was shown (from: wave5; phone-pinned: yes; design: the gate is a choice).
- **must** controller_app/lib/src/home/phone_home_screen.dart:119 `unawaited(SystemNavigator.pop())` is a platform channel called from the widget, against guideline §1 → move the exit behind a small injected adapter with a fake, and have the test check the fake (from: wave4-n8b2; phone-pinned: yes; design: changes the test the brief named).
- **must** controller_app/test/phone_home_marks_test.dart:76-91 "a saved showTips false shows none" and "a client that is connecting shows none" pass on the old code (old Home never shows marks) → add a positive control in each: after `set(true)` or idle, expect `_marks` to appear (from: wave5; phone-pinned: yes).
- **must** controller_app/test/phone_home_marks_test.dart:33 and :161, controller_app/test/phone_home_screen_test.dart:44 lines are over 120 columns (checked with `^.{121,}$`) → wrap as `dart format` would, so the format gate passes (from: wave4-n8b2 and wave5; phone-pinned: yes).
- **must** controller_app/lib/src/home/coach_marks.dart:137-140 item 1 (the re-read in the LayoutBuilder) does not move the hole: the host's setState does not rebuild the overlay (f1-report.md:7, :18-19); test (e) that would show it is not in coach_marks_test.dart → choose a mechanism (f1 recommends the host rebuilds CoachMarks when it moves an anchor) and add test (e), or say item 2e is open (from: f1 and wave4; phone-pinned: yes; design).
- **should** controller_app/test/coach_marks_test.dart:265-275 "a tap after Skip" taps step 2's box, not Skip again, so removing the `_finish` or `_advance` guard passes → tap Skip a second time, then the box; expect skipped 1 and done 0 (from: wave4; phone-pinned: yes).
- **should** controller_app/test/phone_home_marks_test.dart:134-143 the tap-under-marks test has no expectation after the final `tester.tap(_marks)` → after the first tap expect `HomeText.tipPlay` on screen; after Skip expect `_marks` gone (from: wave5; phone-pinned: yes).
- **should** controller_app/test/phone_home_marks_test.dart:182 and controller_app/test/phone_home_screen_test.dart:250 `reason: 'the pad alone overflows'` sits on a check that expects no overflow → change the reason to 'the pad alone must not overflow' (from: wave5 and wave4; phone-pinned: yes).
- **should** controller_app/lib/src/home/phone_home_screen.dart:71-74 the search timer (started at :63) is cancelled in `dispose`, but no test proves it → add a test that disposes Home before `homeSearchWait` and pumps past it with nothing pending (from: wave4; phone-pinned: yes).
- **should** controller_app/lib/src/home/phone_home_screen.dart:86 and controller_app/lib/src/home/launch_consent.dart:17 the live-hosting guards (no close, no prompt) have no test → add a test: Home on a phone that hosts live asks nothing and stays open on a connection (from: wave4; phone-pinned: yes).
- **should** controller_app/lib/src/ui/settings_screen.dart:96 `ShowTipsRow` sits outside every `_Section` card and in the motion column (other sections: settings_screen.dart:153 `_Section`) → Claude picks the card and column (n8d2 Q1 and Q2), then put the row in a `_Section` (from: wave4 and n8d2; phone-pinned: yes; design).
- **should** controller_app/test/touch_targets_test.dart:101 `find.byType(Scrollable).first` may pick Connect's widgets while Settings is pushed over it (the Settings measure does not check) → scope the finder to the Settings route, or confirm by a run (from: wave1-n9b1; phone-pinned: yes; not checked here).
- **should** packages/puzzle_game/lib/src/play_view.dart:192-199 `_roundLabel` (both-set rule and the "Round N of M" text) has no test; a getter that returns null leaves round_label_test.dart green → add a PuzzlePlayView test with round and rounds set (label drawn) and only round set (no label) in round_label_test.dart (from: wave2; pinned by: puzzle_game tests, controller_app not checked).
- **should** packages/puzzle_game/lib/src/match_view.dart:210 the round label reaches only the one-board HUD; split and phone screens show none, against n9sr brief item 3 → owner decision (n9sr Q1), then either pass the label through MatchPainter or record that only one screen shows it (from: wave2; pinned by: puzzle_game tests).
- **should** tools/mine.sh:286 `churn_revert` runs in every job and reverted the three `tv_test_app/windows/flutter/` generated files, which were dirty before the wave (run.log:42-153, ten jobs); its comment says "never a person's file" → restrict the revert to paths the job's own run changed, or skip files dirty at start (from: across jobs; tools, outside every job's allow).
- **should** controller_app/lib/src/home/launch_consent.dart:16-19, controller_app/lib/src/ui/controller_screen.dart:107-110 and controller_app/lib/src/ui/connect_screen.dart:62-66 the "ask once" consent guard exists in three copies; n8b3 (which removes the old two) is not in this folder → finish n8b3, or record in code-health.md that the rule lives in three places (from: across jobs; phone-pinned: yes).
- **should** docs/briefs/m16/wave2-789/n8a-report.md:29 A4 says "Yes, apart from the churn revert" → state it as a breach of allow: (from: wave1).
- **should** docs/briefs/m16/wave2-789/n9b1-report.md:25 says `tt.log` and `tt_backup.dart` remain in the repo root; neither exists → correct the line. Also :27 "Every look: menu and TV, in every test" is untrue: touch_targets_test.dart:45 skips 568x320 TV → name the exclusion (from: wave1-n9b1).
- **should** docs/briefs/m16/wave2-789/n8b2-report.md:13 "14 tests (16 reported …)" → the file has 13 `testWidgets` calls, 16 tests run → say "13 tests in the file, 16 run" (from: wave4-n8b2).
- **should** docs/briefs/m16/wave2-789/n9sr-report.md:62 says the three generated files "are now clean" but they show as modified in git status; :77 the commit draft says "(owner decision)" while Q1 is open → correct both (from: wave2).
- **should** docs/briefs/m16/wave2-789/n8c-report.md:21 says the test file was "written together with the widget", against "Tests FIRST"; run.log:68 says "tests-first ok" for n8c → reconcile the report and the log; no red run is shown (from: wave2-n8c and wave4).
- **could** controller_app/lib/src/home/coach_marks.dart:138 `LayoutBuilder(builder: (context, _) …)` ignores its constraints and shadows `context`; f1's verdict said the builder uses them → name the builder's parameters or drop the wrapper once item 2e is decided (from: wave2 and f1).
- **could** controller_app/test/coach_marks_test.dart:238 "unmounting the marks before the anchor is read" uses `pumpMarks(settle: false)`, which already runs the post-frame read, so the `mounted` guard is not reached → rename to what it checks, or unmount while a read is pending (from: wave4).
- **could** controller_app/lib/src/home/coach_marks.dart:34 the `CoachStep` constructor dartdoc restates the class doc and says what, not why → say why the anchor is a GlobalKey (from: wave4).
- **could** docs/briefs/m16/wave2-789/n8c-report.md:16 cites `coach_marks.dart:149`; the hole is inflated at coach_marks.dart:153 → change the reference (from: wave4).
- **could** packages/puzzle_game/test/round_label_test.dart:56-67 `differs()` returns `top`, which no test reads → drop the field (from: wave2).
- **could** packages/puzzle_game/lib/src/board_hud.dart:80-94 `_labelledName` builds a TextPainter that text_paint.dart:51-63 `_layout` also builds → add maxWidth and ellipsis as optional parameters to `_layout` in a later job; text_paint.dart is outside this run's allow: (from: wave2; across jobs).
- **could** controller_app/test/touch_targets_test.dart:55 `if (screen != TargetScreen.pad) await reachConnect(tester);` branches in the test body → split the pad case, or call reachConnect for every screen (from: wave5).
- **could** controller_app/test/touch_targets_test.dart:44 the comment cites `controller_top_bar.dart:89`; the overflow is in the `Expanded` row at :92 → cite :92 (from: wave1-n9b1).
- **could** controller_app/test/phone_home_marks_test.dart:163-165 "is true when the client failed or is idle" asserts only `failed` → add `expect(idle(clientStatus: ClientStatus.idle), isTrue)` (from: wave5).
- **could** controller_app/lib/src/home/phone_home_screen.dart:26 the dartdoc cites "APP-START.md, item 8 of JOBS.md", planning files, not the reason for the code → cut the parenthetical (from: wave4).
- **could** docs/briefs/m16/wave2-789/n8d2-report.md:9 says the 48 dp check is in the "menu-look default test"; controller_app/test/settings_tips_test.dart:13 runs in both looks → say both looks (from: wave4).
- **could** across jobs: file sizes. coach_marks.dart is 357 lines (target about 300, limit 380 for touched files); settings_screen.dart 370 → 373; puzzle_painter.dart 357 → 366 (n9sr added 9 lines) → split when next touched (from: across jobs).
- **could** controller_app/lib/src/home/phone_home_screen.dart:63 the search timer runs even when a host is found; review rule B2 asks for no timer with nothing to time → start it only while the find is searching (from: wave4).

## Open questions

1. Where the round label shows: split and phone screens, or only the one-board HUD? Suggest: the one-board HUD only for this milestone, recorded in the PRD note (n9sr Q1).
2. Do `reconnecting`, `pairing` and `waitingForCode` count as idle for the marks? Suggest: busy, so the marks wait for a settled link (n8d1 Q1; the brief said only connecting or connected).
3. Should "Search again" reset the search wait (phone_home_screen.dart:94)? Suggest: yes, so a restarted search shows "searching" again (wave4 decision).
4. ShowTipsRow: which card and column? Suggest: a `_Section` in the controls column, with no spacer line (n8d2 Q1–Q3).
5. The 48 px frame controls on the phone-host screens (n9b3 Q1): enlarge the controls, or raise the frame's minimum scale? Suggest: enlarge the controls; a design call, so Claude decides.
6. The mode control at 40 dp in the brief measures 48 dp here (n9b1-report.md:13): which one does the PRD mean? Suggest: keep 48 dp, which is the touch floor.
7. The 12 px pad overflow at 568x320 TV look (n8b2 Q1): own job. Suggest: a fix job for the top bar.
8. n8b3a Q1: call `reachConnect` before the `pageBack` in launch_consent_test "a launch asks once"? Suggest: yes.
9. n8e0 Q1–Q4: spell "Thumb Party TV app"? Suggest: yes. Change log strings to "screen"? Suggest: user-visible only, leave logs. Rename kindTv label "TV" to "Screen"? Suggest: yes.
10. n9e: keep Resume and Quit `good` (option a), or give Quit a paper fill (b)? Suggest: (a), since the brief's premise is false and no change is needed.
11. n9b2 Q1–Q2: widen the bar at 667x375 TV in a follow-up; ping hidden under 280 dp. Suggest: yes to both.
12. n9b3 Q2: measure the puzzle results card and the night scoreboard? Suggest: yes, in a follow-up.
13. f1 Q1–Q3: mechanism for the moved anchor (suggest f1's option 2), test (e) when the mechanism exists, and the n8c format and analyze log that is not in the worktree (re-run it).
14. n8b0 Q1–Q2: the two flow tests fail in setUpAll on `puzzles/index.json` in worktrees; does `main` fail the same way? Suggest: run them on a full checkout before merge. Churn revert expected? Suggest: no (see the churn finding).

## Numbers against targets

- Controller touch targets (touch_targets_test.dart): `knownBelow48` is empty after n9b2 (n9b2-report.md Summary); target met at the sizes tested; 568x320 TV excluded for all three screens.
- Phone-host touch targets (touch_targets_host_test.dart, 30 tests): 60 offenders recorded in `knownBelow48Host` (n9b3-report.md:65). Target 48 dp missed.
- Frame controls (footer, back, "i", pause): 48 px in the frame, below 48 dp on every phone size (n9b3-report.md:49). Target missed; a fix job is needed.
- Mode control: brief says 40 dp compact; measured 48 dp (n9b1-report.md:13). Not a miss by measure; the brief's number is in question.
- Connection chip: 48 dp minimum (bar_connection.dart, n9b2). Target met; ping hidden below 280 dp.
- Coach marks 568x320 TV, step 2: box 135 dp, room 100 dp above and 100 dp below (n8c-report.md:16, corrected). The box does not fit beside the anchor, so the arrow is dropped. Target "box fits" met by design, not by space.
- Coach marks Skip and box: at least 48 dp each way (coach_marks_test.dart:282–326, all looks). Met on the tested sizes.
- Test counts: controller 22 (f1, mine.sh), 53 (n8b3a), 29 (n8d2), party_host 30 (n9b3), round label 12 (n9sr). Not re-run here.

## Could not check

- Nothing was run: read-only job. `dart analyze`, `dart format` and every test result are the workers' claims, not checked here.
- The moved-anchor claim (f1 Blocked) and the post-Skip finding rest on reading the code; no red run was seen.
- Whether `churn_revert` lost uncommitted edits in `tv_test_app/windows/flutter/`: git status here still shows the three files as modified, and the content could not be compared.
- Whether `Scrollable.first` picks Connect's widgets under pushed Settings (touch_targets_test.dart:101): needs a run.
- Wave 3 (n8b1, n9b2, n9b3) has no per-job review file; this review is their only check.
- `STATUS.md` does not exist; `run-findings.md` has one line only (n8d1 has no Summary block).
- The `pumpMarks` parameter count (coach_marks_test.dart:42) was not re-counted.
- Device checks listed in n9sr-report.md:67 (cut label on a TV and a narrow phone) are not possible here.
- Fixed, unverified: needs device check: the round label's ellipsis on a TV and a narrow phone (n9sr, board_hud.dart); the n9b2 chip at 667x375 TV (tests only); f1 item 1 (by reasoning; its own red run shows no change); n8d1 `_promptUp` starting true (timing by reasoning, phone_home_screen.dart:53).
- Hand-fixes (run.log HAND-FIX): n9b1 (report yes; no tests-first line), n8c (report yes; tests-first not done, admitted), n8b1 and n9b2 (both reports yes; n8b1 exempt, n9b2 no tests-first line), n8b2 (report yes; "new file, no earlier behaviour").

## Commit message — a draft

docs: run review of wave2-789 (findings only)

Read-only review of the wave2-789 run as one change, against the coding
guidelines and review rules. Adds docs/briefs/m16/wave2-789/REVIEW.md with
5 must, 16 should and 13 could findings, the hand-fix list, the open
questions and the numbers against targets. No code or other document
changed.

## Status row

wave2-789 run review: needs Claude's design (5 must, 16 should, 13 could); open: exit adapter, moved-anchor mechanism, Home tips gate, round label placement, 60 phone-host and 48 px frame targets below 48 dp, churn revert in tools/mine.sh.

## Delete

- none
