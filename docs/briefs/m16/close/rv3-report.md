# rv3: milestone-end review, packages, tools and docs (fb2f6a5e..6300f506)

## Summary
Verdict: no protocol change and no blocker. Counts: must 0, should 3, later 3.
Top three:
1. should: the new Arena HUD tests (round, map) never run at large text or an iPad window (A6).
2. should: the pause "other layout" and the volume semantics tests run at the default test size only, in one host look (A6).
3. should: the phone-host night-awards tests cover the menu look only (A1/A6).

Protocol: `git diff fb2f6a5e..6300f506 -- packages/protocol` is empty. No message shape changed. The `connection` changes are log text, `ClientProblem` detail text and one close-reason string (see later 1).
Files read: every `packages/*/lib` hunk of the range, the tools diff stat, the release/version/apply-job/check-par/flash/smoke tools, the docs diff, and the test names and sizes of the new tests. I ran no test.

## Findings
- **should** packages/test_game/test/arena_hud_round_test.dart:41 A6: the round test draws the HUD at 960x540 only, and `arena_hud_map_test.dart:62-65` at 960x540, 812x375 and 390x844. Neither uses large text or an iPad window. The new `Wrap` row now holds map name, "Round N of M", clock and Best (`arena_hud_widgets.dart:326-333`), so the one-line bar at 812x375 with 1.3x text may wrap into a clipped second line, and no test would show it -> add a 1.3x text case at 812x375 and one at 1024x768, asserting no overflow.
- **should** packages/party_host/test/pause_resume_label_test.dart:30 A6: the test checks which layout each phone gets and does not pump the pause menu in the TV look or a small window. The `otherLayout` logic is in `controller_menus.dart:176-183` and is look-free, so the risk is low, but the pause card's look is not covered by this test -> state in the self-check that the pause card is covered elsewhere, or add one TV-look case.
- **should** packages/party_host/test/night_awards_flow_test.dart:200 A1/A6: the phone host runs at 640x360 in `HostLook.menu` only (lines 200-205), never in the TV look or at 320x640 / 568x320 -> add the portrait and 568x320 sizes for the phone host.
- **later** packages/connection/lib/src/host_connection.dart:193 wire: the close reason string changed to 'The Thumb Party TV app uses protocol v…'. It is text in the close frame, not a message shape, so it is allowed. An older phone shows its own text and ignores the reason. Nothing to do; noted so nobody reads it as a protocol change.
- **later** packages/party_host/lib/src/ui/game_screen_shell.dart:24 G (dartdoc): the public `GameScreenShell` constructor has no dartdoc (`ShellBack` has one at line 11) -> one line of dartdoc.
- **later** packages/puzzle_game/lib/src/play_view.dart:123 and packages/test_game/lib/src/arena_hud_widgets.dart:300 G2: the text 'Round $n of $m' is built in two packages, outside the string table -> one shared helper or table entry when a third place needs it.

Checked and fine: `arena_map_names.dart` is guarded by a test against the map files (`arena_hud_map_test.dart:96`); the hurry boundary (15000 bad, 15001 ink, 1 bad, 0 ink) is tested on both looks (`arena_hud_round_test.dart:87`); new puzzle label tests use the new `roundLabel` argument, so they fail to compile on the old code; no touched lib file is over 380 lines (largest: host_text.dart 379, puzzle_painter.dart 368, game_screen.dart 362, arena_hud_widgets.dart 351); `GAME_SCREEN_SHELL` keeps the Back guard, claim and focus order of the old build; `UPDATE_GOLDENS` stops the tests writing PNGs in the tree. The tools changes (tag-to-version, release.sh, apply-job, check-par, flash model, sync-agents, smoke text) agree with each other and with `docs/release.md`; `app_info.dart` in both apps reads `APP_VERSION`, and `release.sh` no longer checks a pubspec version, as `docs/release.md:12` says. The coverage floor 92.9 -> 92.8 is a decided item.

## Combination table (A3)
| Combination | Status |
|---|---|
| Pause menu: only resumers see Resume, others keep the menu label | tested by pause_resume_label_test.dart:30 and :50 |
| Pause menu with nobody who may resume here | tested by pause_resume_label_test.dart:65 |
| Pause menu look (TV and menu) | not tested in that test |
| Host away / player away at the Round label or the HUD | not tested (the HUD takes round numbers only) |
| "Get ready" with the new HUD or shell | not tested in these packages |
| Dropped link | not touched by this range (text only in connection) |
| Results and leaving: Back on the results through `GameScreenShell` | not tested in these packages; the shell keeps `canPop: _stage != results`, and tests of the old build still cover it |
| Night awards, tie and no tie, both looks and phone host | tested by night_awards_flow_test.dart:190-205 |
| Round label on one board, cut short of the clock, two boards | tested by round_label_test.dart:72-93 at 640x360 and 360x640 |
| HUD map name, known and unknown id, both looks | tested by arena_hud_map_test.dart:69 and :85 |
| Volume slider speaks its percentage, each palette | tested by volume_semantics_test.dart:38 |

## Could not check
- I did not run any test or `tools/check.sh`, so "fails on the old code" is judged by reading (compile error for new parameters; the pause and volume tests assert new behaviour).
- The look of the phone-host Arena HUD with the round label on a joined phone: a phone's `ArenaViewer` passes no round (`arena_module.dart:56`), so it shows "Round N" (decided).
- The tools tests (`tools/tests/*.sh`) were read by name only; `docs/code-health.md` already notes they are not wired into check.sh.
- `.github` and `codemagic.yaml` were out of scope; I only grepped them for `APP_VERSION`.

## Commit message
m16 close: rv3 review of packages, tools and docs

Read-only milestone-end review of fb2f6a5e..6300f506 for connection,
game_kit, party_host, puzzle_game, test_game, tools and docs.
No protocol change, no must. Three should (A6 sizes and large text on
the new HUD and phone-host tests), three later.

## Status row
rv3 done: packages, tools and docs reviewed, no must, no protocol change; open: 3 should (large-text and iPad cases for the new HUD and phone-host night tests), 3 later.

## Delete
- none
