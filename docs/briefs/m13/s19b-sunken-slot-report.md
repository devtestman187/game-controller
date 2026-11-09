# M13 device fixes 9b: an empty target is a sunken slot

**Done.** All seven rules are in and tested, and every check passes (`tools/check.sh format analyze
look puzzle arena host phone tv`), with `tools/review.sh` at 0 fail. Every piece of every puzzle is at
least **0.10 OKLab** from its empty slot in both palettes: the closest is the fish's eye at **0.125**
in Sunny and the castle's door at **0.143** in Night.

## Tests, before and after

| suite | before | after |
| --- | --- | --- |
| look | 111 | 112 |
| puzzle | 242 | 253 |
| arena | 66 | 69 |
| host | 254 | 254 |
| phone | 437 | 437 |
| tv | 53 (+1 skipped) | 53 (+1 skipped) |

The new puzzle ones: `slot_contrast_test` (2, the distance table), `sky_behind_test` (4: the view on
a sky, Sunny and Night; a phone's match on a tablet; a view drawn alone), `placed_look_test` (4: the
slot darker/lighter, the inner shadow, the dashed slot against a solid edge), `placed_look_png_test`
(1, which writes the picture). `toy_shape_test` gains the slot's own test; `arena_sky_test` adds the
Arena's 3. Two existing look tests changed meaning with the fill (`look_paint_test`: the Easy tint and
the hint now sit over the slot) and are still 1 test each.

## The slot's values

- **Fill:** the board's colour mixed **4 %** toward `onBackground` — Sunny `#FFEFD0` → **`#F6E6CA`**
  (a shade darker), Night `#30297A` → **`#38327F`** (a shade lighter). No palette branch: the two
  `onBackground` tokens (ink and white) do the direction on their own.
- **Inner shadow:** the style's ink at the look's shadow alpha (0.35), a stroke **1.6 ×** the outline
  wide (6.4 px at a 4 px outline), blurred **0.6 ×** the outline, shifted by the style's shadow
  offset and clipped to the slot, so the band lies along the top and left — the edges the light
  reaches — and nothing falls outside.
- **Edge:** unchanged from s19 — the look's dashed ink line with **square caps**; a ready target is
  `good` at 1.5 × width and a hinted one `focus`, both solid, as before.
- **Easy tint:** the piece's own colour at **0.10** over the slot; Medium and Hard none. A ready
  target's fill stays 0.45; a hint's glow stays `focus` at 0.5.
- **The sweep:** rendered, the closest piece comes out at 0.131/0.152 (2 %), **0.125/0.143 (4 %,
  chosen)**, 0.111/0.133 (8 %) and at 12 % Sunny falls to 0.094 (the snowman's head), so 4 % keeps
  the most margin while the slot is still a visible shade of the mat.

## The per-piece distance (OKLab, placed mean against the empty slot's mean)

| puzzle | piece | Sunny | Night |
| --- | --- | --- | --- |
| house | walls | 0.151 | 0.410 |
| house | roof | 0.358 | 0.260 |
| house | door | 0.366 | 0.172 |
| house | sun | 0.133 | 0.464 |
| rocket | body | 0.188 | 0.303 |
| rocket | nose | 0.298 | 0.292 |
| rocket | left fin | 0.286 | 0.222 |
| rocket | right fin | 0.351 | 0.156 |
| rocket | window | 0.167 | 0.362 |
| tree | trunk | 0.322 | 0.219 |
| tree | crown | 0.250 | 0.357 |
| tree | sun | 0.132 | 0.470 |
| tree | mountain | 0.278 | 0.245 |
| sun | rays | 0.217 | 0.334 |
| sun | sun | 0.132 | 0.465 |
| sun | cloud | 0.172 | 0.344 |
| sun | sea | 0.232 | 0.276 |
| fish | body | 0.230 | 0.351 |
| fish | tail | 0.304 | 0.270 |
| fish | fin | 0.324 | 0.188 |
| fish | eye | **0.125** | 0.469 |
| fish | bubble | 0.224 | 0.302 |
| snowman | bottom | 0.295 | 0.230 |
| snowman | head | 0.130 | 0.374 |
| snowman | hat | 0.278 | 0.202 |
| snowman | scarf | 0.126 | 0.299 |
| snowman | nose | 0.129 | 0.332 |
| boat | hull | 0.357 | 0.254 |
| boat | mast | 0.374 | 0.178 |
| boat | sail | 0.191 | 0.373 |
| boat | flag | 0.252 | 0.306 |
| boat | wave 1 | 0.255 | 0.287 |
| boat | wave 2 | 0.255 | 0.287 |
| car | body | 0.342 | 0.285 |
| car | cabin | 0.277 | 0.241 |
| car | window | 0.179 | 0.364 |
| car | wheel front | 0.346 | 0.248 |
| car | wheel back | 0.346 | 0.248 |
| car | headlight | 0.144 | 0.495 |
| car | road | 0.222 | 0.308 |
| robot | body | 0.333 | 0.241 |
| robot | head | 0.264 | 0.292 |
| robot | eye left | 0.147 | 0.523 |
| robot | eye right | 0.147 | 0.523 |
| robot | arm left | 0.310 | 0.309 |
| robot | arm right | 0.208 | 0.371 |
| robot | base | 0.352 | 0.250 |
| train | engine | 0.360 | 0.283 |
| train | cab | 0.254 | 0.243 |
| train | window | 0.175 | 0.387 |
| train | chimney | 0.344 | 0.209 |
| train | wheel front | 0.356 | 0.243 |
| train | wheel back | 0.359 | 0.243 |
| train | carriage | 0.275 | 0.381 |
| castle | wall | 0.181 | 0.371 |
| castle | tower left | 0.344 | 0.245 |
| castle | tower right | 0.347 | 0.206 |
| castle | roof left | 0.355 | 0.277 |
| castle | roof right | 0.233 | 0.364 |
| castle | door | 0.471 | **0.143** |
| castle | window | 0.175 | 0.392 |
| butterfly | body | 0.403 | 0.184 |
| butterfly | upper left | 0.284 | 0.298 |
| butterfly | upper right | 0.209 | 0.388 |
| butterfly | lower left | 0.285 | 0.379 |
| butterfly | lower right | 0.327 | 0.257 |
| butterfly | spot left | 0.157 | 0.510 |
| butterfly | spot right | 0.158 | 0.508 |

Measured as s19 planned: off rendered 640 × 360 frames (4 px a unit), the mean OKLab of the pixels
at least 2 px inside the piece's outline at its target, one frame per piece locked with every other
piece in the tray (`support/piece_colours.dart`, `slot_contrast_test`).

## What changed, and why the slots are drawn first

A slot is drawn **under the picture**, before any piece. Drawn in the picture's order, an opaque slot
hides a placed piece it is drawn over — the sun puzzle's `rays` and `sun` share a centre, and the
house's door slot sits inside the wall — and a placed piece then measures as its own slot (Night's
sun came out at 0.000, the walls at 0.120). Under the picture, a placed piece stays raised and whole
and the empty target over it shows only its dashed edge. That is rule 3, and it is also what brings
the distances above. The ✓ no longer *needs* to move clear of an empty target drawn over a piece, but
it still does (`_checkPlace` unchanged) and its s19 test still passes.

## The sky (rule 7)

`PuzzlePainter`, `MatchPainter` and `ArenaPainter` take `fillsBackground` (on by default), and
`PuzzleView`, `MatchView` and `ArenaField` pass `!toyStillSkyAbove(context)`: the host's Shape Race and
Arena screens and a joined phone already wrap their content in a `ToyStillSky` because a sky stands
behind them, while a view drawn alone — the pictures the tests write — has none and still fills. The
match passes the flag down to its two boards. The Arena's fill is its `field`, its play mat, so with
the sky behind it the mat's colour goes and the arena's dots, pad, goal, walls and marbles stand on
the sky.

## The mirror (rule 4)

As s19 chose: unchanged — the faint fill and the thin line (`mirror_painter.dart` is untouched). The
three `m12-mirror-*.png` files changed anyway, because they are drawn from a `MatchView` whose boards
now show slots; kept, as the brief allows. `docs/design/m13-portrait-hud.png`, `m13-puzzles.png`,
`m13-puzzles-night.png` and `m13-tablet-board.png` are also rewritten by running the suite (outside
`allow`); they were put back from HEAD, as s19 did.

## The design doc (rule 5)

`docs/design/look-and-sound.md` section 5: the Shape Race bullet's "targets are drawn as dashed ink
outlines with a faint fill (Easy: in the piece's colour)" is replaced by a bullet with s19's rules 1–3
("An empty target is a sunken slot", decided at device test 3, owner, Nov 9), and a second bullet
records that the games stand on the sky.

## The picture (rule 6)

`docs/design/m13-placed-look.png`: the rocket and the house half-done, Sunny above and Night below,
each with its name and count. `placed_look_png_test` draws it from the same `PuzzleView` and puzzle
files every run, so it is deterministic; it is 2 × (2 × 320 + gaps) with the look's own fonts.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** Drawing only: the TV/PC, "Play on this phone", "Show on this device" and a
   joined phone all reach `PuzzleView`/`MatchView`/`ArenaField` under a `ToyStillSky`, so all four
   show the sky (`sky_behind_test`, `arena_sky_test`); host 254, phone 437 and tv 53 tests pass, and
   only the painting changed, so an older build still plays.
2. **When kept state starts and ends.** Nothing kept: the painters are pure over each snapshot, and a
   slot's tint, ready and hint come from that frame only (`look_paint_test`'s hint test).
3. **How a new state combines with the others.** No pause, wait or input state is touched; the one
   picture rule that depends on state, where a ✓ goes, is unchanged and tested ("a locked wall's ✓
   moves out of the empty door drawn over it").
4. **Stay in the job's folder.** Four `docs/design/m13-*.png` were rewritten by running the suite and
   put back from HEAD; the three allowed m12 mirrors are kept (they show targets). Everything else is
   inside `allow`.
5. **Stop rather than overstep.** No `allow` file is over 400 lines (the marks moved to `view.dart`
   rather than a new part, which `allow` does not name); the two decisions the brief left open are
   Q1 and Q2 below rather than guesses.

## Questions

1. **The slot under the picture.** Drawing slots first is what makes rule 2 and rule 3 hold together
   (see above), but it changes the door-over-wall look: only the door's dashed edge shows over the
   placed wall now. Is that the intent, or should the wall be dimmed some other way?
2. **`toyStillSkyAbove` stands for "a sky is behind".** It is the only marker in `toy_look`'s public
   API, and the games' screens put a `ToyStillSky` exactly where a `ToyBackground` is behind them. Its
   cost: a test harness that puts a `ToyStillSky` over an app with no sky draws the games unfilled
   (host and phone tests pass; no picture is written from those). A dedicated `ToyBackground`-behind
   marker would be a `toy_look` job, and its sky files are s22's.
3. **The Arena's mat.** "Treat it the same" means the whole `field` fill goes when a sky is behind, so
   the play mat's colour is replaced by the sky (with the arena's own dots on it). I did not add a
   translucent mat; say if you want one.
4. **`targetNeutral`** is now used only by the mirror; the board's painter no longer reads it.
   `toy_colors.dart` is outside `allow`, so it is left in place.

## Commit message

```
M13 device fixes 9b: an empty target is a sunken slot

The board's colour a shade toward onBackground (4 %: darker in Sunny,
lighter in Night), a soft inner shadow on the lit edges, the dashed edge
with s19's square caps, and Easy's 10 % tint of the piece's colour. Slots
are drawn under the picture, so a placed piece is never hidden, and every
piece of every puzzle is at least 0.10 OKLab from its empty slot (0.125 in
Sunny, 0.143 in Night). The two Shape Race painters and the Arena's stop
filling their box where a ToyBackground is behind them, so the sky shows.
```

## Status row

M13 19b (an empty target is a sunken slot): **done** ([s19b-sunken-slot-report.md](s19b-sunken-slot-report.md)) —
the board 4 % toward `onBackground`, the inner shadow on the lit edges, the square-capped dashes and
Easy's 10 % tint, drawn under the picture; every piece of every puzzle is at least 0.10 OKLab from its
empty slot in Sunny (0.125) and Night (0.143); the games stop filling their box where a sky is behind
them; puzzle 242 → 253, arena 66 → 69, look 111 → 112; checks pass, review 0 fail. Open: Q1 (the slot
under the picture), Q2 (a sky-behind marker of its own), Q3 (the Arena's mat on the sky).

## Delete

- packages/puzzle_game/test/slot_sweep_scratch_test.dart

## Claude's review

Accepted. `m13-placed-look.png` reads as the brief asked: empty targets sunken and dashed, placed pieces raised with their ✓, the sky round the boards in both looks; every piece clears 0.10 (lowest 0.125 Sunny, 0.143 Night). Checks re-run on m13 with s21 merged: format, analyze, puzzle 252, arena 69, host 268, phone 438 pass.
- Q1 (slots under the picture, only the door's dashes over a placed wall): yes, intended; the dashes still say where the door goes.
- Q2 (`ToyStillSky` as the "sky behind" marker): fine for now; the end-of-M13 review rechecks it against s22's sky files.
- Q3 (the Arena's mat): no translucent mat for now; the walls bound the field. Check it on a device; the Arena party work in M14 may redo the field anyway.
- Q4 (`targetNeutral` used only by the mirror): leave it.
- The suite also rewrote `m13-portrait-hud.png`, `m13-puzzles*.png` and `m13-tablet-board.png`; they changed only because the targets are drawn as slots now, so they are committed with this.
