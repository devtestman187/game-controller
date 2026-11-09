# M13 4c — characters: report

A player is now shown by a colour **and an accessory, never by a number on a
body** (design 5b, PRD L6): `ToyCharacter` is the only place a player's number
becomes a character, the Shape Race worker and the Arena's marble wear it, and
the host's badges wear it too (the disc in the character's colour, the number
kept for the menus).

`tools/check.sh format analyze look puzzle arena host phone tv` — **all pass**.

## Test counts

| suite | before | after | the new tests |
| --- | --- | --- | --- |
| toy_look | 88 | 94 | `toy_character_test` (4), `toy_accessory_test` (2) |
| puzzle_game | 170 | 171 | `worker_accessory_test` (1) |
| test_game | 60 | 61 | `arena_character_test` (1) |
| party_host | 199 | 202 | `player_badge_test` (1), +1 in `join_screen_test`, +1 in `pause_menu_test` |
| controller_app | 403 | 403 | none (its join-screen fit still passes) |
| tv_test_app | 50 + 1 skipped | 50 + 1 skipped | none |

The two `_…_measure_test.dart` files are scratch measurements (they print and
assert the numbers in this report); they are in the `Delete` list at the end.
With them still in the tree the check says look 95 and puzzle 172.

## Files changed

toy_look:
- `lib/src/toy_character.dart` (new): `ToyAccessory`, `ToyCharacter` (`colourSlot`, `accessory`, `colourIn`, value equality, `forPlayer`), its doc saying it is the only place a number becomes a character (PRD L7).
- `lib/src/toy_accessory.dart` (new): `paintAccessory` and the six shapes; `toyAccessoryReachShare` and `toyAccessoryHeadroom(diameter)` for rows that hold badges.
- `lib/src/toy_badge.dart`: `paintToyBadge`/`ToyBadge` take an optional `ToyCharacter`; the disc takes its colour, the number stays, the accessory is drawn on top; the painter compares it.
- `lib/toy_look.dart`: exports the two new files.
- `test/toy_character_test.dart` (new), `test/toy_accessory_test.dart` (new).
- `test/_accessory_measure_test.dart` (new, scratch — delete).

puzzle_game:
- `lib/src/worker_painter.dart`: each worker asks `ToyCharacter.forPlayer(p.number)` once a paint, draws its body in the character's colour, keeps the face, drops the tummy number and draws the accessory after the face inside the hop/lean/squash canvas.
- `test/worker_number_test.dart`: inverted — the tummy is the body's colour now (see Pins).
- `test/worker_paint_test.dart`: the tummy pin removed, the middle-colour pin kept; `crateSnapshot` takes a `number`.
- `test/worker_accessory_test.dart` (new): players 1–6 show their accessory's ink above the body in Sunny and Night.
- `test/_tummy_measure_test.dart` (new, scratch — delete).

test_game:
- `lib/src/arena_marble_painter.dart`: the marble takes its character's colour, keeps its eyes, drops the number, draws the accessory on top.
- `test/arena_character_test.dart` (new): player 1's marble has ink above it, player 2 has none on its lower half.

party_host:
- `lib/src/ui/player_badge.dart`: `rowBadgeShare` (0.75) and `rowBadgeHeadroom(look)`; `PlayerBadge` passes `ToyCharacter.forPlayer(number)`.
- `lib/src/ui/join_screen.dart`, `lib/src/ui/puzzle_screen.dart`: import the badge module.
- `lib/src/ui/join_screen_widgets.dart`: `_PlayerRow` wears its player's character and keeps the accessory's room above it (the panel's own padding counts for the first row).
- `lib/src/ui/pause_menu_widgets.dart`: the pauser's badge wears its character, with the room for it under the card's header band.
- `lib/src/ui/away_card.dart`, `lib/src/ui/puzzle_screen_widgets.dart`: their rows wear the character and keep its room.
- `test/support/pixels.dart` (new): `Pixels`, `argb`, `colourGap`, `screenPixels` (a whole-frame capture through the render view's layer) and `accessoryInk` (the ink an accessory draws in a row's room above a badge).
- `test/player_badge_test.dart` (new), `test/join_screen_test.dart` (+1), `test/pause_menu_test.dart` (+1).

## The six accessories, as built

Coordinates are body radii from the body's middle; ink and paper are the look's,
and the ears use the body's own colour, so any accessory suits any colour.

| accessory | shapes | colours |
| --- | --- | --- |
| ears | two filled circles, radius 0.34, at (±0.7, −0.9), each with an ink arc on its outer half only | body colour + ink |
| antenna | ink stalk from −0.95 to −1.55, 0.1 wide, round ends; paper ball radius 0.18 at −1.62 with its ink ring | ink + paper |
| bow | two paper loops (triangles from the knot (0.55, −1.0) to (0.1, −1.25)/(0.25, −0.8) and to (1.0, −1.2)/(1.05, −0.78)); paper knot dot radius 0.1 with its ink ring | paper + ink |
| cap | paper dome from (−0.85, −0.55) over an arch at −1.9 to (0.85, −0.55); paper brim (rounded rect 0.52…1.28 × −0.78…−0.56, corner 0.1) to the front | paper + ink |
| tuft | three ink strokes, 0.1 wide, each a quadratic through a bend: (−0.45, −0.9) → (−0.7, −1.3), (−0.05, −0.98) → (0.02, −1.42), (0.35, −0.93) → (0.6, −1.28) | ink |
| crown | one closed paper polygon with three points (7 points, −0.88 down to −1.38) | paper + ink |

Every edge is `look.sizes.outlineWidth` in pixels, divided by the canvas's whole
scale, as 4a's `_pxPerUnit` does, so a scaled game canvas gets the look's width
on screen. Each is above the body's middle and none reaches the eyes' band
(−0.45…−0.15 radii): `toy_accessory_test` checks that band is the body's colour
for all six, in both palettes.

## Silhouettes

Measured on the test frame (100 px body, player 1): ink pixels above the body's
top edge — ears 196, antenna 235, bow 189, cap 138, tuft 289, crown 294 — and
the share of the smaller mask shared with each other (the test's limit is 70 %
of `min(a, b)`):

| pair | share | pair | share |
| --- | --- | --- | --- |
| bow / cap | 39.1 % | cap / tuft | 18.8 % |
| cap / crown | 31.9 % | bow / crown | 17.5 % |
| tuft / crown | 28.0 % | ears / crown | 10.2 % |
| antenna / tuft | 25.1 % | ears / bow | 9.5 % |
| ears / tuft | 20.4 % | antenna / crown | 6.8 % |
| | | bow / tuft | 6.3 % |

The rest are under 6 % (antenna / cap 5.8 %, and ears / antenna, ears / cap and
antenna / bow share nothing at all). The worst pair, the bow and the cap, share
the paper edge they both draw on the top right; at 39 % they still read apart.

## Room above badges (the fits that needed it)

A badge's accessory is drawn outside the badge's box, so `ToyBadge` says how much
room it needs (`toyAccessoryHeadroom`: 0.9 of the badge's radius, the cap's
arch). The rows that hold badges keep it:

- **the join screen's rows**: badge = `buttonHeight * 0.75` (36 px on a menu,
  48 on a TV), so 16.2 / 21.6 px of room. The side panel's own padding (12 tight
  on a phone, 16 on a TV) is already above the first row, so the first row keeps
  only the rest (4.2 / 5.6) and every later row the whole headroom. At 852×393
  the left side's content grows by 0.2 px, so controller_app's
  `host_menu_fit_test` still finds no scrolling; a side with two players scrolls
  a little more than it did (the side already scrolls by design when short).
- **the pause card**: badge = `buttonHeight` (48 / 64), so 21.6 / 28.8 px above
  the pauser's row, under the header band (`pause_menu_test`'s new test reads
  the ink there).
- **the away card's lines and the results' rows**: each keeps `rowBadgeHeadroom`
  above its badge as well (their cards' 16 / 24 px padding alone would leave the
  second row's accessory on the row above).

`screen_fit_test` (TV 960×540 and phone 852×393, Sunny and Night) and the
controller app's join-screen fit pass unchanged.

## Pins changed

- `packages/puzzle_game/test/worker_number_test.dart`: the pin of the tummy
  number is inverted — the same band now holds **no** ink (0), because the tummy
  is the body's colour again. The band starts at 0.35 radii so it clears the
  mouth's own stroke (0.28 radii at this frame's 8 image px a unit).
- `packages/puzzle_game/test/worker_paint_test.dart`: its tummy band pin is
  removed (it also reached past the body's bottom edge); the middle-colour pin
  stays, and the test is renamed "a worker's body is the player's colour".
- No marble-number pin existed in test_game (nothing was pinned on the marble's
  number), so only the new `arena_character_test` is added there.

## Self-check (review rules, part A)

1. **Every host setup.** Nothing reads a host's kind: the painters only read the
   player's number from the snapshot, and the badges from the widget. The TV and
   phone looks are both measured by `screen_fit_test`, and a joined phone's own
   row by `join_screen_test`'s new test; a TV or PC host and "Show on this
   device" draw the same character, and no protocol message changed, so a phone
   or host one build older plays as before (`arena_character_test`,
   `worker_accessory_test`).
2. **When kept state starts and ends.** Nothing is kept: `ToyCharacter.forPlayer`
   is pure and asked once per player per paint; no cache, timer or flag was
   added (`toy_character_test`, `player_badge_test`).
3. **How a new state combines with the others.** No new state pauses, hides or
   blocks input; the pause card, the away card and the results only gained the
   character and its room, and their suites (`pause_menu_test`, `away_card_test`,
   `puzzle_results_test`) pass unchanged.
4. **Stay in the job's folder.** Only files under `allow:` were written; the two
   scratch measure tests are listed under `Delete`.
5. **Stop rather than overstep.** No file outside `allow:` was needed. The one
   conflict is the brief's six-parameter `paintAccessory` against coding
   guidelines §3 — see questions.

## Questions

1. `paintAccessory` has six positional parameters, exactly the brief's signature,
   but coding guidelines §3 says "at most 5 parameters; beyond that a value
   object". I followed the brief (Claude is the source of truth). The value
   object would be `({Offset centre, double radius, Color colour})` for the body
   — what the private painters already pass around — kept for a later job if you
   want it.
2. The TV app's own badge uses (`controllers_panel.dart`, `latency_screen.dart`,
   `toy_gallery.dart`) keep the plain disc: the character is optional and
   `tv_test_app/lib` is outside `allow:`. They will wear it when a later step
   passes `ToyCharacter.forPlayer`.
3. party_host's `PlayerBadge` is exported but used nowhere in this repo (both
   apps have their own pill badge), so its new accessory may draw 14.4 px above
   a 32 px badge wherever a host app puts it against tight content; none does
   today.
4. With two players on one side of the join screen at 852×393 the panel now
   scrolls a little more than before. If that is too much, the rows could use
   smaller badges (`rowBadgeShare` is one constant).
5. The four `docs/design/m12-mirror*.png` and `tv_test_app/windows/flutter/
   generated_*` files were already modified in the working tree when this job
   started (the three generated ones by line endings only, as running the
   Flutter tool on Windows does). I did not touch either set.

## Commit message

Show players by colour and accessory, not a number on the body

toy_look: ToyCharacter (colour slot + accessory, forPlayer) and paintAccessory's
six shapes in ink, paper and the body's colour only; ToyBadge takes an optional
ToyCharacter (its colour, the number kept, the accessory on top) and says how
much room that needs.
Shape Race's worker and the Arena's marble wear their character; the tummy and
the marble's numbers are gone, and neither asks a TextPainter any more.
The host's rows keep the accessory's room above their badges: the join screen's
rows, the pause card, the away card and the results. PlayerBadge wears its
player's character.

## Status row

M13 4c done: players are shown by a colour and an accessory on Shape Race's worker, the Arena's marble and the host's badges, with the room their rows keep; open: the phone pad's badge (step 8) and the TV app's own badge uses.

## Delete

- packages/toy_look/test/_accessory_measure_test.dart
- packages/puzzle_game/test/_tummy_measure_test.dart

## Claude's review (Nov 8, 2026)

Accepted, with two changes, after Claude rendered the join screen with four players, a 2-vs-2 race and the Arena at TV size:

1. **Four players no longer fitted a TV's join screen.** With each badge's accessory given room above it, two players a side needed about 205 px of side card where a TV gives about 175, and the second row was cut in half.
   - The pause-and-leave hint (added earlier the same day) moves from its own line under the buttons into the instructions' text: it sits inline after their last word, where the line has room.
   - Test-first: screen_fit_test's "four players show whole on a TV's join screen". It failed by 12.6 px.
   - Two join_screen_test finders now match the instructions with `textContaining`, since the hint follows them on a TV host. The words checked are the same.
2. **The pause card's `build` passed 60 lines** with the accessory's room. The pauser's row moved into its own `_Pauser` widget.

Seen by Claude: the six accessories read apart at TV size on the workers, the join screen's badges match them, and the Arena's marble wears its ears.

Counts after the review: look 94, puzzle 171, arena 61, host 203, phone 403, tv 50 (+1 skipped).
