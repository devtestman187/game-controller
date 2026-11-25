# wave5 review: rv1, rv2, rv3 (read-only)

## Summary
Verdict: small fixes.
Counts: must 0, should 6, later 2.
The wave's own range (e788b84d..43fab1b4) adds only the three reports (172 lines). `packages/protocol` has no diff in fb2f6a5e..6300f506 (checked), so no protocol change is claimed or found. rv2's diff size (13 files, +248/-164) matches git.
Top three:
1. should: 7 of the file:line references in rv2 and rv3 point at the wrong lines or at nothing (`bar_connection.dart:101`, `connect_manual_entry.dart:228` and `:232`, `settings_tips_row.dart:701`, `play_view.dart:123`, `arena_hud_widgets.dart:300`). Claude cannot find them as written.
2. should: rv3 says the HUD `Wrap` row sits at `arena_hud_widgets.dart:326-333`; those lines are the `_dash` `Row`.
3. should: no job checked that its new tests fail on the old code (rv2 and rv3 say so; rv1 does not say); G9 and the brief require it.

## Findings
- **should** docs/briefs/m16/close/rv2-report.md:15 `bar_connection.dart:101` does not hold `pingBesideMinBarDp`; the constant is at `:23` and its use at `:47` → cite `:23` and `:47`.
- **should** docs/briefs/m16/close/rv2-report.md:18 `settings_tips_row.dart:701` is not a line of that 21-line file; `ShowTipsRow` is declared at `:9` with its constructor at `:10` → cite `:9`/`:10` and drop "701 in the diff".
- **should** docs/briefs/m16/close/rv2-report.md:18 `connect_manual_entry.dart:232` does not exist (file is 87 lines); the `ManualEntry` constructor is at `:16` → cite `:16`.
- **should** docs/briefs/m16/close/rv2-report.md:19 `connect_manual_entry.dart:228` does not exist; the constant is at `:11` and used at `:65` → cite `:11` and `:65`.
- **should** docs/briefs/m16/close/rv3-report.md:19 `packages/puzzle_game/lib/src/play_view.dart:123` is wrong: `'Round $round of $rounds'` is at `:201`; `packages/test_game/lib/src/arena_hud_widgets.dart:300` is wrong: it is at `:174` → cite `:201` and `:174`.
- **should** docs/briefs/m16/close/rv3-report.md:14 `arena_hud_widgets.dart:326-333` is `_dash`, a `Row`, not the `Wrap` that holds map name, round, clock and Best (`Wrap(` is at `:108`, `:195`, `:250`) → cite the real `Wrap` and say which one.
- **later** docs/briefs/m16/close/rv2-report.md:16 `connect_screen.dart:100`: the app-bar title with `maxLines: 1` is at `:102` → cite `:102`.
- **later** docs/briefs/m16/close/rv2-report.md:31 `controller_screen.dart:134`: the `returnHomeOnFailedConnect` call is at `:135` and the function is `launch_route.dart:39` (rv1 cites it right) → cite `launch_route.dart:39`.

Checked and correct (no finding): `phone_home_screen.dart:80, :117, :167, :184`; `home_view.dart:66`; `coach_marks.dart:11`; `launch_route.dart:39`; `host_connection.dart:193` (close reason text changed, no message shape); `night_awards_flow_test.dart:200-205` (phone host at 640x360 in `HostLook.menu` only, as rv3 says); `game_screen_shell.dart:23-24` (constructor has no dartdoc, as rv3 says); `controller_menus.dart:176-181`; `launch_home_test.dart:54-55` (Sunny and Night at 852x393 and 393x852, as rv1 says); `settings_tips_test.dart:13-18`.

## Decisions to confirm
- rv1 ran no tests, citing "the job allows no scratch files" (rv1-report.md:3). The brief forbids scratch files, not test runs. Claude decides whether the wave is re-checked with tests run.
- rv1, rv2 and rv3 each add `## Commit message`, `## Status row` and `## Delete` sections that their briefs do not ask for (rv1-report.md:49, rv2-report.md:44, rv3-report.md:44). Claude decides whether these stay.
- rv2 and rv3 could not confirm that their new tests fail on the old code. Claude decides whether that check (G9) is run before the wave is closed.

## Could not check
- No test, analyzer or build was run (read-only review). Test pass claims in the reports are unverified; rv2's "820+ pass" comes from REVIEW-VERDICTS.md.
- rv3's claims about `tools/release.sh` (no pubspec version check, `docs/release.md:12`) and the tools' agreement were not read; I did not run the script.
- rv3's "host_text.dart 379" line count: no file of that name was found (`Glob` not run; `wc` only on `puzzle_painter.dart` 368 and `arena_hud_widgets.dart` 351, both matching).
- rv3's `round_label_test.dart:72-93` and rv2's `connect_screen.dart` 389-408 ranges were not read.
- Test bodies of the new tests (rv2 said it read names and sizes only) were not read, so no fail-on-old-code verdict is given here.

## Commit message
m16 close wave5: review of rv1, rv2, rv3 reports

Read-only review of the three milestone-end review reports (rv1, rv2,
rv3) against their briefs and the code at 43fab1b4. No must. Six should
and two later: wrong file:line references in rv2 and rv3, a wrong
`Wrap` citation in rv3, and no fail-on-old-code check for new tests.
Protocol unchanged (packages/protocol diff empty in the range).

## Status row
wave5 review done: rv1, rv2, rv3 reviewed, 0 must, 6 should, 2 later; open: fix the wrong file:line references in rv2 and rv3 (rv2-report.md:15-19, :31; rv3-report.md:14, :19), and run a fail-on-old-code check on the new tests.

## Delete
- none
