# M12 cleanup c3 — G4 review (read-only)

Job: [c3-g4-review.md](c3-g4-review.md). Read: [c3-g4.md](c3-g4.md), [c3-g4-report.md](c3-g4-report.md), and the
uncommitted diff of `packages/party_host`, `packages/puzzle_game`, `packages/metrics` and `tv_test_app`.

## Findings

- nit docs/briefs/m12/c3-g4-report.md:82 — `_JoinScreenState.build` after is 46 lines (join_screen.dart:241–286),
  not 51; still ≤60, so item 1 holds, but brief item 5 asks for the real count.
- nit docs/briefs/m12/c3-g4-report.md:80 — controller_menus `_tick` after is 27, not 28 (controller_menus.dart:128–154).
- nit docs/briefs/m12/c3-g4-report.md:81 — join_screen `_tick` after is 18 (join_screen.dart:115–132), not 19.
- nit docs/briefs/m12/c3-g4-report.md:23 — says "the four static helpers" and names six (`_statusLine`, `_title`,
  `_detail`, `_playerLabel`, `_mode`, `_time`).
- nit docs/briefs/m12/c3-g4-report.md:90 — `_SessionTable.build` is 48 lines too (stats_screen_widgets.dart:
  173–220), level with `_Figures`, so "the largest new build is `_Figures` at 48, then `_StatsBody` at 41" skips it.
- nit tv_test_app/lib/src/ui/latency_screen.dart:90 — `host.latency(player.id)` is read here for the verdict and
  again in `_Figures` (line 161); HEAD read it once. A map lookup and a record, so no rule is broken.
- nit packages/party_host/lib/src/ui/puzzle_screen_widgets.dart:107 — `result.sides[side]!`: `side` comes from
  `result.sides.keys` three lines up, not from the line before (guidelines §2, `!`).

No must or should: every finding is a count or wording error in the report, or a readability nit in the code.

## Brief — 5 of 5 items done

Nothing missing. Done differently:
- Item 1 "game_screen.dart build": the build over 60 was `DebugOverlay.build` (64 → 38, game_screen.dart:165–202);
  `_GameScreenState.build` was already 46 and is untouched. That is the brief's intent.
- Item 1 sibling files: the three new files are `part`/`part of` files, not separate libraries (precedent:
  packages/protocol/lib/src/messages.dart:3–7). The widgets stay `_`-private and unexported, which is what the
  brief's "sibling file, still not exported" asks for; the screens are 297 / 185 / 294 lines.
- Item 2: the "take it from the widget" option was taken, so `PuzzlePlayView.random` (play_view.dart:88) is a
  fourth required public parameter; item 2 offers exactly that choice, so it stays inside "item 2's required
  parameters". The report's Q1 is answered: allowed as written.
- Item 2: `_pick` now draws its random puzzle from the same `Random` (puzzle_screen.dart:104) instead of its own
  `Random()`; the report says so, and no test or screen behaviour depends on which source picked the puzzle.

## Checked

- `tools/review.sh`: 5 FAIL, 49 NOTE — exactly the report's numbers, and no FAIL is on a line this job adds:
  game.dart:1 (732 lines), game.dart:306 `update` 103, play_view.dart:21 `labels:` 103, play_view.dart:144 `_tick`
  61, match_test.dart:1 (1074 lines). All five are HEAD code: `update`, `_tick` and match_test are unchanged;
  `labels:` was 97 at HEAD and the +2 import lines and the new `random` parameter and field fall inside its span
  (review.sh's known false positive). No FAIL names a member from item 1.
- `tools/review.sh --strings`: "3 removed, 4 added, 397 unchanged or moved", byte-identical to the report's block.
  The added texts: `"Skipped $skipped summaries that couldn't be read"` (report.dart:75) — allowed by brief
  item 3; `'…${formatName(MatchFormat.of(teams))}…'` (join_screen_widgets.dart:127), `'${(intensity * 100)
  .round()}%'` (haptic_panel_screen.dart:197) and `'$durationMs ms'` (haptic_panel_screen.dart:204) — the same
  rendered texts as the three removed ones, only the variable renamed, allowed by brief item 1 (move, no text
  change). Nothing is outside the brief.
- Trees: every extracted widget compared with `git show HEAD:` — join `_SidePanel`, `_Sides`, `_NotJoined`,
  `_JoinButtons`; puzzle `_PlayHint`, `_Results`, `_ResultSideRow`, `_ResultButtons`; stats `_SharingButton`,
  `_ExportButton`, `_StatsBody`, `_SessionList`, `_SessionTable`; game `_DebugTable`; haptic `_Targets`,
  `_EventButtons`, `_Steppers`; latency `_Header`, `_Figures`. Same children in the same order, same keys
  (`side-<name>`, `notJoined`, `joinStart`, `joinBack`, `joinFormat`, `puzzleResults`, `puzzleResultTitle`,
  `puzzleResultLine-<side>`, `rematch`/`playAgain`, `changeTeams`, `resultsBack`, `debugOverlay`, `statsSharing`,
  `statsExport`, `statsStatus`, `session-$i`, `sessionTable`, `panelTargets`, `fire-<event>`, `intensityValue`,
  `durationValue`, `latency-$id`, `inputDelay-$id`, `stageSent-$id`, `stageDrawn-$id`).
- Rebuilds: no extracted widget reads a provider its old code didn't — the only two ConsumerWidgets are `_Results`
  (watched `gamePlayersProvider` before, in the same widget) and `_Targets` (the parent read it before) and
  `_SharingButton` (no watch; it only passes its ref to `askConsent`). No widget lost a `const`; the Theme reads
  that moved out of the parent builds now sit in the widgets that use them, so they still rebuild on a theme
  change.
- Ticks, statement by statement against HEAD (the risk in the split): join's A/B/Start early returns, the `_tap`
  per-key `_teams[p.id]` lookup, `_prune`'s order and `changed`; controller_menus' `only` filter, `_before`
  bookkeeping and repeat timings: same order, same early exits, same values.
- Random: `grep -rn "Random()"` over `packages/puzzle_game`, `packages/party_host/lib`, `tv_test_app/lib`,
  `controller_app/lib` finds one, puzzle_screen.dart:67. All three constructors require it (game.dart:133–136,
  match.dart:82–86, library.dart:33), `match.dart:97/103/107` seeds each `PuzzleGame` from the match's seed, and
  every other caller (all in tests) passes `Random(<seed>)`. The test diffs add only `random:`/`import
  'dart:math';`: no expectation moved, so the report's "no old/new values" is correct.
- Report claims: file line counts by `wc -l`, HEAD counts via `git show HEAD:<file> | wc -l` — 242→261, 255→267,
  367→297, 297→185, 374→294, 228→276, 193→226, part files 137/167/164: all match. Test counts by
  `grep -rn "testWidgets("` + `grep -rn " test("`: metrics 38, puzzle 7+55=62, host 26+18=44, tv 22+0=22, the same
  as at HEAD (no `test(`/`testWidgets(` line is added or removed by the diff).
- Other new builds: `_SessionTable` 48, `_Figures` 48, `_StatsBody` 41, `_Results` 37 — all ≤60.
- Ran, all PASS: `flutter analyze` in tv_test_app ("No issues found"); `dart format --output=none
  --set-exit-if-changed` over the 28 changed/new dart files (0 changed); `flutter test` in packages/party_host
  (44), tv_test_app (22), packages/puzzle_game (62) and `dart test` in packages/metrics (38).
- Scope: only `allow` paths; no controller_app, no packages/connection. The `tv_test_app/windows/flutter/
  generated_*` entries in `git status` have no content diff (line endings only) and are not this job's.
