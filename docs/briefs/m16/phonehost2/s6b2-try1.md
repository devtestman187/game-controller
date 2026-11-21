# S6b2 — puzzle results in HostFrameScreen

## Summary

**Stopped before any lib change: the brief's `allow:` list cannot come out clean.** The new layout moves
every button `_SeriesButtons` builds into the footer (first + Back) or the body as new widgets with the same
keys, so its only reference — `puzzle_results_widgets.dart:100` — goes. `_SeriesButtons` lives in
`puzzle_continue.dart`, which is not in `allow:`, and it becomes an unreferenced private class:

```
warning - lib\src\ui\puzzle_continue.dart:94:7 - The declaration '_SeriesButtons' isn't referenced.
          Try removing the declaration of '_SeriesButtons'. - unused_element
```

`tools/check.sh` runs `dart analyze --fatal-infos` over `packages/party_host`, so that warning fails the job.
I proved it by replacing that one call with `const SizedBox.shrink()` in an allowed file and running
`dart analyze packages/party_host`, then put the line back; the only declaration orphaned is `_SeriesButtons`
(`_ShuffleSwitch` is reused by the body's Shuffle; `_SeriesOptions` and `_Shuffle` stay used by `_ResultMenu`
and `_ShuffleSwitch`).

**The ask:** add `packages/party_host/lib/src/ui/puzzle_continue.dart` to `allow:` (to delete `_SeriesButtons`
and its now-unused doc comment), and the job is a straight run of the plan below. Nothing else outside the
brief's allow list is needed; I checked every test that touches the results.

Everything below is measured or read, so the next brief can be the same plus one allow line.

## Plan (what the next run of this job does)

- **The results stay over the board.** `_cardShown` swaps the current
  `Center(SingleChildScrollView(...))` at `puzzle_screen.dart:351-368` for a `Positioned.fill(_Results(...))`;
  the play view must stay mounted: `end_night_puzzle_test.dart`'s `roundPoints` reads
  `PuzzlePlayViewState` from the results card, and `_photos()` reads `_play.currentState?.match`.
- **`_Results` becomes a `HostFrameScreen`** (like `ArenaResults`, `arena_results.dart:114`):
  - **title**: `HostText.shapeRace`. The results' own headline stays in the card (see below), so
    `find.text('Done!')` / `'Left wins!'` / `'Draw!'` stay single. No new string.
  - **footer**: outside a night `[first, resultsBack]` (first = the menu's key: `nextPuzzle` /
    `continueLevel` / `playAgain` / `rematch`, with `_againFocus`); a night's round before its last
    `[next, endNight]`; a night's last round `[next]` — `night_round_test.dart:218-221` expects no
    `resultsBack` on a night round (the first of three), so a night never gets one.
  - **body**: one full-stage-width `ToyCard` (key `puzzleResults`), `Row`:
    - left: the photos (`_photos()`, unchanged: `PuzzlePhoto` keyed `puzzlePhoto-<side>`);
    - right: headline (`Text`, key `puzzleResultTitle`, on a chip in the results colour), the series prompt,
      the per-side rows, and under them the secondary controls in a `Wrap` of **compact** `HostButton`s:
      Shuffle (through `_ShuffleSwitch`, key `shuffle`), Play again (`menu.replay`, key `playAgain`/`rematch`),
      Change teams (key `changeTeams`). No night and no `any <level>` round draws them.
- **The wire colours:** the old `ToyCard.headerKey`/`headerColor` band goes (the brief's card has no band);
  `puzzle_results_test.dart:306` and `:411` are rewritten to read the headline chip's colour (same intent: the
  results are headed in the winning side's colour), not dropped.
- **The walk (planned):** the focus still starts on the first footer button (`_againFocus`). From it, `up`
  enters the body column at its bottom button and `up` again walks the wrap upwards; `down` walks back to the
  footer and `right` reaches `resultsBack`. `host_focus_ring_test.dart:221-250` is rewritten to that order
  (body column first, then the footer) with the same keys, and `puzzle_results_test.dart`'s two walks
  (`:85-97`, `:173-194`) are rewritten the same way, keeping what they check (every direction lands on one of
  the five, and `up` + `down` comes back to the first button, which A presses).

## Measured values (frame px, with the look's real fonts)

Frames and bodies (the five devices, as `host_frame_screen_test.dart` has them): 640x360 → 960x540, body 392 ·
852x393 → 1170.687x540, body 392 · 1024x768 → 960x720, body 572 · 1280x800 → 960x600, body 452 · 1920x1080 →
960x540, body 392. Card width = frame − 2 × 24 gutter: 912 · 1122.687 · 912 · 912 · 912. Card content height at
the three 540 frames = 392 − 2 × 24 padding = 344.

Secondary buttons at the frame's 28 px type, with icons (measured in a throwaway test, now deleted):
**Shuffle 267.3, Play again 327.7, Change teams 399.9**; 1018.9 with the two 12 px gaps. So they never share a
row of the card's column (right column ~532 in a 960 race, ~682 solo, ~742 at 852x393) — the `Wrap` gives two
rows at 960 and one at 852x393, with **`compact: true`** (dense = 0.75 × buttonHeight = 48 at a TV look's 64,
36 at a phone look's 48; labels at the frame's 22 px body type).

Rows: badge floor 37 (`badgeNumberMinDiameterPx`, so a phone look's 36 grows to 37) + headroom 16.65 + 4 =
**57.65 each**, two in a race = 115.3.

Height check, TV look, a 960 frame race: headline 33.6 + 12 + dense wrap 2 × 48 + 12 + 108 + 12 + 115.3 = **280.9
of 344** (63 px slack); phone look 256.6. With the full-size buttons it would be 389 — over 344, which is the
second reason the old five-button wrap cannot survive in the body.

Photos: height 2 × buttonHeight = 128 at the TV look, 96 at a phone look; width = height × 80/72 (the board is
80x72) → 142.2 / 106.7, a race's pair 292.4 + the 8 px gap. Right column: 960 race 848 − 292.4 − 24 = 531.6 ·
960 solo 681.8 · 852x393 race 742.3 · solo 892.5.

Footer pair without icons: Play again 291.7 + Back ~153 + 16 = **~461 ≤ 480** (DESIGN section 3's footer
budget); with icons 531.7 > 480, so the two go without icons, as `ArenaResults` did (`arena_results.dart:146`).

## Tests owed (tests first, next run)

`test/puzzle_results_layout_test.dart` (new), the five-device table from `puzzle_results_frame_test.dart`, the
`PuzzleScreen` mounted inside `_InFrame` as its home (the frame's arrow needs a route to pop, so the walk test
mounts it the way `puzzle_results_test.dart` does), a round finished with `lockEveryPiece` + `endRound`, five
cases: a 2-player race, a 4-player one-board round, a night's round before its last (End night), its last round
(Next alone), and a series round (Next puzzle + the three secondary controls). Each case asserts: no
`Scrollable` inside `hostFrameBody`; no exception; every footer button's rect inside `hostFrameFooter`'s rect;
every secondary button's rect inside the body and right of the photo; the card's width = frame − 48; every
`Text`'s style ≥ 20 px; the headline chip's colour. Plus the five-size walk in `host_focus_ring_test.dart` and
the two walks in `puzzle_results_test.dart`.

## Questions

1. **`puzzle_continue.dart` in `allow:`?** That is the only blocker: one line to delete `_SeriesButtons`
   (`:89-166`); `_ShuffleSwitch` stays (reused), the two typedefs stay used.
2. **"Stars"** (DESIGN section 4): the results have no rating and no new strings are allowed; is the star the
   new-record chip's (`_NewRecordChip`) what the card should show, or is a rating wanted (new behaviour, text
   and rules data)?
3. **"Per-player pieces (names 24 px, pieces 20 px)"**: nothing keeps a per-player piece count
   (`MatchResult` is per side; only a night's `RoundResult.lines` is per player), so the plan draws each side's
   badges, a race's Left/Right label at 24 px and its pieces/time line at 20 px. Should the row instead name
   each player (`GamePlayer.nickname` exists) — and where does its piece count come from?
4. **A night's last round**: is the footer `[Next]` alone (my reading, matching `night_round_test`), or
   `[Next, Back]` as the "no Back before its last" sentence implies for its last?
5. **The winning colour**: the old card band carried it. Is a chip behind the headline right, or should the
   results colour disappear from the card now that the frame's header carries the screen?

## Suggestions

- A `HostButton` at the frame's type is 267–400 px for these labels; the arena's "no icons or the pair wants
  487" is the same fact. A `HostButton(width: …)` or a measured "fits the footer's 480" helper would keep
  later briefs from re-measuring.
- `_SeriesButtons` and `_ShuffleSwitch` could move to `puzzle_results_widgets.dart` in the next run, next to
  the layout that uses them, if the file's size allows (it is 248 lines).

## Self-check (review-rules part A)

1. **Every host setup** — nothing changed: no code shipped. The plan keeps the keys and the focus node, and
   `HostFrameScreen` is the same on every host. Test: none (stopped).
2. **When kept state starts and ends** — nothing changed. The plan keeps `_cardTimer`/`_cardShown` as they are.
   Test: none (stopped).
3. **How a new state combines with the others** — nothing changed; the results' `Positioned.fill` stays inside
   the same `Pausable`/`PopScope`/`Focus` wrappers. Test: none (stopped).
4. **Stay in the job's folder** — `git status` shows one new file inside `allow:`
   (`packages/party_host/test/puzzle_results_layout_test.dart`, the throwaway measurement, listed under
   Delete) and this report; the `run.log` and `tv_test_app/windows/flutter` changes were there before me.
5. **Stop rather than overstep** — this report: `_SeriesButtons` needs `puzzle_continue.dart`, outside
   `allow:`; proved with `dart analyze`, not guessed.

## Hand-over

- The layout and the numbers are ready (above); the next run of this brief needs one extra `allow:` line
  (`packages/party_host/lib/src/ui/puzzle_continue.dart`) and answers to Q2–Q5, then it is tests first in
  `test/puzzle_results_layout_test.dart`, the `_Results` rewrite, and the four test files to fix.
- The measurer: `packages/party_host/test/puzzle_results_layout_test.dart` holds the button widths at the
  frame's type; it is listed under Delete so the next run writes the real layout test at that path.

## Checks

`tools/check.sh format analyze host phone`: format PASS, analyze PASS, phone PASS, host PASS on the second
run. The first full run failed one host test, `live_stats_share_test.dart` ("a phone that said no is left out
of the upload": the two ids came back in the other order); it passes alone and on a clean re-run of the suite,
and no lib file changed in this job, so it is an ordering flake, not this diff.

The `phone` suite rewrites the pictures in `site/shots/` (`controller_app/test/site_shots_test.dart`), so
`git status` shows those PNGs as modified after a check run. Not this diff; left as they are.

## Commit message

Stop S6b2 before the results layout: _SeriesButtons needs an allow line

- The new results put every button `_SeriesButtons` builds into the footer or the body as new widgets with the
  same keys, so its only reference goes; the class is in `puzzle_continue.dart`, outside `allow:`, and
  `dart analyze --fatal-infos` reports `unused_element` (proved, then reverted). No lib or test behaviour
  changed.
- `allow:` needs `packages/party_host/lib/src/ui/puzzle_continue.dart` to delete `_SeriesButtons`;
  `_ShuffleSwitch` is reused by the body's Shuffle and the two typedefs stay used.
- Measured for the next run: the secondary buttons at the frame's 28 px type (267.3 / 327.7 / 399.9 px), the
  card's column and height budgets, and the footer pair at ~461 ≤ 480 px without icons.

## Status row

S6b2 stopped before the results layout: the plan, the measured frame numbers and the tests owed are in the report; open — `puzzle_continue.dart` must join `allow:` to delete the orphaned `_SeriesButtons`, plus answers to Q2–Q5 (stars, per-player pieces, a night's last-round footer, the winning colour).

## Delete

- packages/party_host/test/puzzle_results_layout_test.dart

