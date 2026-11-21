# fB (second try) — the reveal's tie fits up to six winners; the band pads evenly

## Summary

Done, per the brief's decisions:

- Winner names on the reveal shrink by count: 40 frame px for one or two winners, 32 for
  three, 24 for four or more (`nightRevealWinnerPx` / `nightRevealTieWinnerPx` /
  `nightRevealTieManyWinnerPx` and `nightRevealWinnerPxFor` in `night_reveal_widgets.dart`).
- Five or six winners draw those 24 px names in two columns of up to three (three rows), so a
  tie of everyone takes 102 px of name height, not 204: `nightRevealTieColumnMinWinners` (5)
  and `nightRevealTieColumns` (2), and a new `_RevealNames` widget that is column-major and
  gives the first column the taller half (five names: 3 + 2).
- The footer band now pads its content by the ink line's width above and below the row, so a
  64 px button stands 10 frame px above and 10 below (it was 12 above and 8 below).
- `games_screen_frame_test.dart:219` pins the new centred value,
  `(84 - 2 * outlineWidth - buttonHeight) / 2 + outlineWidth` = 10 with the TV look. No other
  test pinned the old 12/8 (grep for `outlineWidth` / `buttonHeight` in `packages/party_host/test`).
- `s3-report.md:35-38` now says 10 above / 10 below and names the old 12/8 and the wrong 16.
- New `night_reveal_tie_test.dart` (written first, failed on the old code: a three-way tie
  overflowed by 31 px and the band gave 12 above / 8 below): the 2-, 3-, 4-, 5- and 6-way tie
  at the five sizes — no scrollable, no overflow, the card inside the body, nothing under
  20 px, names at 40/32/24/24/24, one ellipsised line each, and the 5/6 cases in two columns
  of at most three names with one row per name; and the band's even padding at the five sizes.

## Computed values

Card content box: body 392, card padding 32 each side, so 328 px of height at 640x360,
852x393 and the TV, 388 at 1280x800 and 508 at 1024x768. Width at 640x360: card 912,
content 848, badge 190 + 32, so the names' body is 626; two columns are
(626 - 16) / 2 = 305 each (410 and 510 at the two wider frames). The column without names
takes 188 px: award 74 (52 px), 8, 16, reason 37 (26 px), 16, points 37. A line is about
1.42 x its size: 57 at 40, 45 at 32, 34 at 24.

| winners | name px | names | names height | column |
| --- | --- | --- | --- | --- |
| 2 | 40 | one column | 2 x 57 = 114 | 302 |
| 3 | 32 | one column | 3 x 45 = 135 | 323 |
| 4 | 24 | one column | 4 x 34 = 136 | 324 |
| 5 | 24 | two columns, 3 + 2 | 3 x 34 = 102 | 290 |
| 6 | 24 | two columns, 3 + 3 | 3 x 34 = 102 | 290 |

All five are inside the 328 px room; four is the tightest with 4 px spare, five and six have
38. The old code drew three names at 40 (188 + 170 = 358) and the test measured the 31 px
overflow the review predicted. Band: 84 high, ink 4, padding 4 top and 4 bottom, row 76,
button 64, slack 6, so 4 + 6 = 10 above and 6 + 4 = 10 below.

## Files changed

- `packages/party_host/test/night_reveal_tie_test.dart` (new): the five ties at the five
  sizes and the band's even padding; starts from the first try's file, adds the five-way
  case, the two-columns check and the 5/6 rows check, and fixes its four-way case (a
  one-column tie has no three-names-per-column bound).
- `packages/party_host/lib/src/ui/night_reveal_widgets.dart`: the size tiers and their doc
  comments, `nightRevealWinnerPxFor`, the two column constants and `_RevealNames`.
- `packages/party_host/lib/src/ui/host_frame_screen.dart`: the band pads
  `EdgeInsets.symmetric(horizontal: hostFrameGutterPx, vertical: edge.width)`, with a doc
  comment saying why.
- `packages/party_host/test/games_screen_frame_test.dart`: the band's expected top offset
  (the `2 *` above).
- `docs/briefs/m16/phonehost2/s3-report.md:35-38`: the band's real numbers.
- `docs/briefs/m16/phonehost2/fB-report.md`: this report.

`night_reveal_test.dart`, `night_reveal_frame_test.dart`, `host_frame_screen_test.dart`,
`host_frame_screen_safe_area_test.dart`, `night_start_frame_test.dart`,
`night_scoreboard_frame_test.dart` and `arena_results_frame_test.dart` pin no old number and
are unchanged; the frame test draws a one- and a two-way tie only, so both keep 40.

## Checks

- `tools/check.sh format analyze host`: format PASS, analyze PASS, host PASS (96 s).
- Tests first: `flutter test test/night_reveal_tie_test.dart` on the old code failed with
  "a three-way tie: nothing overflows — RenderFlex overflowed by 31 pixels" and "12.0 px
  above the buttons, 8.0 below"; after the fix, 6 tests pass.
- The eight reveal/frame/start/scoreboard/games/arena test files together: 158 pass (before
  the last comment-only edits; the host suite above re-ran all of them).

## Self-check (review-rules part A)

1. Every host setup: the change is inside the shared `HostFrameScreen` and the reveal, so TV,
   PC, phone and joined views draw the same; `night_reveal_tie_test.dart` covers the five
   device setups. No services or protocol involved.
2. When kept state starts and ends: no state is added; the reveal's existing timers are
   pumped through all three awards, so nothing is left running (`night_reveal_tie_test.dart`).
3. How a new state combines: none — layout only; pause, away, Escape and Back are untouched
   (`night_reveal_test.dart`, passing in the host suite).
4. Stay in the job's folder: only files in `allow:` were written (list above).
5. Stop rather than overstep: nothing needed outside `allow:`; `games_screen_frame_test.dart`
   was in `allow:`, as the brief says, so its 12 px expectation is updated rather than left.

## Questions

1. Should the tie's two columns balance by rows rather than columns if a night ever has more
   than six players? Today the column-major split gives `ceil(n / 2)` rows, which degrades
   gracefully (8 winners -> two columns of 4), but the brief's "up to three" only holds for
   six.
2. `nightRevealWinnerPxFor` is public like the constants beside it; if the next review wants
   the surface smaller, the tiers could be a private map instead.

## Hand-over

The reveal now fits a tie of all six players at every size, in two columns of 24 px names,
and the band pads evenly (10/10) with its test and the s3 numbers corrected. The tier
function is the one place to change if a future decision wants other sizes; the columns'
threshold is `nightRevealTieColumnMinWinners`.

## Commit message

The reveal's tie names shrink and split in two columns; the band pads evenly

Winner names take 40 frame px for one or two winners, 32 for three and 24
for four or more, and five or six put those names in two columns of up to
three, so a tie of everyone fits the card at 640x360.
The footer band pads the ink line's width above and below its row, so a
64 px button stands 10 above and 10 below; games_screen_frame_test pins it.
night_reveal_tie_test.dart checks the two- to six-way ties and the band at
the five sizes; s3-report.md's band numbers are corrected to 10/10.

## Status row

fB: done — reveal tie sizes 40/32/24 with two columns for five or six winners, and an even footer band (10/10, s3-report corrected, games_screen_frame_test updated). Open: none in this job.

## Delete

- none
