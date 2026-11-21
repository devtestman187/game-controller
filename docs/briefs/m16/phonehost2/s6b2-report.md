# S6b2 report — the Shape Race results in the host frame

## Summary

The results are now a `HostFrameScreen`: the frame's header names the screen (with its back arrow when there is a
route to pop), the body is one full-stage-width card, and the footer holds the way on alone. The card keeps what it
showed before — the headline on a chip in the round's colour, the series' level-done prompt, the per-side rows (side
name, badges, time or pieces, best time, New record chip) — with the finished picture(s) at its left and the words
at its right. Shuffle, Play again (a series' replay) and Change teams became compact buttons under the rows in the
card's right column, with the keys they had. Tests came first: a new five-device, five-case layout test; then the
two walks the layout moved were rewritten (puzzle_results_test, host_focus_ring_test) and the two reads of the old
card's header colour now read the new chip's colour. `tools/check.sh format analyze host phone` passes.

`puzzle_screen_test.dart`, `screen_fit_test.dart` and `best_times_test.dart` passed unchanged, so neither was edited.
`test/puzzle_continue_test.dart` (outside `allow:`) failed at 852x393 with a 27 px overflow: the three compact buttons
in a `Wrap` took a second run under the test's box font, in the 245 px body an unframed 393-high phone leaves. The
card now lays its controls out as a `Row` of `Flexible` buttons — the pattern the frame's footer already uses — so
they share one line and the look ellipsises a label where a host is too narrow, and that test passes untouched.

## Sizes (frame px, measured at 960x540 inside `hostFrameBuilder`)

Before (the card over the board, HEAD): header band on the card, `ToyCard` padding 32 h / 24 v, photos on a row
under the header with a 16 px gap, the rows, a 24 px gap, then the buttons in a `Wrap`; no frame, so no fixed header
or footer and the screen's own title bar above the card. After:

| part | size | where |
| --- | --- | --- |
| frame header | 64 high (0–64) | title left, back arrow at x 24–72 |
| frame body | 392 high (64–456), 24 gutter | the card |
| frame footer | 84 high (456–540) | its buttons 48 high, y 474–522 |
| card | 912 wide (960 − 2×24); 183.2 high (series solo) · 229.4 (2-player race) | top of the body |
| card padding | 24 h / 8 v (the Arena results' `_cardPadding`) | |
| headline chip | 103 × 54 solo, 155.5 × 54 in a race; words at the button type in ink | at the column's top |
| photos | 96 high (2 × buttonHeight at the 48 look); 106.7 solo, 92.9 each in a race | at the card's left |
| side name | 24 px | in the row's `Wrap` |
| time or pieces, best time | 20 px (the frame floor) | in the row |
| badges | 36 (0.75 × 48), floored at 37 inside the frame | in the row |
| rows | headroom 16.2 + line + 4 each | under the prompt |
| Shuffle / Play again / Change teams | 36 high; 152.4 / 184.2 / 222.1 wide, one run solo | right column |
| Next puzzle / Back | 202.5 / 110.2 wide, 48 high | footer, x 607.3–936 |

## Where each button went

- **The first button** (Rematch, Play again, Next puzzle, or a night's Next) and **Back** (`resultsBack`, pops the
  round): the footer, right end, without icons (with them the pair wants over the 480 px the footer keeps beside the
  rest). A night's round before its last: **Next, End night**, no Back; the night's last round: **Next** alone.
- **Shuffle** (`shuffle`, the series' switch), **Play again** (the series' `playAgain`) and **Change teams**
  (`changeTeams`): compact buttons in one `Row` under the rows in the card's right column. A night's round draws
  none; an `any <level>` round draws Change teams only.
- **The header's back arrow** (`hostTitleBarBack`): pops the round, as the old title bar's did.

## The walk, before and after

Before (card over the board): from Next puzzle, Right → Shuffle, Right → Play again, Down → Back, Left → Change
teams; Up + Left came back to Next puzzle. `host_focus_ring_test`'s race read: Next puzzle → Right Shuffle → Right
Rematch → Down Back → Left Change teams.

After (measured with a throwaway probe, now deleted):

- Next puzzle (footer) → Up Change teams → Left Play again;
- Left Shuffle → Left the header's arrow (it sticks there) → Down Shuffle;
- Down Next puzzle → Right Back.

`host_focus_ring_test` now reads Next puzzle → Up Change teams → Left Rematch → Left Shuffle →
Down Next puzzle → Right Back: the same five keys, the body column first and the footer after,
which is the order a thumb or a remote takes.

## What changed

- `puzzle_screen.dart`: the results mount is `Positioned.fill` over the kept-mounted board (its last frame is the
  photos) and hands the card the night's flags, the puzzle, the match and the round's best-time results.
- `puzzle_results_widgets.dart`: `_Results` builds the `HostFrameScreen`; the card, chip, rows and controls are
  private widgets in the same file; the footer's two shapes (the way on with Back, a night's Next with End night).
- `puzzle_screen_widgets.dart`: `_ResultButtons` deleted (`_AgainButton` stays).
- `puzzle_continue.dart`: `_SeriesButtons` deleted; `_ShuffleSwitch` takes `compact` (default false) so the card's
  copy is the dense button with the same key.
- Tests: new `puzzle_results_layout_test.dart` (five devices × five cases, plus the chip's colours and the header
  arrow's pop); `puzzle_results_test.dart`'s two walks and two colour reads; `host_focus_ring_test.dart`'s walk.

## Tests

- `test/puzzle_results_layout_test.dart` (new, 28 tests): every case at 640x360, 852x393, 1024x768, 1280x800 and
  1920x1080 inside `hostFrameBuilder` — no exception, no `Scrollable` in the body, every footer button inside the
  band and hit-testable, no other footer keys, the card's width = frame − 48, the photo left of the headline, every
  text ≥ 20 px; the chip's colour for a player win, a draw and a night's round; the focus starting on the footer's
  first button and the header's arrow popping the round.
- `test/puzzle_results_test.dart`: the phone's walk and the stick's walk read the new order; the card's heading is
  read from the chip (`puzzleResultChip`'s `BoxDecoration` colour) instead of the deleted header band.
- `test/host_focus_ring_test.dart`: the results' walk rewritten as above, every key still ringed.

## Self-check (review-rules part A)

1. **Every host setup** — the same card at all five device sizes inside the frame
   (`puzzle_results_layout_test.dart`), and `screen_fit_test`'s 852x393 phone look passes; a joined phone draws its
   own card and is not touched (the host's screen only).
2. **When kept state starts and ends** — no new state: the card still appears only after `Celebration.totalMs`
   (`puzzle_results_test`, 'the results card waits for the finish celebration'), and the night's flags come from
   `partyNightProvider` as before (`night_round_test`, `end_night_puzzle_test`, unchanged and passing).
3. **How a new state combines with the others** — the card is still mounted over the board in the screen's `Stack`
   (the board stays mounted for the photos), the pause menu is a route above it as before, and the header's new
   arrow pops the round: the layout test's 'the way on keeps the focus as the card comes up, and the header's arrow
   pops the round'.
4. **Stay in the job's folder** — only files in `allow:` were written (the four lib files, three test files, the new
   test and this report); the other changed files in the tree are the parallel jobs' (their reports are there too).
5. **Stop rather than overstep** — nothing needed a file outside `allow:`; the one outside-allow test that broke
   (`puzzle_continue_test.dart`) was left as it is and the card made to fit instead.

## Hand-over

- The card's controls are a `Row` of `Flexible` compact buttons, not the `Wrap` the plan measured: a second run is
  44 px the 245 px body of an unframed 393-high phone screen does not have. On a device the three fit one run at
  every supported size (measured 582.7 of the 681.8 solo column at 960); a narrower host ellipsises a label, which
  the look's button already does (the frame footer's rule).
- `_ResultButtons` and `_SeriesButtons` are gone; the results draw their own footer. Anything else that looked for
  `_ResultButtons`' keys finds them on the card or in the footer.
- The measured numbers in "Sizes" are this harness's look (frame titles, 48 px buttons); a TV look's photos are
  142.2 × 128.

## Questions

1. The controls' one `Row` (labels ellipsise) replaced the `Wrap` (a second line): the 393-high phone screen without
   the frame's scale has no room for the second line under the test's box font. If two runs are wanted there, the
   card needs ~30 px more room in a 245 px body (the rows' badge headroom is the only slack I see).
2. A series' solo card is 183 px of the 392 px body: the picture could be larger than 2 × buttonHeight. Kept the
   brief's size (`_photoShare`), since the design draws it so.

## Suggestions (not acted on)

- `test/puzzle_continue_test.dart` measures with the box font, which is what made its card the narrowing case; adding
  `loadLookFonts` there (as the layout tests do) would measure a device's text. Outside this job's `allow:`.

## Commit message

Draw the Shape Race results in the host frame

- The results are a HostFrameScreen: the way on and Back in the 84 px footer (a night's Next with End night, no
  Back, before its last; Next alone on it), the card full stage width with the pictures left and the words right.
- Shuffle, Play again and Change teams are compact buttons under the rows in the card's right column, same keys, in
  a Row of Flexible buttons so their labels never take a second line.
- The headline sits on a chip in the round's colour (the winner's, the focus yellow for a draw, good or caution for
  one board); names at 24 px on the frame's 20 px floor for the times.
- _ResultButtons and _SeriesButtons deleted; _ShuffleSwitch takes compact.
- Tests: a new five-size layout test (five cases); puzzle_results_test's and host_focus_ring_test's walks read the
  new order; the header's arrow pops the round.

## Status row

S6b2 done (try 2): Shape Race's results drawn in HostFrameScreen at five sizes, tests first (28 new layout tests), the walk rewritten (body column, then footer); open — the card's controls use a Row of Flexible buttons where the older harness's 245 px phone body could not hold a second Wrap run (see Hand-over).

## Delete

- none
