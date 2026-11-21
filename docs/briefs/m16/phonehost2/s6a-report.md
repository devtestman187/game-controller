# s6a — Arena results in HostFrameScreen, one card of coin rows

## Summary

- `ArenaResults` is now a `HostFrameScreen`: the winner's headline (`ArenaText.wins(...)`, `HostText.draw` for a draw) is the 64 px header's title, the body is one full-stage-width `ToyCard` (`arenaResults`), and the 84 px footer holds the way on.
- `arenaResultsWidthPx` and the `SingleChildScrollView` are gone: the card fits every body (the smallest, 392 px, holds the most rows, 380 px).
- `ScoreRow` grew three optional fields: `value` (a `ScoreRowValue` icon and text), `tag`, and `isHighlighted`. Rows show a coin icon with `ArenaText.coins(n)` in place of the star and points; Robo's row wears the robot head, no badge number and a `bot` pill; joiners stay a soft line (`joinsNextRound-<id>`, 20 px).
- The winner's gold wash no longer needs the night's taller winner row: `isHighlighted` washes the row gold and the row keeps the design's 52 px line, so 6 players + Robo fit a 540-high frame.
- Bars fill by coins over the round's most coins; ranks count the lines ahead, level lines wear `=` (`3=`); Robo keeps `arenaCrown-robo` when it wins.
- Footer, first button still on `againFocus`: in a night `next` + `endNight` (Next alone on the night's last round, B-021); outside a night `arenaAgain` + `arenaChangeMode`.
- Back is the header's arrow only, as the brief allows: the three buttons need 648 px with icons and 547 without, over the footer's 480 px budget beside Thumby's corner, so the footer keeps two. The two kept measure 420 px without icons (with them, 487 px). A test pops the results with `hostTitleBarBack`.
- `game_screen.dart` needed no change: the results' nested `Scaffold`/`SafeArea` is transparent (the toy theme's scaffold background) and a nested `SafeArea` takes no padding, and the field stays mounted under the results.
- Kept keys: `arenaResults`, `arenaResultRow-<id>`, `arenaCrown-<id>`, `arenaResultCoins-<id>`, `joinsNextRound-<id>`, `next`, `endNight`, `arenaAgain`, `arenaChangeMode`. Added through `ScoreRowKeys`: `arenaResultName-<id>`, `arenaResultRank-<id>`.
- `arenaResultTitle` could not be kept: the headline is `HostFrameScreen`'s `String` title, which takes no key, and `host_frame_screen.dart` is outside `allow:`. The tests find the headline by its text (`P1 Mia wins!`, `Robo wins!`, `Draw!`).
- Tests: new `test/arena_results_frame_test.dart` (38 cases: five devices × 4/6 players × night/outside, plus wash/crown, draw, Robo, nickname fit, the arrow and joiners); `test/arena_results_test.dart`'s three rewritten. `end_night_arena_test`, `menu_press_test`, `arena_night_test` and `score_row_test` are unchanged and green.
- No lib file over 380 lines: `arena_results.dart` 310, `score_row.dart` 346, `score_row_parts.dart` 123 (the new part holds `_MedalDisc`, `_ScoreBar` and `_RowValue`).

### Sizes, in frame px

| device | frame | card width | body height | rows (4 + Robo) | rows (6 + Robo) |
| --- | --- | --- | --- | --- | --- |
| 640x360 | 960x540 | 912 | 392 | 5 × 52 + 16 = 276 | 7 × 52 + 16 = 380 |
| 852x393 | 1170.6870229007634x540 | 1122.6870229007634 | 392 | 276 | 380 |
| 1024x768 | 960x720 | 912 | 572 | 276 | 380 |
| 1280x800 | 960x600 | 912 | 452 | 276 | 380 |
| 1920x1080 | 960x540 | 912 | 392 | 276 | 380 |

Card width = frame width − 2 × 24 (`hostFrameGutterPx`); body = frame height − 64 − 84; the card's 16 px is 8 above and 8 below (`_cardPadding`). Every row is 52 px (the winner's too), the smallest text 20 px (`ToyType.frame.title` 40, button 28, name 22, joins line 20).

Footer at the frame's 28 px type: night `next` 145.137 + gap 16 + `endNight` 206.503 = 367.64; outside a night `arenaAgain` 182.492 + 16 + `arenaChangeMode` 221.886 = 420.38; the budget (`nightFooterButtonsWidthPx`) is 480.

## Tests rewritten

- New `arena_results_frame_test.dart`: copies the five-device `_Case` table and the `HostFrame` wrapper from `host_frame_screen_test.dart`, and the roster from `night_harness.dart` (`TestRoster`). It checks, at every case in a night and outside one: no `Scrollable` in the body, nothing overflows, each row 52 px (winner included), the footer's buttons on screen, hittable and inside 480 px; every `Text` ≥ 20 px; the winner's wash + crown and ranks `1, 2, 3=, 3=` with `9 coins`; a draw's headline with no crown or wash; Robo's `bot` pill, robot head, no `PlayerBadge` and `1 coin`; `Alexandria`/`Nightshade` inside the 190 px name column without ellipsis; the card 912 px wide; a fifth test pushes the results on a route of its own and taps `hostTitleBarBack`; a sixth checks the joiners' line.
- `arena_results_test.dart`: the three card tests now find the headline as text and `hostFrameHeader` instead of a card-title widget, expect `arenaResultsBack` absent (the 480 px budget), and look for the `bot` tag inside Robo's row.
- Unchanged and green: `end_night_arena_test.dart`, `menu_press_test.dart`, `arena_night_test.dart`, `score_row_test.dart`.

## Self-check (review-rules part A, 1–5)

1. Every host setup: one layout, no setup branch; the same frame layout runs at all five devices, 4 and 6 players, in a night and outside (`arena_results_frame_test`).
2. Kept state: nothing the screen owned before it became a frame screen (no timers, `PopScope` or focus trap); `againFocus` still starts the first footer button, checked by the footer tests and `menu_press_test`.
3. New state combining with others: `isHighlighted`/`tag`/`value` are stateless; the wash is tested alone in `arena_results_frame_test` and the night's taller winner row is untouched (`score_row_test`).
4. Stay in the job's folder and `allow:`: only `arena_results.dart`, `score_row.dart`, `score_row_parts.dart`, `arena_results_frame_test.dart`, `arena_results_test.dart` and this report changed; `game_screen.dart` and the other three named tests needed nothing.
5. Stop rather than overstep: `host_frame_screen.dart`, `night_scoreboard_*.dart`, `player_badge.dart` and the text files were read and used unmodified; the title key and the `bot` string are reported rather than fixed outside `allow:`.

## Checks

- `tools/check.sh format analyze host` — PASS, PASS, PASS (format 5 s, analyze 9 s, host 96 s).
- `flutter test test/arena_results_frame_test.dart` — 38/38 before the final format run; `tools/review.sh` 0 fail, 2 notes (file lengths, now 310 and 346).

## Hand-over

- `arenaResultTitle` is the one key from the brief that is not there: it needs a `titleKey` on `HostFrameScreen` (outside `allow:`). Say the word and a later job adds it; the tests would then switch back from `find.text`.
- The `bot` tag is a literal (`arenaRoboTag = 'bot'`): the text catalogues are outside `allow:` and the tag is a `ScoreRow` parameter. It can move to `ArenaText` when a job owns that file.
- 6 players + Robo already fill 380 of a 392 px body; a late joiner's 20 px line beside them would make 408 and overflow. The brief's frame tests stop at 6 players, so this is untested; the roster cap may make it impossible in the app.
- Unrelated flake seen once in a full `host` run: `live_stats_share_test.dart` "a phone that said no is left out…" (player order); it passes alone and the final full run was green.
- The outside-a-night pair lost its icons to fit the budget (420 px without, 487 with); the words alone say what they do.

## Commit message

```
M16 S6a: Arena results in the frame, one card of coin rows

ArenaResults is a HostFrameScreen: the winner's headline in the 64 px
header, one full-stage-width ToyCard of ScoreRows in the body, the way
on in the 84 px footer (Next + End night, or Play again + Change mode).
ScoreRow takes a value icon and text (a coin and "9 coins"), a tag
("bot" on Robo's row) and a gold wash without the taller winner row;
bars fill by coins, ranks tie with "=". Back is the header's arrow: the
three footer buttons want 540 px of the 480 px budget. arenaResultsWidthPx
and the scroll view are gone.
```

## Status row

S6a done: Arena results in a HostFrameScreen with one stage-wide card of coin rows at the five sizes; open: `arenaResultTitle` needs a `titleKey` on HostFrameScreen, `bot` should move to ArenaText, 6 + Robo + a late joiner would overflow at 392 px.

## Delete

- none
