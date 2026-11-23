# B-037 report: winner badge 48 px, crown on the rim, rank number fits its disc

## Summary

- New tests (`score_row_winner_fit_test.dart`, 3 tests, each run in the menu look and the TV look via `forEachLook`) failed on the old code and pass now:
  - badge width is 48 px (`PlayerBadge` box, exact).
  - crown's bottom edge sits 2 to 6 px over the disc's top and is centred on it (the design value is 4 px).
  - the rank "1" in the 32 px podium disc is inside the disc on all four sides and at most 0.6 of the disc high (19.2 px).
- The winner row stays `scoreWinnerRowHeightPx` (68 px). No other row size, text or colour changed.
- The rank's font is capped at 0.55 x 32 = 17.6 px (the brief's step 3), with the line height set to 1.0 so the text box is the font size. At the old line height the box was 25.0 px tall for a 17.6 px font, which is over 19.2 px. Without the height change the cap alone fails check (c).
- The 17.6 px number is under DESIGN rule 3's 20 px floor. A 20 px number would need a disc of at least 36.4 px (20 / 0.55), and the disc is the rank's 32 px column. I used the largest size that fits, as the brief says. This is a decision for the design owner (see Questions).
- Checks: `tools/mine.sh` OK (format, analyze, 4 touched-test tests). `flutter test` on the 5 named files plus the new file: 49 tests, all passed.

## Hand-over

Files changed (all in `packages/party_host`):

- `lib/src/ui/score_row.dart`: `scoreWinnerBadgePx` 58 to 48 with a new doc comment. New `scoreCrownRimOverlapPx = 4.0`. New `scoreRankTextShare = 0.55`. `_badge` now uses `Stack(clipBehavior: Clip.none)`. The crown is lifted by its own height with `FractionalTranslation(0, -1)` and dropped back by the 4 px overlap with `Transform.translate`, so it sits on the rim and is not clipped.
- `lib/src/ui/score_row_parts.dart`: `_MedalDisc` caps the rank's font at `scoreRowMedalPx * scoreRankTextShare` and sets `height: 1.0`.
- `lib/src/ui/night_scoreboard_widgets.dart`: comment only, "58 px badge" to "48 px badge". `nightWinnerCrownPx` stays 30.
- `test/score_row_winner_fit_test.dart` (new): the 3 tests above.

Files not changed, though named in the brief: `player_badge.dart`, `night_widgets.dart`, `arena_results.dart`, and the 4 other test files. The 5 existing test files needed no pinned-size changes.

Self-check (review-rules part A):

1. Host setups: the new tests run the ScoreRow alone in both looks. Phone, TV and peer-build host screens are not touched by this change; the existing night, arena and puzzle tests ran green (49 tests).
2. Kept state: none added.
3. Combinations with pause, host away, get ready, dropped link, results, leave: the change only affects the winner row's badge and the medal's text. The existing night scoreboard, arena and puzzle result tests pass.
4. Stayed inside allow.
5. Nothing stopped.
6. Looks: menu and TV both tested in the new file. No fixed pixel height was added to a look-sized widget.

## Commit message — a draft

Shrink the winner badge to 48 px and fit the podium rank

- Winner's badge: 58 px to 48 px (DESIGN section 4); the row stays 68 px.
- The crown is seated on the badge's rim (4 px over its top, centred), not floating above it.
- The podium disc's rank font is capped at 0.55 of the disc, with the line height at 1.0, so the number sits inside the disc.
- New test file checks the badge width, the crown's seat and the rank's box, in the menu and TV looks.
- Brief: docs/briefs/m16/bugs3/b037.md (B-037).

## Status row

B-037 done: winner badge 48 px, crown on the rim, podium rank capped to fit its disc (17.6 px, under the 20 px floor), tested in both looks. Open: the design owner's call on the 20 px floor for the rank; the crown's overflow above the row (see Questions).

## Delete

- none

## Questions

1. DESIGN rule 3's 20 px text floor: the podium rank is now 17.6 px, under the floor, because the 32 px disc cannot hold 20 px within the 0.55 share. Should the disc grow, or should the floor be waived for a disc number?
2. The crown is 30 px and the seat puts it 17 px above the disc's top. In the 68 px winner row that is 7 px above the row's own top, so it overlaps the card's padding or the row above. Not checked on a real host screen. Is that acceptable, or should the crown shrink?
3. `arenaCrownPx` (30 px) and its comment ("on the row's 38 px badge") are unchanged. The Arena winner's badge is not enlarged, so I left it alone. Confirm.
4. The exact rendered height of the rank box was not printed. The test asserts it is at most 19.2 px and it passed; the number itself was not captured.
5. `tools/mine.sh` printed "churn: reverted 22 generated file(s)" on the first run. The start-of-session git status listed about 22 modified files (the `docs/design` and `site/shots` PNGs, and `tv_test_app/windows/flutter` plugin files). Those are no longer modified in this worktree, so the script's revert may have discarded uncommitted changes of yours. I could not restore them (git checkout is not allowed here). Please check them.
6. `flutter test` printed "Resolving dependencies" on its first run. I did not check whether that changed `pubspec.lock` at the repository root. `git status` for the package shows only my 4 files.

## Driver note (hand-fix)

The 0.55 cap (17.6 px) failed phone_fit_matrix_test's 20 px floor (night-final, 11 cases). Driver set scoreRankTextShare to 0.625 (20 px in the 32 px disc) and the new test's limit to 0.625; the figures above that say 0.55 / 17.6 / 19.2 are superseded.
