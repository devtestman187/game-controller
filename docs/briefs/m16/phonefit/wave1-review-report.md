# pf1, pf2: wave 1 review (findings only)

## Summary

Verdict: small fixes. 0 must, 2 should, 3 could.

- `pf1-report.md:12` the start card at 360x640 is reported as scroll 293 and button 777–825; the committed `results.json` has 300.0 and 784–832.
- `pf1-report.md:13` the 360x640 spills are measured with 18–21 character names, while a real host cuts a name at 10 (`maxNicknameLength`), so the table reads as a couch's bug when it may not be.
- `phone_fit_test.dart:272` the reveal's name cut mid-word at 360x640 (visible in `night-reveal-360x640.png`) is in no `clipped` entry, so a fix driven by `clipped` alone misses it.

## Findings

- **should** docs/briefs/m16/phonefit/pf1-report.md:12 (also :113) the start-card row at 360x640 says `maxScrollExtent` 293 and a button at 777–825, but the committed results.json recorded by the same run says 300.0 with the button at 784–832 → copy the numbers out of results.json (or rerun) so the report and its evidence agree.
- **should** docs/briefs/m16/phonefit/pf1-report.md:13 the 360x640 "nicknames 0 wide" and the 4 row overflows are produced with names of 18–21 characters injected into the fake host at packages/party_host/test/phone_fit_test.dart:143, while a real host cuts a nickname at `maxNicknameLength = 10` (packages/connection/lib/src/game_types.dart:79), so Claude cannot tell from the summary whether a couch hits this → mark the row as a worst case beyond the app's cap, and add a 10-character row before a layout fix is judged.
- **could** packages/party_host/test/phone_fit_test.dart:272 `_isClipped` records only `didExceedMaxLines` and non-wrapping over-width, so the reveal's "Bartholomew" cut mid-word at 360x640 (picture) is absent from its `clipped` list (docs/briefs/m16/phonefit/results.json:287) and only the RenderFlex error hints at it → also record a paragraph whose laid-out right edge falls outside the box its ancestors paint.
- **could** docs/briefs/m16/phonefit/pf1-report.md:24 "Every text's painted scale is exactly 1" is stronger than the data: the test records a scale only when it is more than `_slop` (0.5) from 1 (packages/party_host/test/phone_fit_test.dart:315), so a 1.4 wrapper would be invisible too → write "within 0.5 of 1", or record every scale.
- **could** docs/briefs/m16/phonefit/pf2-report.md:46 "The three pictures the review needs are in place" names three files; the job wrote two (`round-strip-852x393.png`, `round-strip-852x393-2x.png`) → say two.

## Decisions to confirm

- Whether `--dart-define=PHONE_FIT=true` stays as a second switch (pf1-report.md:134, packages/party_host/test/phone_fit_test.dart:22); the brief asked for the env variable only, and the env path was never exercised by pf1's run.
- Whether a 10-character-name case is measured before any 360x640 fix (pf1-report.md:137, `maxNicknameLength = 10`); today's spill numbers are a name no host can pass on.
- "On screen" means inside the screen's rect, not the scroll viewport (pf1-report.md:188); safe only while no way-on button sits under the title bar, as the report says.
- The `-2x` file name for the dpr-2 twin (pf2-report.md:53), against the brief's "one file per size under a name the brief spells out" silence.
- Both pictures were produced off the brief's command (`--dart-define` for pf1, `--run-skipped` for pf2, pf2-report.md:22), so the documented `PHONE_FIT=1` / `ROUND_STRIP_PNG=1` run is untested by either job.

## Could not check

- Whether either worker staged files outside its own: both commits were made two seconds apart by the runner, and 289de18b (pf1's) holds pf2's two PNGs and pf2-report.md, so the staging is not the worker's to read.
- `tester.takeException()` null in all 24 cases and "no pending-timer failure" (pf1-report.md:70, :158): neither is in results.json.
- The modified `docs/design/m13-tablet-board.png` in the working tree (126,808 → 167,512 bytes, mtime 18:02:04, after both commits); the test that writes it is packages/puzzle_game/test/tablet_board_png_test.dart, so I cannot say which run wrote it.
- Turns used, in both reports.

## Commit message

Review the m16 phone-fit wave 1 (pf1, pf2)

Findings only. pf1's start-card row at 360x640 no longer matches the
committed results.json (293 dp vs 300.0, button 777-825 vs 784-832), and
its 360x640 spills are measured with 18-21 character names where a real
host cuts at 10, so the summary should say worst case. The reveal's cut
name is in no `clipped` entry; "scale exactly 1" only holds to 0.5; pf2
says three pictures where two exist. Both pictures came from run paths
other than the brief's env switch, now a decision.

## Status row

m16 phonefit wave 1 reviewed (pf1, pf2): 0 must, 2 should, 3 could written up; open: the 360x640 spill fixes and the five decisions (dart-define switch, 10-character name case, on-screen rule, 2x name, run commands).

## Delete

- none
