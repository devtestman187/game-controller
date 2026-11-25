## Summary

Verdict: **needs Claude's design** (six must findings are small fixes; the 6-parameter widget, the blanket overflow filter and the hard-coded names table need a decision first).
Counts: 6 must · 16 should · 5 could (plus 14 open questions).

Top five:
1. `night_awards_flow_test.dart:128` `BISECT-TEMP` early return is still in the committed file; the reveal and totals checks never run (n7a said it was removed; it was not).
2. `connect_narrow_test.dart:61` a blanket `onError` filter drops every overflow whose text names `controller_top_bar.dart`, which hides the committed 568x320 TV overflow (12 px, n9a). The check is weakened.
3. `arena_hud_widgets.dart:220` "Best" uses the clock's `tabular` style, so it turns red in the last 15 s.
4. `volume_semantics_test.dart:46` passes on the old code; its tests-first exemption rests on an unverified Slider default.
5. Uncommitted work was discarded by `tools/mine.sh` churn revert: 22 files (n9a) and 3 `tv_test_app/windows/flutter/` files (n7a, n9d3). Still ` M` in this tree at the start of the run; owner to check.

Fix jobs (one wave, no shared files; `phone` = controller_app tests pin the file):
- J1 party_host: night_awards_flow_test.dart (BISECT line, skip comments, `_playNight` length)
- J2 party_host: volume_semantics_test.dart + look_and_sound_section.dart (old-code pass, ignore, TV look)
- J3 `phone`: slider_semantics_test.dart (ignore, `contains`, `endsWith`)
- J4 `phone`: connect_narrow_test.dart + connect_identity_gap_test.dart (blanket filter if the owner picks "fix the top bar"; stale comment)
- J5 test_game: arena_hud_widgets.dart (Best colour, `_hurrying` rename, round source)
- J6 test_game: arena_hud_round_test.dart (race frame)
- J7 docs: n9d3-report.md, n9c-report.md, docs/decisions.md
- Design first (Claude): round/rounds value object (arena_hud_widgets.dart, arena_view_widgets.dart); GameScreenShell six parameters (new file outside allow:); names table in arena_map_names.dart; settings/gyro/stick screen-reader check (device)

## Findings

- **must** packages/party_host/test/night_awards_flow_test.dart:128 `if (i == 0) return; // BISECT-TEMP` ends the reveal loop before any check, so lines 129-157 (reveal names, reasons, "+3 points", totals) never run for the two running tests → delete line 128, run the file, fix what then fails (from: n7a)
- **must** controller_app/test/connect_narrow_test.dart:61 `if (!text.contains('controller_top_bar.dart')) overflows.add(...)` silently drops any overflow from the pad's top bar at every size and look, so the 568x320 TV overflow n9a reported (12 px) passes → fix the overflow in `controller_app/lib/src/ui/controller_top_bar.dart`, or have the owner name that one size and look as an explicit exemption; remove the blanket text filter (from: n9a; DRIVER-NOTES.md 18:18, which names controller_top_bar.dart:89)
- **must** packages/test_game/lib/src/arena_hud_widgets.dart:220 the "Best" text uses `tabular`, which now carries the `bad` colour in the last 15 s, though the brief asks only for the clock → give the clock (line 217, key `roundTime`) the `tabular` style with the colour and keep "Best" on ink; add a test that "Best" stays ink at 15000 ms (from: n9d2)
- **must** packages/party_host/test/volume_semantics_test.dart:46 the test passes on the old code, and the exemption in n9c.md:5 rests on a Slider default nobody read; `look_and_sound_section.dart:164` (`semanticFormatterCallback`) is therefore not shown to change anything → make the assertion equal the value the callback returns for each key and show it fails without the callback, or the owner withdraws the exemption (from: wave1; run-findings.md)
- **must** controller_app/test/slider_semantics_test.dart:40 `// ignore: deprecated_member_use` breaks the rule against analyzer ignores → read each node through `tester.getSemantics(...)` or the non-deprecated root accessor, and delete the ignore (from: wave1)
- **must** packages/party_host/test/volume_semantics_test.dart:21 the same `// ignore: deprecated_member_use` → same fix as slider_semantics_test.dart:40 (from: wave1)
- **should** controller_app/test/slider_semantics_test.dart:72 `contains(...)` over the whole semantics tree lets another slider with the same text satisfy the check; the brief asked for per-slider equality → `expect(tester.getSemantics(find.byKey(Key(key))).value, _valueShownAbove(...))` for each key (from: wave1)
- **should** controller_app/test/slider_semantics_test.dart:92 and :110 `endsWith(...)` is a suffix match, and `endsWith('')` is true for any line, so an empty semantics value passes → compare with `equals` against the value the slider reports (from: wave1)
- **should** packages/party_host/test/volume_semantics_test.dart:39 the volume rows run only in the Sunny and Night palettes; the TV look is not tested, and `packages/party_host/test/support/all_looks.dart` exists for this → run the case through `forEachLook` (from: wave1)
- **should** packages/party_host/test/night_awards_flow_test.dart:164-166 and :180-181 both tie cases are `skip: true`; the comment gives no file:line or exception text for the lib fault, and the tie rule (PRD item 7) has no running test → have the driver read the exception from `flutter test` on this file and put its file:line in the comment before the skip stays (from: n7a)
- **should** packages/party_host/test/night_awards_flow_test.dart:100 `_playNight` is 59 lines against the ~40-line guideline → move the reveal loop (127-142) and the totals check (144-157) into named helpers (from: n7a)
- **should** packages/test_game/test/arena_hud_round_test.dart:88 the race test calls `bumperFrame` (line 13, which sets `mode: ArenaMode.bumper` at line 25), so no race frame is tested → add a `mode` parameter and pass `ArenaMode.race` (from: n9d2)
- **should** packages/test_game/lib/src/arena_hud_widgets.dart:40 `ArenaHud` has 7 named constructor parameters (limit 5; it had 5 before this run) → group `round` and `rounds` into one value object (needs Claude's design; see Open questions) (from: n9d2)
- **should** packages/test_game/lib/src/arena_view_widgets.dart:23 `ArenaBoard` has 8 named constructor parameters → same value object as above, passed as one parameter (from: n9d2)
- **should** packages/party_host/lib/src/ui/game_screen_shell.dart:11 `GameScreenShell` has six named parameters (limit 5) → value object for `canPop` and `onPopInvoked`; needs a new file outside n9d1's allow: (needs Claude's design) (from: n9d1)
- **should** packages/test_game/lib/src/arena_hud_widgets.dart:192 `_hurrying` is a boolean that does not read as a question → rename to `isHurrying` (from: n9d2)
- **should** controller_app/test/connect_identity_gap_test.dart:77-78 the comment cites `connect_screen.dart:348` and `:102`; `connect_screen.dart` is 332 lines now and the manual row moved to `connect_manual_entry.dart` → update the comment to the current location (from: n9a)
- **should** packages/test_game/lib/src/arena_map_names.dart:4-10 the names of the bundled maps are hard-coded in lib, which the guidelines forbid; the only guard is the drift test at `arena_hud_map_test.dart:91` → owner decides: keep the table with the drift test, or read the name from the loaded map (needs owner decision) (from: n9d3)
- **should** docs/briefs/m16/wave1-789/n9d3-report.md:5 and :42-43 say "no view or session holds the loaded ArenaMap"; `packages/test_game/lib/src/arena_field.dart:64` (`final ArenaMap map`) and `arena.dart:67` hold it → correct the Summary and the commit draft to say the map lives on the host's game object and the HUD gets only the id (from: n9d3)
- **should** docs/briefs/m16/wave1-789/n9c-report.md:1 is a driver note with no Summary and no review-rules part A self-check → add the six one-line answers, or the owner accepts the driver note in its place (from: wave1)
- **should** docs/decisions.md (grep: no entry for "Nov 24" or "item 9") the owner's hurry decision for the Bumper clock has no entry with its reason; the reason lives only in the comment at `arena_hud_widgets.dart:71-74` → add a decisions entry (from: n9d2)
- **should** controller_app/lib/src/ui/settings_screen.dart:247, controller_app/lib/src/ui/gyro_dialog.dart:129, controller_app/lib/src/ui/stick_dialog.dart:114 the sliders now give a screen reader their value (n9c) → Fixed, unverified: needs device check (the tests read the semantics tree, not a screen reader's wording; the dialog lines read the whole "label: value" text, which the owner must confirm) (from: n9c)
- **could** controller_app/test/slider_semantics_test.dart:30-58 and packages/party_host/test/volume_semantics_test.dart:11-33 `_spokenValues` and the row helpers are copied in both files → one test support file, when the next slider test needs them (from: wave1)
- **could** packages/party_host/test/night_awards_flow_test.dart:132 the literal `'Not won tonight'` repeats `NightText.notWon` (`packages/party_host/lib/src/text/night_text.dart:53`), and :135 `_names[id]!` uses `!` with no line proving the key exists → use the constant, and `expect(name, isNotNull)` before the lookup (from: n7a)
- **could** packages/test_game/lib/src/arena_hud_widgets.dart:184-187 `_roundLabel` takes the number from `round` when both are set and from `snapshot.round` otherwise, so two sources give one number → use `snapshot.round` only, unless the brief needs the parameter (from: n9d2)
- **could** docs/briefs/m16/wave1-789/run.log:35-36 HAND-FIX n9c: the tests-first proof exists (run.log 18:23:46 and 18:26:08; done.txt) and the wave1 review exists; the commit 0ba463db ("analyze infos") is a further hand fix in DRIVER-NOTES 18:11 that the HAND-FIX list omits → add it to the run log's HAND-FIX list (from: across jobs)
- **could** packages/party_host/lib/src/ui/game_screen.dart 363 lines, against the 355-line target of n9d1 → accept 363 and drop the target, or move the `_leave`/`_next` helpers in a job that may touch that file (from: n9d1)

## Open questions

1. The 568x320 TV overflow: fix the top bar in its own job, or name it as an exemption for that size and look? Suggest: fix it, and remove the blanket filter until then. (connect_narrow_test.dart:61)
2. The bundled names table: keep it with the drift test, or read the name from the map file? Suggest: keep it until a wire change needs otherwise. (arena_map_names.dart:4)
3. The volume test's tests-first exemption: accept it, or require the callback to be tested? Suggest: require the test. (n9c.md:5)
4. Discarded uncommitted edits (22 files from n9a's churn revert, 3 `tv_test_app/windows/flutter/` files from n7a and n9d3): recover them, or accept? Suggest: check `git status` for the 22 PNGs in `docs/design/` and `site/shots/` first; accept them if they are regenerated artefacts.
5. `game_screen.dart` at 363 lines against a 355 target: accept or move more? Suggest: accept 363.
6. `GameScreenShell` six parameters: a value object in a new file, or accept six? Suggest: value object.
7. `ArenaHud` and `ArenaBoard` round/rounds: one value object, or keep the parameters? Suggest: one value object.
8. The round label's source (`round` or `snapshot.round`): suggest `snapshot.round` only.
9. "Round N of M" on every ArenaView that gets `rounds` (arena_view.dart:201-202), or only the night? Suggest: keep it everywhere, as the brief asked.
10. Dialog sliders read the whole "label: value" line: suggest keep, it matches the shown text.
11. The tie reveal fault (n7a): run `flutter test` on the file directly and read the exception before unskipping. Suggest: do this before the tie tests are accepted.
12. Missed-reveal wait of `nightAwardMissedRevealMs` (2000 ms) instead of `nightAwardRevealMs`: suggest keep it and say so in the report (night_awards_flow_test.dart:140).
13. Add `export 'src/arena_map_names.dart'` to `lib/test_game.dart`: suggest yes, in a job whose allow: names that file.
14. The base `analyze` failure at run.log 18:19: cause not recorded; suggest check the log under `.dart_tool/run-jobs/` before the next wave.

## Numbers against targets

- `game_screen.dart`: 363 lines against the 355 target (n9d1). Misses by 8.
- Connect at 568x320 TV: 12 px overflow (n9a) against "fits every size in both looks". Misses; the test filter hides it.
- Night awards: 2 of 4 tests run; the tie rule (PRD item 7) has 0 running tests. Misses.
- Widget parameters: `ArenaHud` 7, `ArenaBoard` 8, `GameScreenShell` 6, against a limit of 5. Misses on all three.
- `_playNight`: 59 lines against ~40. Misses.
- Connect row at 320 dp: chip 0 to 309.3 dp and the 45 px overflow fixed by the `Flexible` change (measured, n9a). Met at 320x640.
- Line counts: `arena_hud_widgets.dart` 366, `settings_screen.dart` 370 and `game_screen.dart` 363 are under 380 and 400, but over the ~300 guide. `connect_screen.dart` 332 (was 378).
- Test counts, unverified: n9d2 "18 tests in two files" (grep: 25 `testWidgets` across three files); n9d3 "OK 4 tests" for the package (the new file has 3, the fourth is not named).

## Could not check

- No tests, analyze or format were run: this review is read-only, and `tools/mine.sh` reverts generated files.
- The Flutter SDK's default `Slider` semantics value was not read, so the exemption's premise is unverified.
- Screen-reader wording and the `bad` colour on the TV look are looks and devices, not readable from code.
- `controller_top_bar.dart:89` (the 12 px overflow source named in run.log 18:18) was not read.
- The tie reveal's exception text was not read (n7a, n7a question 1).
- Whether the discarded generated edits mattered: this tree shows them modified at the start, and nothing here can restore them.
- `docs/decisions.md` was checked by grep only, not read.
- `STATUS.md` does not exist in the brief folder, so the status rows were not compared with it.
- PRD item 7 and the coding-guidelines files were used through the worker extract, not read in full.

## Commit message — a draft

docs: review of the wave1-789 run (findings for Claude)

Read-only review of the run's commits 8168e09e..7da6e34d, as one change.
Adds docs/briefs/m16/wave1-789/REVIEW.md only. Six must findings: a
BISECT early return left in n7a's test, a blanket overflow filter that
hides the 568x320 TV overflow, the Best text turning red, a volume test
that passes on the old code, and two analyzer ignores. Owner calls open:
the names table, the discarded generated edits, and the 6-parameter widgets.

## Status row

wave1-789 run review: needs Claude's design. Open: six must findings (BISECT line 128 in night_awards_flow_test.dart, the overflow filter in connect_narrow_test.dart, "Best" red in arena_hud_widgets.dart, volume test passing on old code, two ignores); design calls (round value object, GameScreenShell params, names table); discarded generated edits for the owner.

## Delete

- none
