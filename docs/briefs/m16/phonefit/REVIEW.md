# m16 phonefit — the run's review

## Summary

Verdict: **one fix batch**. 0 must, 4 should, 9 could. Both jobs are test-only and tests-first exempt (run.log:8–9), and the wave1 review report exists; `run.log` has no `HAND-FIX` line.
Carried over: all five wave1 findings still hold (no later job touched those lines); none dropped, none fixed.
1. pf1's 360x640 start-card numbers contradict its own results.json (293 vs 300.0, 777–825 vs 784–832, "233 under" vs 248 under).
2. The 360x640 spills are measured with 18–21 character names; a real host caps a nickname at 10, so the summary reads as a phone bug it may not be.
3. No 10-character case exists, so a layout fix has no acceptance number to pass.
4. `docs/briefs/m16/STATUS.md:28` still says the round strip is not captured; pf2's picture exists.
5. The run leaves `docs/design/m13-tablet-board.png` changed (126,808 → 167,512 bytes, 18:08:28) and no report claims it.
Fix batches (≤3 findings each, no shared files; only D is phone-pinned):
- A docs: pf1-report.md:12, :24, :168.
- B docs: pf2-report.md:7, :46, :64, :22.
- C host: phone_fit_test.dart:107, :272 — `check: host`.
- D phone: round_strip_png_test.dart:33, :57 — `check: phone`.
- Claude's own: STATUS.md:28, restore the design picture, guard tablet_board_png_test.dart:84.
Owner: whether the 360x640 night-card fix comes before M16 item 5 or after it; every other question is Claude's.

## Findings

- **should** docs/briefs/m16/phonefit/pf1-report.md:12 (also :44, :113, :115) the start-card row at 360x640 says `maxScrollExtent` 293 with the Shape Race button at 777–825, but the committed evidence says 300.0 with the button at 784–832 (results.json:141, :154–155) → copy every number out of results.json, including "248 px under" instead of 233 (from: wave1)
- **should** docs/briefs/m16/phonefit/pf1-report.md:13 (also :45–48, :109) the 360x640 "nicknames 0 wide" and four row overflows are produced with names of 18–21 characters injected at packages/party_host/test/phone_fit_test.dart:143 while a real host cuts a nickname at `maxNicknameLength = 10` (packages/connection/lib/src/game_types.dart:79) and the fake host passes names uncapped (packages/party_host/lib/src/testing/host_fakes.dart:216) → mark the row a worst case beyond the app's cap and add a 10-character case before any layout fix is judged (from: wave1)
- **should** docs/briefs/m16/STATUS.md:28 (also :108, :119–120) says the round-state strip is "not yet captured", which pf2's `round-strip-852x393.png` has made wrong → say "captured in a widget test at 852×393 (and 2x); the emulator capture is still open" (from: across jobs)
- **should** docs/design/m13-tablet-board.png is modified in the working tree (126,808 → 167,512 bytes, mtime 18:08:28, one second after results.json was rewritten at 18:08:27) because packages/puzzle_game/test/tablet_board_png_test.dart:84 writes it on every run with no guard, so the run's verification left a tracked file changed and no report claims it → restore it from `HEAD` and guard that test behind an env switch as the two new PNG tests are (from: across jobs)
- **could** packages/party_host/test/phone_fit_test.dart:272 `_isClipped` records only `didExceedMaxLines` or a non-wrapping over-wide text, so the reveal's "Bartholomew" cut mid-word at 360x640 (night-reveal-360x640.png) is in no `clipped` entry (results.json:287 has `[]`) and a fix driven by `clipped` alone misses it → also record a paragraph whose laid-out right edge falls outside the box its ancestors paint (from: wave1)
- **could** docs/briefs/m16/phonefit/pf1-report.md:168 and docs/briefs/m16/phonefit/pf2-report.md:22 document `PHONE_FIT=1 flutter test …` and `ROUND_STRIP_PNG=1 flutter test …`, commands neither job ran (run.log:8–9 records only the skipped path; pf1 used `--dart-define`, pf2 `--run-skipped`) → put the command that was actually used in the hand-over and mark the env-variable form unverified (from: across jobs)
- **could** docs/briefs/m16/phonefit/pf2-report.md:7 says the picture reads "exactly the content of mock-up frame 0", but that frame's strip also has a badge at its left (docs/briefs/m16/ux-review/mockups/proposal-00-sunny.png) that the picture lacks → say the four parts the brief asked for, and that the badge belongs to item 5 (from: across jobs)
- **could** packages/party_host/test/phone_fit_test.dart:107 loads `loadLookFonts` only, so all 24 night pictures draw an empty box where an icon goes (night-scoreboard-360x640.png), unlike controller_app's pictures; the report's fit claim holds but the pictures cannot be used for a visual check → load the Material icons as controller_app/test/support/test_font.dart:38 does, or say in the report the pictures are not for the look (from: this review)
- **could** docs/briefs/m16/phonefit/pf2-report.md:64 (copied into commit 8a26cbdb) says "the suite … needs no fonts on a plain run", but controller_app/test/round_strip_png_test.dart:45–46 loads the fonts in `setUpAll` unconditionally, as pf2-report.md:17 says → correct the draft so the two statements agree (from: this review)
- **could** docs/briefs/m16/phonefit/pf2-report.md:46 "The three pictures the review needs are in place" names three files; the job wrote two (`round-strip-852x393.png`, `round-strip-852x393-2x.png`) → say two (from: wave1)
- **could** controller_app/test/round_strip_png_test.dart:57 (also :67) `greaterThan(5000)` is a bare magic floor with no named constant, against coding-guidelines.md §2 → name it (`_blankFrameBytes` or the like) with its reason (from: this review)
- **could** docs/briefs/m16/phonefit/pf1-report.md:24 "Every text's painted scale is exactly 1" is stronger than the data: the test records a scale only when it is more than `_slop` (0.5) from 1 (packages/party_host/test/phone_fit_test.dart:315) → write "within 0.5 of 1", or record every scale (from: wave1)
- **could** controller_app/test/round_strip_png_test.dart:33 `shotDir = '../docs/briefs/m16/phonefit'` is right only when `flutter test` runs in controller_app, while packages/party_host/test/phone_fit_test.dart:101–103 resolves the folder from either working directory; run from the repo root and the picture lands outside the repo → copy the two-path lookup `_outDir` uses (from: across jobs)

## Open questions

1. Keep `--dart-define=PHONE_FIT=true` as a second switch (pf1-report.md:134, phone_fit_test.dart:22)? Suggested: no — keep `PHONE_FIT=1` only and run it once as documented.
2. Should the measurement also use the real 10-character cap (pf1-report.md:137)? Suggested: yes, before any 360x640 fix; that is the only way a fix has a number to pass.
3. Is the puzzle results' way-on "Next puzzle" the right case (pf1-report.md:141)? Suggested: keep the four keys as they are; add a plain round's Rematch case in the fix job.
4. Keep the `-2x` name for the dpr-2 twin (pf2-report.md:53)? Suggested: yes, it says what it is.
5. Optimise the 207 KB PNG (pf2-report.md:54)? Suggested: leave the bytes; the pictures are review evidence, not app assets.
6. "On screen" = the screen's rect, not the scroll viewport (pf1-report.md:188)? Suggested: keep it; no way-on button sits under the title bar, but say so in any fix brief.

## Numbers against targets

- PRD target (docs/PRD-v2.md:872): the night cards fit a ~360x640 dp phone host and leave room for Thumby's corner head + 2-line caption. Missed: start card scrolls 300 of a 584 viewport with the button 784–832, 248 dp under the screen (results.json:141, :154–155); scoreboard 4 overflows 15/16/7.7/8.6 px (results.json:162–166); final scores 18/18/14/7.3 (results.json:220–224); reveal 121 (results.json:279); Arena results 3.1/63/56/39 (results.json:298–301); puzzle results 188/17 (results.json:325–326). The Thumby slot is not measured at all.
- The 360x640 nicknames want 201/199/190/185 dp and are given 0 dp (results.json:174–205); those names are 18–21 characters where the app caps at 10 (game_types.dart:79), so no number here matches a couch's case.
- Report against its own evidence: 293 vs 300.0, 777–825 vs 784–832, 233 vs 248 dp under (pf1-report.md:12, :44, :113, :115 vs results.json:141, :154–155). Every other table value checked (551/304, 175, 115, 15, 71, 86, 70 of 664, 24.0 dp labels, 13.5 dp minimum, the four overflow sets, the button rects) matches results.json.
- Met: test files under the briefs' 380 lines (359 and 146); 24 screen × size pictures; strip 852×393 and 1704×786 (PNG headers 0x354×0x189 and 0x6A8×0x312); 206,799 and 416,657 bytes as reported.

## Could not check

- `tester.takeException()` null in all 24 and "no pending-timer failure" (pf1-report.md:70, :158): neither is in results.json.
- "Painted scale exactly 1" (pf1-report.md:24): only scales more than 0.5 from 1 are recorded, so a 1.4 wrapper would not appear.
- Which run wrote docs/design/m13-tablet-board.png: the mtime (18:08:28) puts it with the wave1 review's verification run, one second after results.json and all 26 pictures were rewritten, but the review report names no such run.
- The commit boundary: 289de18b (pf1) also holds pf2's two PNGs and pf2-report.md, so a revert of the measurement commit would take the strip's pictures; the runner staged both, not the workers.
- Whether the badge at the left of mock-up frame 0 belongs to item 5: inferred from M16 STATUS, not stated in either report.
- The strip on a real device or the emulator: both pictures are widget-test renders, and the emulator was stopped.
- Turns used in either report, and the `PHONE_FIT=1` / `ROUND_STRIP_PNG=1` forms of the commands themselves.

## Commit message

Review the m16 phone-fit run (pf1, pf2)

Findings only: pf1's 360x640 start-card row disagrees with results.json
(293/777-825 vs 300/784-832), the spills use 18-21 character names where
a host caps at 10, and no 10-character case exists to judge a fix. The
reveal's cut name is in no clipped entry, STATUS.md still says the strip
is uncaptured, and the run leaves docs/design/m13-tablet-board.png
changed in the tree. 0 must, 4 should, 9 could; five fix batches.

## Status row

m16 phonefit run reviewed (pf1, pf2): 0 must, 4 should, 9 could, five fix batches; open: the 10-character-name case, the 360x640 night-card fixes, and the report/STATUS corrections.

## Delete

- none
