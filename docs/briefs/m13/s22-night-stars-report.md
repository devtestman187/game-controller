# M13 12: a starry Night sky

Owner, Nov 9, 2026: "In night mode, have the background look more like stars". Night's polka dots are now a
scattered star field — many tiny points, some small dots, and pale yellow four-pointed sparkles about one per
200 × 200 px — that drifts with the sky and twinkles while it moves. Sunny's sky is untouched: its Canvas frame is
pinned to the checksum it had before the job (948082591).

Picture: [m13-night-sky.png](../../design/m13-night-sky.png) — Night alone (top) and behind a game picker's two
cards (bottom), drawn by the Canvas fallback at one fixed moment of the drift.

## The rules, rule by rule

1. **Night is stars, Sunny is dots.** `ToyColors` gained `hasStars` (false for Sunny, true for Night) and `star`
   (`#FFD23F`, both palettes; only Night draws with it). `ToyBackgroundPainter` draws `ToyStars.paint` where the
   sky has stars and `_paintDots` where it doesn't; the glow, background, theme and every other token are as they
   were, and the sky owns no ink edges: a star is a point of light.
2. **Twinkles while the sky moves, still when it doesn't.** The twinkle's clock is the drift's own ticker: the
   painter now takes the sky's `ValueListenable<Duration>` beside its shift and repaints on either, so a held sky
   (a round's screens, effects off, reduced motion) stops the stars as it stops the drift, and shows them at the
   moment it stopped. A held sky keeps its field; no star ever goes out (a twinkle only dims to 0.6 of its size's
   alpha), so a still sky is never blank.
3. **Deterministic, seamless, no bunching.** One star a 32 px cell, its place, size and twinkle from a hash of the
   cell's place in a 32 × 32-cell tile (1024 px). The drift's wrap is that tile (`ToySky.wrapPx`), so a full tile of
   drift brings the same sky back and no star jumps. The jitter is scaled to each star's own reach, so a star stays
   wholly inside its cell — which is what lets the shader look at one cell a pixel — and the field cannot clump or
   leave a hole.
4. **Both paths.** `ToyStars` holds the field; the Canvas fallback draws it, and `toy_backdrop.frag` draws the same
   field per pixel from the same float hash and the numbers `ToySky.uniforms` hands it (`ToyStarUniforms`). The
   shader is one pass with no loops and no neighbours: the pixel's cell, two hashes and one shape test.
5. **Docs.** [look-and-sound.md](../../design/look-and-sound.md) §3 has the `star` token, §4 the `ToyBackground`
   part, §6 the shader's line and a dated "Decided at step 12" block with the field's numbers.

## Files changed

- `packages/toy_look/lib/src/toy_stars.dart` (new, 261 lines) — `ToyStar`; the field's constants and their numbers;
  the shared float hash (`_hashOf`, `_hashPairOf`, `_spread`, `_fract`); `field`; `paint`; the sparkle's two-ellipse
  path; the twinkle's `bump`.
- `packages/toy_look/lib/src/toy_sky.dart` (218) — `wrapPx` is now `ToyStars.tilePx` (1024, was 64);
  `dotAlphaOf`; `ToyStarUniforms` and its `of`.
- `packages/toy_look/lib/src/toy_background.dart` (284) — the drift's `_time` notifier; the painter's `time` and
  merged repaint; `_paintCanvas` picking stars or dots; `_setStarUniforms`; `shouldRepaint` on time.
- `packages/toy_look/lib/src/toy_colors.dart` (186) — `hasStars` and `star` in the constructor, both palettes and
  their docs.
- `packages/toy_look/shaders/toy_backdrop.frag` (154) — `hashOf`, `hashPairOf`, `stars()` and its uniforms; the
  dot pass is unchanged and Sunny still draws it.
- `packages/toy_look/test/toy_stars_test.dart` (new, 232) — 13 tests (below).
- `packages/toy_look/test/night_sky_png_test.dart` (new, 170) — writes `docs/design/m13-night-sky.png`: two panels,
  the look's own fonts, Night at 700 ms of drift, and the same frame captured twice and compared byte for byte.
- `packages/toy_look/test/toy_background_test.dart` (302) — the painter's `time`; Night's uniforms no longer expect
  dots; the wrap test now uses the 1024 px tile (170.67 s at 6 px/s); the widget tests read the twinkle clock.
- `packages/toy_look/test/support/pixels.dart` (61) — `width`, `height`, `luminance` (Rec. 709) and `checksum`
  (FNV-1a) so a whole frame can be pinned and the brightest pixel found.
- `docs/design/look-and-sound.md` — the `star` token row, the `ToyBackground` part, the shader's line, and the
  "Decided at step 12 (Claude, Nov 9, 2026)" block.
- `docs/design/m13-night-sky.png` (new) — the picture.

`toy_still_sky.dart` and `toy_shaders.dart` are unchanged: a hold already stops the ticker, which is now the
twinkle's clock too.

## The star field's numbers

| | |
| --- | --- |
| Grid | 32 px cells, one star a cell (1 per 1024 px², about Sunny's dot density), field 32 × 32 cells |
| Tile | 1024 px both ways; the drift wraps there (6 px/s → 170.7 s) |
| Tiny point | radius 0.9 px, at most 0.2 alpha, white, no twinkle — 3 cells in 4 |
| Small dot | radius 1.7 px, at most 0.32 alpha, white, twinkles — 1 cell in 5 |
| Sparkle | arms 3.2 px long and 0.9 px wide (0.28 of the length), at most 0.45 alpha, `star` yellow, twinkles — 1 cell in 40 |
| Twinkle | 2, 3, 4 or 5 s a cycle from the cell's jitter seed, its own phase; dims to 60 % and grows 15 % |
| Brightest star | 0.45 over the glow `#3B2F8F` → red 0.45 × 255 + 0.55 × 59 = 147.2, so a pixel no brighter than 148 |
| Measured in one tile | 30 sparkles (2.9 %), 186 small dots (18.2 %), 808 tiny points (78.9 %) |
| Measured in the 300 × 300 test box | 77 tiny, 6 small and 1 sparkle blobs over the brightness threshold; 144 stars in the box's cells |

The sparkles come out at 2.9 % rather than the nominal 2.5 %: one per ~35 cells, about 186 × 186 px rather than
200 × 200. That is the fixed seed's own rate, not a rounding of the threshold — the hash itself is flat (a 40,000-
cell sample has 978 seeds under 0.025, 2.45 %).

## Test counts before and after

| Check | Before | After |
| --- | --- | --- |
| `look` | 111 | **125** |
| `puzzle` | 230 | 230 |
| `host` | 254 | 254 |
| `phone` | 435 | 435 |
| `format`, `analyze`, `tv` | pass | pass |

The 14 new look tests: 13 in `toy_stars_test.dart` and the picture test. `toy_background_test.dart`'s Night tests
changed their expectations rather than their count: Night's uniforms now carry no dots, the drift wraps at the
tile, and the widget tests check the twinkle clock (0 while held, 1 s and 2 s while drifting).

## What the tests compute

- `toy_stars_test.dart` — Sunny's Canvas frame is pinned at checksum 948082591; Night's fallback frame holds 77
  tiny, 6 small and 1 four-pointed blob (sparkles fill under half their square, points over half); the nearest-
  neighbour gaps vary by more than 8 px; two still frames are identical and a drifting one differs; the frame at a
  full tile of drift equals the first; no star's alpha leaves `[class alpha × 0.6, class alpha]`; every star stays
  inside its cell by its radius plus 0.5 px; the brightest pixel's red is ≤ 148; the field is deterministic; the
  shader declares exactly the uniforms the painter sets and carries the fallback's hash constants and margin; Sunny
  has no stars and Night does.
- The picture test pins the picture as repeatable: the same sky at the same 700 ms is byte-identical on a second
  capture, and the composed PNG is star-bright.

## The shader's cost

Per pixel, only when the sky has stars (Sunny returns after one uniform compare): one `floor` and one `mod` for
the cell and its place in the tile; two hashes — `hashPairOf` (3 `fract`, ~15 mults, ~12 adds) and `hashOf`
(2 `fract`, ~10 mults, ~10 adds); two class compares; for a small dot or a sparkle a twinkle (1 `floor`, 1 `fract`,
one `bump` of 2 clamps and ~8 mults); then one shape test: 1 `sqrt` + `smoothstep` + `mix` for a point, 2 `sqrt` +
`min` + `smoothstep` + `mix` for a sparkle. Roughly 50–80 float operations and at most two square roots a pixel,
no loops, no texture fetches, no neighbouring cells. The dot pass above it is unchanged.

## Self-check (review-rules part A)

1. **Every host setup.** The sky is the same `ToyBackground` in all of them and the change reads no host, round or
   route state: look 125, puzzle 230, host 254 and phone 435 pass, which cover a TV host, a phone host, a joined
   phone and an older peer.
2. **Kept state.** The twinkle's clock is the drift's own `_drift`: it starts when the sky drifts (effects on, no
   reduced motion, no hold), stops with the ticker keeping its place, and is disposed in `dispose`; with nothing
   going on it is zero, and `toy_background_test.dart` checks 0 while held and 1 s / 2 s while drifting, with
   `toy_stars_test.dart`'s still-frame test.
3. **Combining with other states.** The twinkle has no condition of its own: it shares `_drifts` with the drift, so
   pause, away, "Get ready", results and leaving hold or release both together; controller_app's and party_host's
   `sky_holds_test.dart` still pass unchanged.
4. **Job folder.** Every file touched is in `allow:` (the report lists them). `tools/check.sh` rewrote four design
   PNGs and three `tv_test_app/windows/flutter` generated files; I put those back to HEAD, and the check's output
   is the only reason they moved.
5. **Stopping.** Nothing needed stopping; the two deviations from the letter are Q1 (float rounding between the two
   draws) and Q2 (the drift's wrap), both below.

## Questions and suggestions

1. **The two draws agree to rounding, not exactly.** SkSL (the impellerc target) rejects integer bit operations —
   `&`, `^`, `>>` all fail to compile — so the hash has to be a float recipe, and Dart's doubles and the shader's
   32-bit floats round it slightly differently. Expect the same star within ~0.001 px, and about one class seed in
   ten thousand landing on the other side of a size boundary between the shader and the fallback. No two devices
   ever draw both, so I took this as "the same field"; say if you want it exact (it would mean quantising the hash
   to a coarse grid, which costs uniformity).
2. **The drift's wrap moved from 64 px to 1024 px** (the star tile), so the pattern repeats every 170.7 s instead
   of 10.7 s. The speed is unchanged; the old wrap would have made the stars jump at the seam. Only toy_look's own
   tests referred to the 64.
3. **Sparkle density measured 2.9 %, not 2.5 %** (see above). If you want exactly one per 200 × 200 px, the
   threshold wants trimming; I left `sparkleEvery = 40` as the design's number.
4. **The picture's cards are a stand-in.** The picker's `_GameCard` and its drawn pictures live in `party_host`,
   which `toy_look` may not import, so the picture draws the picker's proportions with a plain toy plate where the
   game's picture goes.
5. **Suggestion:** `ToyStars` is not exported from `toy_look.dart` (its tests import the `src` file). Export it if a
   later job wants the field — a celebration's confetti of stars, say — rather than copying the numbers.

## Commit message

```
Make Night's sky a starry field of three sizes that twinkles

Night's polka dots become stars: a jittered 32 px grid, one star a cell,
a tiny white point, a small dot, or a pale yellow four-pointed sparkle
(one cell in forty). Each small one and sparkle has its own 2-5 s twinkle
that only dims, on the drift's clock, so a held sky holds its stars.

The backdrop shader draws the same field per pixel from the same float
hash as the Canvas fallback, and the drift now wraps at the field's
1024 px tile so the stars never jump.
```

## Status row

M13 12 (a starry Night sky): **done** — Night draws a three-size star field with four-pointed sparkles that twinkle
on the drift's clock, from the shader and the Canvas fallback alike; Sunny's frame is pinned unchanged; look
111 → 125 tests; picture `docs/design/m13-night-sky.png`; open: Q1 (rounding between the two draws), Q2 (the wrap),
Q3 (2.9 % sparkles).

## Delete

- Nothing: this job left no scratch files.

## Claude's review

Accepted. Applied by hand: the job's "outside allow" files were only pictures the suite redraws (`m12-mirror-*`, `m13-portrait-hud`) and the Windows plugin files, all left out. `m13-night-sky.png` reads as a starry night (tiny points, small dots, pale-yellow sparkles) and the picker's cards stay as clear as before. Checks on m13 with s21 and s19b in: look 126, arena 69, puzzle 252, host 268, phone 438, tv pass. The shader stays one pass, no loops.
- Q1 (shader and fallback agree to rounding): fine; no device draws both.
- Q2 (drift wraps at 1024 px): right; it removes the seam jump.
- Q3 (sparkles 2.9 %, not 2.5 %): keep.
- The stars are on the faint side by design (brightest 0.45). The owner judges them on the iPad; brighter is a one-number change in `toy_stars.dart`.
