# M13 device fixes 9: a placed piece always looks placed — report

**Stopped** at rule 3's slot fill. Rules 1 and 2 (the ✓) and rule 3's edge (a dashed, not a solid,
empty target) are done and tested; rule 3's fill cannot meet its own test as written, so the design
doc, the recess, the mirror change and the picture are not made (review rules A5). The numbers are
below; question 1 asks which way to go.

## Why I stopped

Rule 3 says the recess is "the board's colour **a little** darker (Sunny) or lighter (Night)", and
test 3 says every piece's placed-vs-empty distance must be **≥ OKLab 0.12**. In Sunny those two can't
both hold:

- The Sunny mat is `#FFEFD0`, OKLab L 0.956. The pieces' placed means span **L 0.46** (the boat's
  mast) to **0.90** (the boat's sail) — a near-continuous set in lightness, with hues all round.
- The *palest* piece (the boat's sail, L 0.90 and all but grey) is only 0.06 from the cream mat, so
  the slot can't stay near the mat either: it has to fall below **L 0.78** just to clear the sail,
  and below **L 0.34** to clear the darkest piece (the boat's mast, L 0.46). The second bound wins,
  and it is the ink, not the mat.
- The sweep below confirms it: mixing the mat toward the ink, the best distance reaches 0.12 only at
  **≈ 89 % toward the ink**, i.e. `#352C54` — 20 % of the mat's lightness. Night is the easy half:
  the board itself already gives 0.173, and 10 % toward white still gives 0.127.

And a near-ink slot breaks the other half of rule 3: the empty target's *dashed ink* edge
(`_colours.ink` `#1E1646`) would be invisible on a `#352C54` fill, so the slot would read as one
solid dark shape — the very thing test 4 ("an empty target has no solid ink edge") forbids. A deep
recess needs a *light* dashed edge, which is a look decision, not a number I can pick.

Worse, a "recess-like" mid-tone slot — what rule 3 describes — makes things *worse* than today for
most pieces, not better (Sunny 30 % toward the ink: rocket body 0.056 against today's 0.083; 50 %:
tree mountain 0.031 against today's 0.271). The owner's goal ("higher contrast", brief line 1) is
only served by the near-ink slot.

## Tests

| suite | before | after |
| --- | --- | --- |
| look | 111 | 111 |
| puzzle | **227** | **230** (231 while `slot_scratch_test.dart` is still on disk) |
| phone | 435 | 435 |
| tv | pass | pass |

The three new tests are in `test/placed_look_test.dart`, and each failed on the old painter first:
the rocket window's ✓ count was 0, the house wall's ✓ count was 0, and the empty target's top edge
ran solid (81 px in a row) instead of dashed. `tools/check.sh format analyze look puzzle phone tv`:
**all pass** (85 s).

## Files changed

- `packages/puzzle_game/lib/src/puzzle_painter.dart` — rule 1: only a target *later in the picture*
  that is still open hides a locked piece's ✓ (`_insideOpenTarget` → `_checkPlace`, fed the set of
  filled targets from `paint`). Rule 2: the ✓ moves to the first place on the piece clear of those
  targets (`_checkPlaces`: the middle, then 0.55 of the way to each corner, or half the radius round
  a circle), and falls back to the middle. Rule 3's edge: the empty target's dashes end **square**
  (`StrokeCap.butt`; round caps were closing the 6 px dashes' 4 px gaps, so every empty target had a
  solid edge) and use the look's own `toyDashOn`/`toyDashOff` instead of the painter's 2 px/1.6 px.
- `packages/puzzle_game/test/placed_look_test.dart` — new: the rocket window's ✓ is drawn though the
  body's outline is under it; a locked wall's ✓ is drawn on the wall and not in the empty door; an
  empty target's top edge is dashed (≤ 6 px runs) where a placed piece's is solid (> 60 px). The
  contrast test (test 3) was written, failed, and is **not** in the file — see question 1.
- `packages/puzzle_game/test/support/oklab.dart` — new: OKLab conversion and the mean colour of a
  piece's area off a rendered frame (used by the measurement below; not used by a kept test).
- `packages/puzzle_game/test/slot_scratch_test.dart` — temporary: prints the per-piece table and the
  sweep below. Delete.
- `packages/toy_look/lib/src/toy_slot.dart` — unused helper for a sunken slot (fill, then an inner
  shadow of the ink: offset (2, 2) look px, 4 px wide, 1.2 px blur, 30 % alpha, clipped to the
  shape). Not exported; kept only as the sketch of rule 3's recess. Delete.
- `docs/design/m12-mirror-169.png`, `m12-mirror-iphone.png`, `m12-mirror-iphone-stick.png` — running
  the suite rewrites them in this environment (every PNG it writes comes out 2–3 % smaller than the
  checked-in one, this job's code or not: a different encoder or engine here). The mirror painter is
  **unchanged**, so I put the checked-in pictures back and the three show no change, as they should.
- `docs/design/m13-portrait-hud.png` — rewritten by `portrait_hud_png_test` the same way; outside
  this job's `allow`, so I restored it from HEAD. It shows no change.

## The slot's colours and shadow values (what I tried, not kept)

I first built the recess as rule 3 reads: Sunny `slot = #B2A792` (the mat 40 % toward the ink), Night
`#837FAF` (the board 15 % toward white), a piece tint of 0.15 on Easy, and the inner shadow above.
Measured off rendered frames, it failed test 3 — and, the important part, made several pieces *less*
distinct than today: Sunny walls **0.075** (today 0.156), rocket body **0.081** (0.083), window
**0.096** (0.160), tree mountain **0.093** (0.271), crown 0.121 (0.225). Only the pale boat and the
dark pieces gained. That is the shape of the sweep below: a mat-toned slot sits in the middle of the
pieces, where they are crowded.

What a slot would have to be to pass (model: the slot's fill with 15 % of the piece's colour over it,
against the measured placed colour):

| Sunny, mat → ink | 0 % | 30 % | 50 % | 70 % | 80 % | 85 % | **90 %** | 95 % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| worst piece | 0.072 | 0.056 | 0.031 | 0.044 | 0.086 | 0.116 | **0.149** | 0.183 |

`#FFEFD0` → `#352C54` at 90 % (the worst is then the boat's mast, 0.149).

| Night, board → white | 0 % | 5 % | 10 % | 15 % | 20 % | 25 % |
| --- | --- | --- | --- | --- | --- | --- |
| worst piece | 0.173 | 0.149 | 0.127 | 0.111 | 0.101 | 0.080 |

`#30297A` → `#453E87` at 10 % works; "a little lighter" survives in Night.

The tint costs contrast: with no tint the Night board gives 0.192 instead of 0.173 (and 20 % toward
white still passes), and Sunny reaches 0.12 at ≈ 84 % toward the ink instead of ≈ 89 %.

## The measured placed-vs-empty distance for every piece

Rendered at 640 × 360, 4 px a field unit, the mean OKLab colour of the piece's area 2 px inside its
outline (so the ink edge and the dashes are excluded). "After" is the same as "before" for the fill:
only the ✓ and the edge changed, and both are outside the measured area.

| palette | puzzle | piece | placed (L, a, b) | empty (L, a, b) | distance | needs 0.12 |
| --- | --- | --- | --- | --- | --- | --- |
| Sunny | house | walls | 0.734, 0.035, 0.118 | 0.879, 0.014, 0.067 | 0.156 | ok |
| Sunny | house | roof | 0.534, 0.140, 0.079 | 0.847, 0.038, 0.050 | 0.331 | ok |
| Sunny | house | door | 0.480, 0.021, 0.022 | 0.800, 0.018, 0.062 | 0.322 | ok |
| Sunny | house | sun | 0.836, −0.017, 0.144 | 0.931, −0.001, 0.079 | **0.117** | **fails** |
| Sunny | rocket | body | 0.828, −0.008, −0.008 | 0.905, 0.001, 0.023 | **0.083** | **fails** |
| Sunny | rocket | nose | 0.585, 0.144, 0.081 | 0.864, 0.045, 0.052 | 0.298 | ok |
| Sunny | rocket | left fin | 0.599, −0.059, −0.100 | 0.874, −0.016, 0.004 | 0.296 | ok |
| Sunny | rocket | right fin | 0.574, −0.054, −0.092 | 0.863, −0.014, 0.009 | 0.309 | ok |
| Sunny | rocket | window | 0.759, −0.043, −0.062 | 0.899, −0.010, 0.007 | 0.160 | ok |
| Sunny | tree | trunk | 0.529, 0.030, 0.049 | 0.834, 0.012, 0.046 | 0.305 | ok |
| Sunny | tree | crown | 0.668, −0.134, 0.067 | 0.871, −0.040, 0.047 | 0.225 | ok |
| Sunny | tree | sun | 0.842, −0.016, 0.146 | 0.931, −0.001, 0.079 | **0.113** | **fails** |
| Sunny | tree | mountain | 0.609, −0.016, −0.006 | 0.877, 0.000, 0.032 | 0.271 | ok |
| Sunny | boat | hull | 0.547, 0.039, 0.055 | 0.899, 0.005, 0.044 | 0.354 | ok |
| Sunny | boat | mast | 0.464, 0.017, 0.019 | 0.899, 0.005, 0.044 | 0.436 | ok |
| Sunny | boat | sail | 0.897, −0.005, −0.002 | 0.899, 0.005, 0.044 | **0.048** | **fails** |
| Sunny | boat | flag | 0.563, 0.113, 0.064 | 0.899, 0.005, 0.044 | 0.353 | ok |
| Sunny | boat | wave 1 | 0.626, −0.057, −0.081 | 0.899, 0.005, 0.044 | 0.307 | ok |
| Sunny | boat | wave 2 | 0.626, −0.057, −0.081 | 0.899, 0.005, 0.044 | 0.307 | ok |
| Night | house | walls | 0.733, 0.035, 0.118 | 0.431, 0.043, −0.043 | 0.342 | ok |
| Night | house | roof | 0.533, 0.140, 0.080 | 0.373, 0.072, −0.074 | 0.232 | ok |
| Night | house | door | 0.477, 0.020, 0.024 | 0.438, 0.044, −0.026 | **0.068** | **fails** |
| Night | house | sun | 0.835, −0.017, 0.145 | 0.465, 0.027, −0.032 | 0.412 | ok |
| Night | rocket | body | 0.826, −0.008, −0.007 | 0.492, 0.019, −0.089 | 0.345 | ok |
| Night | rocket | nose | 0.583, 0.143, 0.082 | 0.397, 0.078, −0.068 | 0.247 | ok |
| Night | rocket | left fin | 0.598, −0.059, −0.099 | 0.419, −0.002, −0.129 | 0.190 | ok |
| Night | rocket | right fin | 0.572, −0.054, −0.091 | 0.403, 0.002, −0.127 | 0.182 | ok |
| Night | rocket | window | 0.757, −0.044, −0.061 | 0.561, 0.005, −0.087 | 0.203 | ok |
| Night | tree | trunk | 0.527, 0.029, 0.050 | 0.377, 0.037, −0.075 | 0.195 | ok |
| Night | tree | crown | 0.667, −0.134, 0.067 | 0.407, −0.016, −0.076 | 0.320 | ok |
| Night | tree | sun | 0.841, −0.016, 0.146 | 0.465, 0.027, −0.032 | 0.418 | ok |
| Night | tree | mountain | 0.609, −0.016, −0.005 | 0.412, 0.022, −0.097 | 0.220 | ok |
| Night | boat | hull | 0.547, 0.039, 0.055 | 0.426, 0.030, −0.124 | 0.216 | ok |
| Night | boat | mast | 0.462, 0.017, 0.020 | 0.426, 0.030, −0.124 | 0.149 | ok |
| Night | boat | sail | 0.896, −0.005, −0.002 | 0.426, 0.030, −0.124 | 0.487 | ok |
| Night | boat | flag | 0.558, 0.111, 0.067 | 0.426, 0.030, −0.124 | 0.246 | ok |
| Night | boat | wave 1 | 0.622, −0.058, −0.079 | 0.426, 0.030, −0.124 | 0.219 | ok |
| Night | boat | wave 2 | 0.622, −0.058, −0.079 | 0.426, 0.030, −0.124 | 0.219 | ok |

(The house's ✓ now sits at a corner of the walls, clear of the empty door, so its placed mean is a
few thousandths from HEAD's. Nothing else moves.)

## The mirror

Chosen: **no change**. The mirror keeps its faint fill and thin line (`_targetFill`, `_targetLine`);
a recess drawn at mirror size would grey a shape a few pixels wide and, with the near-ink slot the
test demands, would read as a solid dark blot. `mirror_painter.dart` is untouched and the three m12
mirror pictures are unchanged.

## Self-check (review rules part A)

1. **Every host setup.** Drawing only: the same painter draws the TV, a host phone's own board, a
   viewer phone and a joined phone, and reads nothing but the frame's snapshot. Tested in the view at
   640 × 360 in both palettes (`placed_look_test`); the phone and tv suites pass unchanged.
2. **When kept state starts and ends.** Nothing new is kept: the ✓ is the existing locked moment
   (`ageMs`), the marks come from `state == locked`, and `filled` is read fresh from the snapshot each
   paint. No timer, nothing runs without a round (`piece_moments_test`, `view_test`).
3. **How a new state combines with the others.** No new pause, wait or input: the ✓ and the dashes
   depend only on the snapshot, so a paused round, a host away, a player away and the results draw
   what they did before (`puzzle_session_test`, `view_test`, `phone` suite).
4. **Stay in the job's folder.** Wrote only inside `allow:`. `docs/design/m13-portrait-hud.png` was
   rewritten by running the suite (outside `allow`) and put back from HEAD; the three m12 mirror PNGs
   were likewise rewritten and put back.
5. **Stop rather than overstep.** This job: rule 3's fill and its 0.12 test contradict in Sunny (the
   table above), so the recess, its colour token, the mirror, the design doc edit and the picture are
   not made.

## Questions and suggestions

1. **Which way out of the slot's contradiction?** (a) Deep recess: the slot is the mat 90 % toward
   the ink (`#352C54` in Sunny, `#453E87` in Night at 10 % toward white), with its dashed edge in the
   **mat's** colour, so it stays visible — a real hole, maximum contrast, and a new look word ("the
   slot is a hole to the ink") for the design doc. (b) Keep "a little darker" and lower test 3: a
   mat-toned slot can reach **0.08–0.10** at best in Sunny (0.096 at a third of the way to the ink,
   with no tint; the pale sail and the dark mast pull in opposite directions), so 0.12 is out of
   reach at any mat-tone. (c) Have s17 recolour the pale pieces first (the sail at L 0.90 is the
   binding one at the light end) and re-measure — but the dark end (mast L 0.46) still forces a
   near-ink slot. My suggestion is (a); it is the only one that beats today's contrast for every
   piece.
2. **The Easy tint works against contrast.** The 15 % piece tint moves the slot *toward* the piece:
   it costs 0.01–0.02 of the distance, and about 5 points less of the mat → ink mix needed at no
   tint. If (a) is chosen, consider dropping the tint to ~5 % or keeping the hint to the glow only.
3. **What the ✓ looks like when it moves.** It now sits near a corner of the wall; on a large piece
   that reads a little odd but is clearly visible. If you want it invariant, a small ink-ringed badge
   at the piece's middle (drawn over any empty slot) would do it; that's another look decision.

## Commit message

```
Keep a placed piece's ✓ and give an empty target a dashed edge

A locked piece's ✓ is hidden only by an open target drawn later in the
picture — a door over a wall — never by one under it, as the rocket's body
is under its window. When one does cover the piece's middle the ✓ moves to
the first place on the piece that is clear of it (part way to a corner, or
round half a circle's radius), and never goes away.

An empty target's dashes now end square: round caps were closing the 6 px
dashes' 4 px gaps, so every slot read as a solid ink edge and a placed
piece's solid edge looked the same.
```

## Status row

M13 19 (device fixes 9, a placed piece always looks placed): **stopped** at the slot's fill — the ✓
rules and the dashed empty edge are in and tested (puzzle 227 → 230), but "the mat a little darker"
and the 0.12 OKLab test contradict in Sunny (0.12 needs the mat 90 % toward the ink, which then hides
the ink dashes); open: Q1 (deep recess with light dashes, or a lower threshold), and with it the
recess, the mirror, the design doc and `m13-placed-look.png`.

## Delete

- packages/puzzle_game/test/slot_scratch_test.dart
- packages/puzzle_game/test/support/oklab.dart
- packages/toy_look/lib/src/toy_slot.dart

## Claude's review

- Accepted rules 1 and 2 (the ✓) and the dash caps; committed.
- The stop is fair: the contrast test was set against today's palette, which s17 is changing. s17 makes every piece at least 0.15 from the board, so "a little darker" slot can work. Answer to question 1: (b), a mat-toned slot, finished in s19b after s17 lands, with the test set against s17's palette. Question 2: keep a faint Easy tint, at most 10%.
