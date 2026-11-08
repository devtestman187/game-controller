# M13 3b — the host's screens and cards in the toy look: report

**Status: stopped.** Everything the brief asks for inside `packages/party_host`,
`packages/toy_look` and the tests is done and green (look 82, host 197, phone 383).
One existing TV test (`tv_test_app/test/home_screen_test.dart: shows the pairing code,
address and controllers with ping`) now fails, and its fix is a design decision about
the TV's home screen — 3c's screen, outside this job's `allow:` list. See
"Blocked: the TV's home" below.

## What was done, by rule

1. **Buttons.** `HostButton` keeps its constructors, keys and callers and draws a
   `ToyButton` with the fill it is given (else `good`) and
   `showFocus: ref.watch(hostFocusLookProvider)`; `compact` passes the new
   `ToyButton.dense`, which is `denseHeightShare` (0.75) of `sizes.buttonHeight` with
   the label in `type.body`'s size in the button's own family and weight (36 / 48 px
   and 15 / 22 px on the phone / TV look). `hostButtonLook` is the toy version:
   paper, a `sizes.outlineWidth` ink side, `sizes.cardCorner` corners and ink text at
   rest; lit (pressed, or focused while the focus look shows) it takes the `focus`
   fill and draws a `hostRingPx` (= `sizes.focusRing`, 4) ring in `focus` outside the
   ink edge (`HostEdgeBorder`). The cards that are buttons (the game picker, the
   level list) use the same rule through `HostCardFocus`/`HostCardButton`; on a
   touch-first host they never light from a finger (bug 1107f).
2. **Screens.** Every host screen's title is `type.title` in `onBackground` over 3a's
   `ToyBackground` page (`HostScreen`), its groups `ToyCard`s and its rows paper.
   The picker's games are big `ToyCard`s (`gameCardHeightShare` 4.0 button heights)
   with a drawn picture above the title and line: `GamePicture` is a small painter
   over `toyShape` — Shape Race's triangle `player(4)`, square `player(2)` and circle
   `player(1)` overlapping like pieces on a mat; the Arena's `player(1)` marble beside
   a `good` pad with an ink flag pole — at `gamePictureHeightShare` 0.4 of the card's
   height. The Shape Race level list, the puzzle settings, the stats and the consent
   dialog have their groups in `ToyCard`s and their rows on paper.
3. **Join screen.** Each side is a `ToyCard` whose header band is the side's colour
   (`player(1)` left, `player(2)` right) with its name, each joined player a row with
   a `ToyBadge` and their name, an empty seat a dashed line; Start is in `good` and
   Back is a ToyButton. The format line, every key and the focus order are unchanged.
4. **Cards over the game.** Results: the winning side's colour in the header, `focus`
   for a draw, each side's time and pieces with ✓. Pause: `focus` header and the
   `ToyBadge` of who paused. Away: `caution` header, countdown in `type.clock`. Ready
   3-2-1: no header, the number in the clock family at `readyCountShare` (3) times its
   size, popping 1.3 → 1.0 over 250 ms with `Curves.easeOutBack` on each change while
   `look.effects` is on, still when off. The Arena's note and the debug overlay are
   paper cards; the play hint is `onBackground` text on a `PlayHint` pill. Every
   card's text, keys, buttons, focus and timing are as before.
5. **Colours.** No `Colors.` or `Color(0x` is left in `packages/party_host/lib`; each
   took the token for its meaning (`greenAccent` → `good`, `amberAccent` → `caution`,
   an error → `bad`, white on the background → `onBackground`, ink on paper,
   `playerColor(n)` → `player(n)`).
6. **String table.** `packages/party_host/lib/src/host_text.dart` holds every
   player-facing text of `lib/src/ui` in `abstract final class HostText` (consts and
   small functions for texts with a value), is exported from `party_host.dart`, and
   includes 3a's Look and sound texts. The tests keep their literal texts.
7. **Sizes.** Every size comes from `look.sizes` (which `toyTvProvider` picks), never a
   literal; `screen_fit_test.dart` pumps each restyled screen and card at 960 × 540
   with the TV look and at 852 × 393 with the phone look, in Sunny and Night, with the
   look's own fonts loaded (`test/support/toy_fonts.dart`), and expects no overflow and
   no exception. Spacing and layout shrank where they had to (`gameCardHeightShare`
   4.5 → 4.0, the picker card's padding `space12`, tighter join rows); no type
   changed.
8. **File sizes.** Everything under 400 lines (largest lib file now
   `toy_button.dart` 381, `join_screen.dart` 365); `pause_menu.dart` and
   `join_screen.dart` kept their widgets in their `*_widgets.dart` parts.
9. **Nothing else.** No behaviour, timing, focus order, key or text changed beyond the
   merged pairs and the button the restyle draws; no game painter and no lib file
   outside `party_host`/`toy_look` touched.

## Files changed

### packages/toy_look
- `lib/src/toy_button.dart` — added `dense` (0.75 height, the body's size in the
  button's family and weight) and `denseHeightShare`; the label is now `Flexible` with
  one ellipsised line, so a label wider than the room a button is given is cut short
  instead of overflowing its pill (the TV app's own panels give a button the width of
  a wrap slot).
- `lib/src/toy_card.dart` — added `scrollBody` (the body scrolls inside a card that is
  given a height, for the join screen's sides, as a `Flexible`; a card in a list has no
  height to shrink into, hence opt-in) and a `Stack(fit: StackFit.passthrough)` paper so
  a card fills the slot it is given instead of shrinking to its widest part.
- `test/toy_button_test.dart` — the dense test: 36 high with the phone look and 48 with
  the TV look, the label at `type.body`'s size in the button's family and weight.

### packages/party_host (new files)
- `lib/src/host_text.dart` — the string table (see rule 6).
- `lib/src/ui/game_picture.dart` — the two picker pictures, a painter over `toyShape`.
- `lib/src/ui/games_screen_widgets.dart` — the picker's game card (picture, title,
  line) and the level rows, out of `games_screen.dart` to keep it short.
- `lib/src/ui/pause_menu_widgets.dart` — the pause menu's and the results' widgets, out
  of `pause_menu.dart`.
- `lib/src/ui/host_card_button.dart` — a card that is a button: a finger taps it, the
  remote's OK/Enter/Space/gamepad A press it, and it takes the focus like a button.
- `lib/src/ui/host_card_focus.dart` — the look's focus ring round a focused card, drawn
  in room left round it so nothing moves when the focus comes and goes.
- `lib/src/ui/host_ink.dart` — the card paper/ink helpers the screens share.
- `lib/src/ui/play_hint.dart` — the play hint pill (`onBackground` on a badge-like
  background-coloured pill, the keyboard's variant included).

### packages/party_host (changed)
- `lib/party_host.dart` — exports `game_picture.dart` and `ready_card.dart`.
- `lib/src/ui/host_button.dart` — `HostButton` draws a `ToyButton`; `hostButtonLook` is
  the toy rest/lit look; new `HostEdgeBorder` for card-shaped buttons.
- `lib/src/ui/games_screen.dart` — the picker is two big drawn `ToyCard`s; the level
  list is cards of `ToyButton`s on paper.
- `lib/src/ui/game_screen.dart` — the page background, the play hint, and the cards
  over the game in the look.
- `lib/src/ui/away_card.dart` — a `ToyCard` headed `caution` with the string table's
  away line and the countdown in `type.clock`.
- `lib/src/ui/ready_card.dart` — the 3-2-1 card: no header, the clock family at 3×,
  the 1.3 → 1.0 pop.
- `lib/src/ui/pause_menu.dart` — the paused/results cards in the look; its widgets
  moved to the part file.
- `lib/src/ui/join_screen.dart` — the sides as `ToyCard`s, Start in `good`; its widgets
  moved to the part file; the layout maps are consts (see "Review").
- `lib/src/ui/join_screen_widgets.dart` — the side panel, player rows with `ToyBadge`s,
  the dashed empty seat.
- `lib/src/ui/puzzle_screen.dart`, `puzzle_screen_widgets.dart` — the results side
  lines with ✓ on the look's paper.
- `lib/src/ui/puzzle_settings_screen.dart` — settings and the highlight switch on
  `ToyCard`s; the two cards split out of `build` (see "Review").
- `lib/src/ui/stats_screen.dart`, `stats_screen_widgets.dart` — groups on `ToyCard`s,
  sessions on paper, the consent dialog as a card.
- `lib/src/ui/host_screen.dart` — the title in `type.title`/`onBackground` over the toy
  page, the title bar on the look's spacing.
- `lib/src/ui/host_focus_scope.dart` — the no-focus-look theme's focus colour is the
  look's `focus` at zero alpha (no `Colors.` left).
- `lib/src/ui/player_badge.dart` — draws the look's `ToyBadge`.
- `lib/src/ui/controller_menus.dart` — its labels come from `HostText`.
- `lib/src/ui/look_and_sound_screen.dart`, `look_and_sound_section.dart` — 3a's texts
  moved to `HostText`, the section's type from the look.

### tests
- `packages/party_host/test/host_button_test.dart` (new, 5) — `HostButton` draws a
  `ToyButton` with the focus look on a TV host and none on a touch-first one;
  `hostButtonLook` at rest (paper, ink side) and lit (the `focus` fill and ring).
- `packages/party_host/test/host_text_test.dart` (new, 5) — the string table's
  functions and the merged away text.
- `packages/party_host/test/ready_card_test.dart` (new, 4) — the pop (1.3 at its start,
  1.0 after 250 ms), still with effects off, the clock family at 3×, fits at both
  sizes.
- `packages/party_host/test/screen_fit_test.dart` (new, 16) — the four walks (menus,
  cards over the round, Arena and the debug card, stats and the consent dialog) at
  960 × 540 TV and 852 × 393 phone, Sunny and Night, with the look's real fonts.
- `packages/party_host/test/support/toy_fonts.dart` (new) — loads Fredoka and Nunito
  from `packages/toy_look/fonts` as the look names them.
- `packages/party_host/test/games_screen_test.dart` — a test for the two cards'
  pictures (each has its `GamePicture`, 0.4 of the card's height, title below it); a
  stale "180 high" comment fixed.
- `packages/party_host/test/join_screen_test.dart` — each side is a `ToyCard` with the
  side's colour in its header and a `ToyBadge` per player.
- `packages/party_host/test/puzzle_results_test.dart` — the header is the winner's
  colour, and a draw's header is `focus`.
- `packages/party_host/test/away_card_test.dart` — the `caution` header and the merged
  away text.
- `packages/party_host/test/host_focus_look_test.dart`, `controller_app/test/host_title_bar_test.dart`
  — the focus look is read off `HostCardFocus` now (no Material fill to read).
- `controller_app/test/host_menu_fit_test.dart` — the picker still fits at 852 × 393;
  the level list is cards of buttons now, so it scrolls (no overflow instead of no
  scroll).

## Computed test values
- Dense button height: 0.75 × 48 = 36 (phone look), 0.75 × 64 = 48 (TV look); label
  15 px / 22 px, in `packages/toy_look/Fredoka`, weight 600.
- Picker card: 4.0 × button height (192 phone, 256 TV) with the picture at 0.4 of it
  (76.8 / 102.4).
- Ready number: clock size × 3 (96 phone, 168 TV), scale 1.3 → 1.0 over 250 ms.
- Focus ring: `hostRingPx` = `ToySizes.focusRing` = 4; corners `ToySizes.cardCorner` =
  16; ink side `sizes.outlineWidth` = 3.
- Fit sizes: 960 × 540 (TV, Sunny and Night) and 852 × 393 (phone, Sunny and Night).

## Test counts
| | before | after |
| --- | --- | --- |
| look | 81 | 82 |
| host | 164 | 197 |
| phone | 383 | 383 |
| tv | 36 (+1 skipped) | 35 pass, 1 skipped, **1 fail** |

`tv` before and after have the same 36 tests; the one failing test is `home_screen_test`'s
"shows the pairing code, address and controllers with ping".

## Colour grep
```
$ grep -rE "Colors\.|Color\(0x" packages/party_host/lib
$ echo $?
1
```
No output, no match: the rule is met.

## Merged texts
- `HostText.playerAway(n)` — "P2 is away" (the away card) and "Player 2 is away" are
  now one text, "Player 2 is away", the brief's example.
- `HostText.ok` / `HostText.back` — the menu layout's phone labels and the host's own
  buttons were the same two words written twice.
- `HostText.level` (and `easy`/`medium`/`hard`) — the picker, the level list and the
  join screen each spelled the level names.
- `HostText.modeName` (a phone's `InputMode`) and `HostText.modeRow` (the stats' name
  for it) — the debug overlay and the stats table each listed "D-pad", "Gyro",
  "Sticks", "Keyboard"; two functions because their inputs differ, one set of words.
- `HostText.dash` — "–" was spelled as a literal in the debug card, the stats and the
  latency column.

## Tests whose pinned colour or text changed
- `packages/party_host/test/away_card_test.dart` — "P2 is away" → "Player 2 is away"
  (the merged text), and the header is now checked to be `HostText.playersAway` in
  `colors.caution`.
- `packages/party_host/test/puzzle_results_test.dart` — the header colour is
  `look.colors.player(1)` (was `playerColor(1)`); a new draw test pins `focus`.
- `packages/party_host/test/host_focus_look_test.dart` — the focus look is read off
  `HostCardFocus.isLit` (was the Material's fill and ring), and a finger on a card no
  longer lights it (the toy card lights on the focus, as bug 1107f asks).
- `controller_app/test/host_title_bar_test.dart` — same reading, through
  `party.HostCardFocus`.
- `controller_app/test/host_menu_fit_test.dart` — the level list's scroll range is now
  `> 0` (its levels are cards of the look's buttons) with no exception, and the test is
  renamed to say so.

## Checks run
- `tools/check.sh format analyze look kit host phone tv` — format, analyze, look, kit,
  host, phone PASS; tv FAIL on the one test above.
- `tools/review.sh` — 0 fail, 21 note (all notes are numeric literals and file sizes on
  my lines, listed in its output).

## Self-check (docs/review-rules.md part A)
1. **Every host setup.** The restyle is in `party_host`, so it is one code path for the
   TV/PC host, "Play on this phone" and "Show on this device": `screen_fit_test.dart`
   pumps every screen at both looks and `host_mode_test.dart`/`host_bar_test.dart`
   (unchanged, passing) drive the phone host. A joined phone is not affected: no
   protocol message changed. An older build is not affected either (no message
   changed).
2. **When kept state starts and ends.** The ready card's pop is per number and ends
   with the card (`ready_card_test.dart`, "each count pops from 1.3 to 1.0 in 250 ms");
   the away card's countdown is the host's clock as before (`away_card_test.dart`, "the
   card names each away player and counts their grace down"); no new timer, cache or
   flag was added.
3. **How a new state combines with the others.** Nothing new pauses, hides or waits:
   the cards only changed how they are drawn. The combinations the diff touches are
   already covered by `pause_menu_test.dart` (pause vs. host away vs. player away vs.
   ready) and `away_card_test.dart`, both unchanged and passing.
4. **Stay in the job's folder.** `git status --short` lists only files under
   `packages/party_host`, `packages/toy_look`, `controller_app/test`, `tv_test_app/test`
   (none) and this report.
5. **Stop rather than overstep.** Done: the TV's home screen cannot be fixed from
   `allow:` — see below.

## Blocked: the TV's home
The restyle makes `HostButton`'s compact form the look's dense button: 48 px high with
a 22 px label on the TV look, where the old Material button was 32 px high with a 15 px
label. The TV app's own home (`tv_test_app/lib/src/ui/home`, 3c's screen, outside
`allow:`) lays its header out in two rows of compact buttons and puts the controllers
panel in the room that is left:

- `Packages`-side effect: `Panel`'s title row grows from 32 to 48 px and the header from
  72 to 104 px, so the controllers list's viewport falls from ~198 to 153 px.
- The first controller's tile is ~187 px tall in the test font, so the second one (the
  phone still pairing) is no longer built: `home_screen_test.dart` line 24,
  `find.text('Waiting for code')`, finds nothing (the list builds only the first row;
  dragging it makes the text appear). On a real TV the second row is at best a sliver,
  and the panel has no key to scroll it with.
- The same shrink also made the pairing panel's "Simulate controller" button overflow
  its wrap slot in the test font (45 px); `ToyButton` now ellipsises a label that does
  not fit, which fixes that overflow but not the hidden row.

Two ways to finish it, both a design decision for the TV's home, so neither is taken
here:
1. Give the TV's home a tighter header or a taller controllers panel in 3c (the
   header's compact buttons are the biggest single win).
2. Move the TV's home tests onto the look's own sizes now, which is 3c's restyle.

Everything else passes: with that one exception `tv` is green.

## Questions and suggestions
1. The picker's mock-up (`game-picker`) has the game's name in a coloured header band;
   the brief (rule 2) asks for a drawn picture above the title inside the card, so
   there is no band and the title is `type.button` in ink under the picture. Should the
   card also take a `player(n)` header band, as the join screen's sides do?
2. `ToyCard`'s paper now fills the width it is given (`StackFit.passthrough`). That
   changed every card, in both apps: cards in a list or a panel stretch to the slot
   instead of hugging their content. It looks right for the host's screens and the
   toy_look tests still pass, but 3c should check the phone's screens against it.
3. The string table is one flat class (347 lines). 3c will add the phone's texts; if the
   file grows past the lib limit, splitting it by screen (`HostText` kept as the
   façade) is the next step rather than shrinking the docs.
4. The TV's home (the point above) is worth doing before 3c restyles it: the toy
   buttons need ~48 px of chrome where the old ones needed 32, and the home is the
   only screen sized to the old ones.

## Commit message
M13 3b: the host's screens and cards in the toy look

HostButton draws a ToyButton (dense for a panel's row) and hostButtonLook is the look's
rest and lit state. Menus, the join screen, the picker with a drawn picture per game,
the results, pause, away and 3-2-1 cards, the stats and the consent dialog are ToyCards
and badges on the toy page, sized from the look on TV and phone. Every colour in
party_host comes from the look, every text from the new HostText table, and a fit test
covers each screen at 960x540 and 852x393 in both palettes.

## Status row
M13 3b: the host's screens and cards are in the toy look (buttons, picker, join, results, pause, away, 3-2-1, stats, string table, fit tests); open: the TV's home needs its header and controllers panel resized for the taller toy buttons (one tv_test_app test, 3c).

## Delete
- none

## Claude's review (Nov 8, 2026)

Accepted, with these changes (each test-first):

1. **The fit test for the cards over the round** looped over the four looks but called `openRace(tester)`, which ignored them: it ran four times at 960 × 540, Sunny, phone look. `openRace` now takes `size` and `clock`, and the test passes the look's size, clock and `toyTvProvider`.
2. **Contrast on paper** (design section 3: text at 4.5:1). Measured on the tokens:
   - The faded label ink at 0.6 was 4.41:1 in Sunny. It is now a token, `ToyColors.inkSoft` at 0.7 (6.1:1). The contrast test has an "inkSoft on paper" pair, and `host_ink.dart` is gone.
   - The empty seat's words were at 0.45 (2.83:1); they are now `inkSoft`. The dashed line stays faint: it is a decoration, not text.
   - The winner's time was `good` on paper (1.97:1), and so was its ✓. Both are ink now; the header says who won.
3. **The away card** had its whole countdown sentence in the clock type, so one line filled the card. The countdown is now in the button's type (a test pins it). The brief's "countdown in `type.clock`" meant a number, and the line is a sentence.
4. **Room on a side** was said on every empty seat ("Room for 2 more" twice). Now it shows on the first empty seat only, and the others keep the line's height.
5. **The TV home** (the job's stop) did not need a layout change. The TV tests measured in the test font's square boxes, where the first controller's tile is 187 px tall. With the look's real fonts the tile is about 100 px, and on a 960 × 540 render the second controller is in view. `tv_test_app/test/flutter_test_config.dart` now loads Fredoka and Nunito for every TV test, and `tv` is green (36, 1 skipped). The home is still cramped: the title is cut to "Thumb…", the header wraps to two rows, and "Connected" and "Waiting for code" are green and yellow text on paper. That is 3c's work.

Answers to the questions:
1. **No header band on the picker cards:** the drawn picture is the card's colour. The mock-up's band was for a card with no picture.
2. **`ToyCard` filling its slot** is fine. 3c renders the phone's screens and checks them.
3. **Splitting the string table:** split it by screen if 3c pushes it past 400 lines, with `HostText` kept as the façade.
4. **The TV home:** 3c, as above.

Seen by Claude in both palettes with the real fonts (TV look 960 × 540, phone look 852 × 393): the picker, the Shape Race list, the join screen, pause, the 3-2-1, away, results, stats and the consent dialog. The stats table is tight at the TV's type, but it scrolls and it is a tester's screen. Counts after the review: look 82, host 197, phone 383, tv 36 (+1 skipped).
