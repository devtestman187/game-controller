# M13 step 8: the phone's pad in the look, at its own sizes

Job: `docs/briefs/m13/s8-pad-look.md`. Gate: the whole step ("stop: after it"). **Status: done.**

## What the step now does

Every part of the pad is drawn from the look, at exactly the sizes, places and hit areas it had (D11).
The face buttons always fill with their face colour, with the ink edge and the sticker shadow, the letter in
Fredoka and a game's label under it in Nunito, both ink (D12); an unused one (P5) is a dashed ink outline
alone. A pressed part loses its shadow and its body, edge and text move by the shadow's offset, so it looks
pushed in: face buttons, D-pad arms (a diagonal's two), small buttons and a held stick's knob. The D-pad is
one paper plus — the union of its four arms, so no seam at the middle — with one ink edge and one shadow;
ink arrows, the lit arms in this phone's player colour, the centre dot ink at `toyShadowAlpha`. The sticks'
bases are paper rings with an ink edge; their knobs are the player's colour with the ink edge and the shadow,
pushed in while held and faded as before when not. Small buttons are paper pills that fill with the player's
colour when pressed. `PressFlash` flashes the look's paper. The bar's `playerBadge` is the look's `ToyBadge`
wearing the player's character (`ToyCharacter.forPlayer`), keeping its key and tooltip, in a box tall enough
for the accessory's headroom. `controller_app/lib` now has no `Color(0x` and no `Colors.`.

## Test counts

| suite | before | after |
| --- | --- | --- |
| look | 108 | 109 |
| host | 233 | 233 |
| phone | 408 | 427 |

Twenty new tests:

- look 1: `toy_badge_test.dart` — "each character's accessory draws its ink above the disc" (players 1–6),
  the rule 7 test the brief asks for.
- phone 16: `pad_look_test.dart` — the face buttons in Sunny and Night (face colour, shadow), the face
  colours are the look's in both, the pressed squish, a hidden button, letters/labels ink in the look's type;
  the D-pad's paper, lit arm (player 3 and before one is known), the diagonal's two lit and squished arms,
  one shadow and no seam, the centre dot; the sticks held/at rest/faint; the small button's paper and pressed
  pill with its label; `PressFlash` painting paper.
- phone 3: `pad_badge_test.dart` — the bar's badge is the look's badge with P3's character and the chosen
  diameter inside the chip, its tooltip, and none before a player is known.

Tests changed (the badge's old Material look is gone; nothing else changed shape):

- `controller_app/test/connection_test.dart` — "shows the player number the TV gave this phone" read
  `find.text('P2')` and the `Container`'s `BoxDecoration` colour; it now reads the `ToyBadge`'s number,
  character and diameter.
- `controller_app/test/joined_view_test.dart` — `find.text('P1')` became the `ToyBadge`'s number and
  character (the badge is the thing that says whose it is now).
- `controller_app/test/host_mode_test.dart` — the same `find.text('P1')` → the `ToyBadge`'s number.

Every test that pins the pad's geometry, hit areas, opacity and the bar's height passes unchanged
(`controller_app/test` 408 of them, plus `controls_layer_test`'s tap-through and the C28 opacity test).

## Files changed

New:
- `controller_app/lib/src/ui/pad_drawing.dart` — what the pad's painters share: `padPlayerColour`
  (`look.colors.player(n)`, player 1 before one is known), `padSquish` (`ToySizes.shadowOffset` when
  pressed), `padFaintInk` (`ink` at `toyShadowAlpha`), `padInkEdge` (the look's outline width, round joins
  and caps, ink or a given colour), `paintPadPart` (shadow while at rest, body and edge, both moved when
  pressed), `padLetter` (Fredoka, ink), `padLabel` (Nunito, ink, one line) and `paintCentred`.
- `controller_app/test/support/pixels.dart` — `paintedPixels` and `Pixels` copied from the look's test
  support (a package's `test/` folder isn't importable), plus `rgb`, `blend`, `whiteRgb`, `expectPixel`
  (a per-channel tolerance for edge antialiasing), `firstRow` and `firstColumn` for measuring an edge.
- `controller_app/test/pad_look_test.dart` — the painter tests: the pad's painters are painted straight onto
  a canvas, so a pixel says what the pad draws.
- `controller_app/test/pad_badge_test.dart` — the bar's badge.
- `packages/toy_look/lib/src/toy_dash.dart` — `paintDashedEdge`, `toyDashOn`/`toyDashOff` (6 and 4), the
  dash `ToyButton` had, now shared, so P5's outline dashes the same as a disabled button's.

Changed:
- `controller_app/lib/src/ui/face_buttons.dart` — `faceFills(ToyColors)` replaces `FaceButtonsView.colors`;
  `FaceButtonsPainter` (public, so a test paints it) draws each face colour with the ink edge and shadow, the
  squish, ink letter and label, and the dashed hidden outline. Sizes and fit rules are today's.
- `controller_app/lib/src/ui/pad_widgets.dart` — `PressFlash` flashes `look.colors.paper`; `DpadPainter`
  (public) draws the plus, its one shadow, ink arrows, the lit arms in the player colour, the dot and the
  edge; `SmallButton`'s pill is a `SmallButtonPainter` (public) with the look's paper, ink and player
  colours, and its `Text` label is ink in the look's button family, moved by the squish.
- `controller_app/lib/src/ui/stick_widgets.dart` — `StickPainter` (public): paper base ring with the ink
  edge, the knob in the player colour with the ink edge and shadow, squished while held, faded when not
  (`idleAlpha` 0.55, as before), `faintAlpha` 0.4 as before.
- `controller_app/lib/src/ui/tilt_view.dart` — the tilt circle's ring is paper, its dot the player's colour.
- `controller_app/lib/src/ui/controller_parts.dart` — `DemoReadout` is paper at 0.9 with ink text.
- `controller_app/lib/src/ui/bar_connection.dart` — `PlayerBadge` is `party.PlayerBadge` (the look's
  `ToyBadge` with the player's character) in a headroom box, key `playerBadge` and tooltip kept;
  `playerBadgeDiameter = 33` (below).
- `packages/toy_look/lib/src/toy_button.dart` — its private dash helper is now `paintDashedEdge`; the drawn
  dashes are identical.
- `packages/toy_look/lib/toy_look.dart` — exports `sticker_shadow.dart` and `toy_dash.dart`, so the phone's
  painters use the look's own shadow and dash rather than copying them.
- `packages/toy_look/test/toy_badge_test.dart` — the accessory-ink test above.
- `controller_app/test/connection_test.dart`, `joined_view_test.dart`, `host_mode_test.dart` — see the tests
  changed above.
- `docs/briefs/m13/s8-pad-look-report.md` — this report.

Not changed: `packages/party_host/lib/src/ui/player_badge.dart` — its `PlayerBadge(number, size)` already
draws the look's `ToyBadge` with `ToyCharacter.forPlayer(number)`, so the phone reuses it (rule 7's "one badge
widget for both apps").

Not mine (in the working tree before this job, outside `allow:`): `tv_test_app/windows/flutter/
generated_plugin_registrant.cc`, `generated_plugin_registrant.h` and `generated_plugins.cmake` show as
modified, with no diff — line endings only, from Flutter tooling (the same three s7 reported). The brief
itself, `docs/briefs/m13/s8-pad-look.md`, is untracked.

## The badge's diameter and the bar's height

- `playerBadgeDiameter = 33.0` px. With `toyAccessoryHeadroom(33) = 14.85` the box is 47.85 high, inside the
  bar's 48 px row, so the bar stays `topBarHeightPx = 4 + 48 = 52` px (measured again in
  `pad_badge_test.dart`: the box is 47.85, the chip is 48).
- 48 / (1 + 0.9 / 2) = 33.1 is the largest diameter that fits; 33 is the largest whole pixel under it, and it
  leaves the disc's shadow (scaled by 33/40) inside the bar's padding too.
- The box is bottom-aligned, so the accessory grows upwards into its headroom rather than over the bar.

## Every place on the pad that took a colour, and the token it takes now

| place | before | now |
| --- | --- | --- |
| face button fill | the old literals in `FaceButtonsView.colors` (green/red/blue/yellow), grey when at rest | `look.colors.faceA`…`faceY` (`faceFills`), always |
| face button edge | the same literal | `look.colors.ink`, `look.sizes.outlineWidth`, plus `paintStickerShadow` |
| face letter / game label | `Colors.black` / `scheme.onSurface` | `look.colors.ink` (`padLetter`, `padLabel`) |
| hidden button outline | `scheme.onSurface` at 0.12 | `padFaintInk` = ink at `toyShadowAlpha`, dashed |
| `PressFlash` | `Colors.white` at 0.75 | `look.colors.paper` at 0.75 |
| D-pad fill | `scheme.surfaceContainerHighest` | `look.colors.paper` + the shadow |
| D-pad lit arm | `scheme.primary` | `look.colors.player(n)` |
| D-pad arrows | `scheme.onSurface` (1 / 0.5) | `look.colors.ink` (1 / 0.5) |
| D-pad centre dot | arrow at 0.15 | ink at `toyShadowAlpha` |
| small button fill / pressed | `scheme.surfaceContainerHighest` / `scheme.primary` | `look.colors.paper` / the player colour |
| small button label | `scheme.onSurface` / `scheme.onPrimary` | `look.colors.ink` in `look.type.button` |
| stick base | `scheme.surfaceContainerHighest` | `look.colors.paper` |
| stick ring | `scheme.outline` at 0.5, 1.5 wide | the ink edge, `look.sizes.outlineWidth` |
| stick knob | `scheme.primary` (0.55 idle) | `look.colors.player(n)` (0.55 idle), ink edge, shadow |
| tilt ring / dot | `scheme.surfaceContainerHighest` / `scheme.primary` | `look.colors.paper` / the player colour |
| demo readout fill / text | `scheme.secondaryContainer` 0.9 / `scheme.onSecondaryContainer` | `look.colors.paper` 0.9 / `look.colors.ink` |
| bar badge | `look.colors.player(n)` disc with "P1" in `look.type.body` | `ToyBadge` with `ToyCharacter.forPlayer(n)` (the character's colour and accessory), the number in `look.type.title` |

The literal check: `grep -rn "Color(0x" controller_app/lib` and `grep -rn "Colors\." controller_app/lib`
both find nothing.

## Computed test values

- Face buttons at `side` 200: radius 32, centres at 0.31 of the side. The fill sample is 0.6 of a radius
  out (clear of the letter); the shadow/squish sample is one radius plus half the shadow's offset (34.5) along
  the offset's direction, inside the shadow and outside the disc's edge stroke — where the moved body covers
  it when pressed. The disc's top edge moves from row 132 to 136 (4 = the offset's y).
- D-pad at `side` 200: arms 68 wide from the middle, corners 12, dot radius 19.04. A lit arm's fill starts
  row 70 (the arm's edge at 66 plus the offset's 4) and column 69 for the down arm; the seam samples are the
  arms' side lines at (66, 100), (134, 100), (100, 66), (100, 134) — paper under a union, an ink line under
  separate arms; the shadow shows at (50, 136), under the left arm.
- Sticks: radius 50, knob 21. The knob's outline's first row where the stick's middle is: 37 at rest, 41
  held (4 = the offset's y); the shadow's crescent blend is (176, 168, 172) over paper.
- Small button 96 × 44: the shadow shows at (50, 57), and the pressed pill's moved edge is there instead.

## Self-check: docs/review-rules.md part A, items 1–5

1. **Every host setup.** The pad is the phone's own; nothing here differs by host, so nothing else needed a
   test. A joined phone draws the same pad, and the player badge (the only part that follows the host's
   number) shows that host's player number: `pad_badge_test.dart` (P3's character, P2's tooltip, none before
   a player is known) and `joined_view_test.dart`.
2. **When kept state starts and ends.** Nothing is held or remembered by the new drawing except
   `PressFlash`'s 180 ms ticker, unchanged (it starts on a press and its widget owns disposal —
   `pad_look_test.dart`, "a press flashes the look's paper", and the existing press-flash tests). The
   squish is immediate and stateless. No round, no players: the pad draws the same, with player 1's colour
   (`pad_look_test.dart`, "player 1 before one is known").
3. **How a new state combines with the others.** Nothing new pauses, hides or blocks input; the squish is
   drawing only, and every existing hit-area test passes unchanged — `controls_layer_test.dart` ("a tap
   between the controls reaches the game behind them; a tap on A stays on A"), `controller_screen_test.dart`
   ("Start and Select work, and sliding off releases"), `face_buttons`/`dpad` geometry tests.
4. **Stay in the job's folder.** Every edit is in `allow:` (`packages/toy_look`,
   `controller_app/lib`, `controller_app/test`, this report). `packages/party_host` needed no change: its
   `PlayerBadge` already draws the look's badge, so it is reused as it is. `tools/review.sh`: 0 fail, 5 notes
   (two files' line counts, three numbers carried over from the old drawing).
5. **Stop rather than overstep.** No file outside `allow:` was needed. The three places where the brief's
   words and the drawing meet are reported as deviations below, not chosen silently.

## Findings and risks

1. **The shadow's offset: `toyShadowOffset` or `ToySizes.shadowOffset`?** The brief's rule 2 says
   "`toyShadowOffset` scaled as `ToyButton` scales it", but `ToyButton` uses `ToySizes.shadowOffset` (3, 4)
   through `paintStickerShadow`; `toyShadowOffset` (2.25, 3) is the games' shape constant. The pad uses
   `paintStickerShadow` and `ToySizes.shadowOffset`, as `ToyButton`, `ToyBadge` and `ToyCard` do, so a press
   squish matches the menus' press (question 1).
2. **The D-pad's shadow stays under the whole plus while an arm is lit.** Rule 4 says one shadow under the
   whole shape; rule 3 says a pressed part loses its shadow. An arm's shadow can't be dropped from a shape
   whose shadow is drawn once, and dropping the plus's shadow while another arm is lit would look wrong. The
   lit arm's fill is moved by the offset and clipped to the plus, so the arm itself is drawn pushed in under
   the shadow the paper plus still casts. Its arrow moves with it (as `ToyButton`'s content moves), which the
   brief doesn't say either way.
3. **"A pixel in the centre is paper."** Rule 4 puts the centre dot (ink at `toyShadowAlpha`) over the exact
   centre, so the exact centre is the dot. The seam test samples the junction beside the dot — the four points
   on the arms' side lines — and the dot is tested separately as ink at `toyShadowAlpha`; both are in
   `pad_look_test.dart`.
4. **A not-held knob's faded fill shows its own shadow through it.** The knob is drawn at 0.55 over the
   shadow it casts (the shadow is drawn under it, as every look widget draws its shadow), so its colour is a
   blend of the two rather than the player colour at 55% over paper. The test says so; if the owner prefers a
   flat faded disc, the knob would draw its shadow only outside its own edge (question 3).
5. **The pad reads its look from `toyLookProvider`, not `ToyLookScope`.** `controls_layer_test.dart` pumps
   `ControlsLayer` under a bare `MaterialApp`, with no scope above it, and that test pins the pad's hit areas
   and must pass unchanged (rule 1). The provider is the same `ToyLook` the app's scope is built from
   (`main.dart`), the pad's widgets are `Consumer`s already, and a look change rebuilds them. The screen's
   own widgets still read the scope; the pad is the exception, and its code says why.
6. **The labels stay widgets where they were widgets.** The small buttons keep their `Text` (ink, in the look's
   button family, moved by the squish) rather than painting the label in the painter, so `find.text('Start')`
   taps and the button's semantics stay as they were; only the pill is painted. Face buttons' letters are
   painted (they were painted before).
7. **The tilt view's circle takes the look's colours, not its edge.** Rule 8 asks for colours; the ring keeps
   its 1 px guides and 1.5 px dead-zone ring as they were. The Calibrate button stays a themed
   `FilledButton.tonal`, since it already takes the look's theme.
8. **The face button's pressed look changed from a 0.94 shrink to the squish**, as rule 2 and rule 3 ask; the
   drawn circle's radius no longer changes with a press, so nothing a thumb hits moved.
9. **`pad_drawing.dart` is a new part of the `pad_widgets` library** (`face_buttons.dart` is a part file, so
   the helpers are visible to both without an export), keeping each file under 400 lines and each function
   under 60 (`pad_widgets.dart` 346, `face_buttons.dart` 205, `stick_widgets.dart` 236).

## Questions and suggestions

1. `toyShadowOffset` (2.25, 3, the games' shape) or `ToySizes.shadowOffset` (3, 4, every menu widget)? I used
   the latter, through `paintStickerShadow`, so a press squishes as much as a `ToyButton`'s. Say if the pad
   should use the smaller one.
2. Should the D-pad's plus keep its shadow while an arm is lit (my choice, rule 4's "one shadow"), or drop it
   while any arm is lit (rule 3 read strictly)? And should the lit arm's arrow move with it?
3. Is a faded (not-held) knob allowed to show its own shadow through it, or should it be a flat faded disc?
4. The pad reads `toyLookProvider` instead of the scope, for the bare-`MaterialApp` test. If you'd rather the
   scope were the only way (as D5 says), the fix is the test's harness, not the pad: `controls_layer_test`'s
   `pumpOverGame` would wrap its `MaterialApp` in a `ToyLookScope`.
5. Rule 2's "flat fill, no shade band" is met by drawing no shader: the pad's painters never touch
   `look.shade`, so a face button is the same in both palettes and with effects off.
6. The look's contrast test already covers ink on `faceA`–`faceY` in both palettes (`contrast_test.dart`,
   keys "ink on faceA"…"ink on faceY"), so no test was added there.

## Commit message

M13 step 8: the phone's pad drawn in the look

The pad's face buttons fill with the look's face colours, with ink
edges and the sticker shadow, Fredoka letters and Nunito labels, and
a dashed outline for an unused button. A press squishes: no shadow,
body, edge and text moved by the shadow's offset, for face buttons,
D-pad arms, small buttons and a held knob. The D-pad is one paper plus
with a single shadow, ink arrows and the player's colour on lit arms;
sticks and small buttons are paper and ink; PressFlash flashes paper.
The bar's badge is the look's ToyBadge with the player's character,
33 px wide so the 52 px bar keeps its height. The pad's painters take a
ToyLook; controller_app/lib has no colour literals left.

## Status row

M13 step 8 (the pad in the look): done — the phone's pad, sticks, small buttons, PressFlash and the bar's player badge are drawn from the look at today's sizes and hit areas, with the press squish; open: the shadow-offset and lit-arm-shadow readings (questions 1–2), the not-held knob's faded fill (question 3), and a device look at the pad in step 9.

## Delete

- controller_app/test/probe_test.dart

## Claude's review (Nov 9, 2026)

Accepted. Checks green (look 109, phone 428); review.sh 0 fail. Claude rendered every pad part in both palettes, with the real fonts: face colours with ink edges and shadows, the paper D-pad and sticks, the press squish, the lit arms in the player's colour.

1. **A hidden button's outline** was ink at the shadow's strength, which all but vanished on Night's grape. It now uses `padHiddenOutline`, the background's text colour at that strength (ink on Sunny, white on Night). Fixed test-first in `pad_look_test`. `padFaintInk` stays for the D-pad's centre dot, which sits on paper.
2. **The offset:** `ToySizes.shadowOffset`, as chosen. A pad press squishes like a menu button.
3. **The D-pad keeps one shadow** while an arm is lit, and the lit arrow moves with its arm. Both are as drawn.
4. **The faded knob** may show its shadow through it.
5. **Reading `toyLookProvider`:** accepted. The phone's `ToyLookScope` is built from the same provider, so the two can't differ. A pad test may still pump without the scope.
6. The worker's `probe_test.dart` was never left in the tree; nothing to delete.
7. **For step 9, on a phone:** the pad over a running game at the lowest opacity, and the badge's accessory inside the bar on a small phone.
