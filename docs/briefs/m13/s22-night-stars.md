job: M13 12: a starry Night sky (owner, Nov 9, 2026: "In night mode, have the background look more like stars")
pub: no
stop: after it.
read: packages/toy_look/lib/src/toy_background.dart (the sky: the palette's background, a lighter centre, white polka dots that drift; the shader path and the Canvas fallback), toy_sky.dart, toy_still_sky.dart, toy_colors.dart (`dotAlpha`, Night's colours), shaders/toy_backdrop.frag, toy_shaders.dart · docs/design/look-and-sound.md sections 4 and 6 (the sky, the drift, effects off and reduced motion = still) · the toy_look tests · docs/review-rules.md · docs/coding-guidelines.md

Claude's design:
1. **Night's sky is a starry night; Sunny's is unchanged.** In Night, the polka dots become stars: a scattered field, not a grid, of three sizes — many tiny points, some small dots, and a few (about one per 200 × 200 px) four-pointed sparkle stars in the toy style (soft, rounded points, no ink edge). White and the palette's pale yellow, faint enough that cards, text and the game read as clearly as on today's Night sky (the brightest star no stronger than about 0.5 alpha; the tiny ones about 0.2). Keep the soft lighter centre.
2. **It twinkles while the sky moves.** With effects on and no reduced motion and nothing holding the sky still (the same rule as the drift), each sparkle star and some small ones slowly twinkle (alpha and a little size, 2–5 s per cycle, each at its own phase), and the field drifts as the dots do. Held still (a round's screens, effects off, reduced motion), it's a still starry sky, never blank.
3. **Deterministic and seamless**: the stars come from a fixed seed, tile without a visible seam as they drift, and don't bunch or leave large gaps (a jittered grid is fine).
4. **Both paths**: the backdrop shader draws the stars on devices that load it, and the Canvas fallback draws the same field (the same positions, sizes and twinkle) where it doesn't, as the dots do today. Keep the shader cheap: one pass, no loops over hundreds of stars per pixel (a jittered cell grid looked up per pixel is the usual way).
5. Design sections 4 and 6: Night's sky is stars (owner, Nov 9).

tests (each failing first):
- Night's fallback sky draws stars: off a rendered frame, points of three sizes, not on a regular grid (the gaps between neighbours vary), and some four-pointed ones; Sunny's sky renders exactly as before (pin it).
- Still (effects off): two frames a second apart are identical; moving: they differ (twinkle and drift).
- The stars tile: the frame at a full tile's drift equals the first.
- The brightest star pixel is no more than the alpha set in rule 1 over the background.
- The shader compiles (the existing shader test) and takes the same uniforms the Dart side sets.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit).
- Pictures: `docs/design/m13-night-sky.png`, the Night sky alone and behind the game picker's cards (fallback path), deterministic.

in the report: test counts before and after; the files changed; the star field's numbers (sizes, density, alphas, twinkle periods); the shader's cost (its per-pixel work).
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · in toy_look touch only the sky's files (toy_background.dart, toy_sky.dart, toy_still_sky.dart, a new star file, shaders/toy_backdrop.frag, toy_shaders.dart, toy_colors.dart for any star colour) — another job works on the focus look.
allow: docs/briefs/m13/s22-night-stars-report.md · docs/design/look-and-sound.md · docs/design/m13-night-sky.png · packages/toy_look/lib/src/toy_background.dart · packages/toy_look/lib/src/toy_sky.dart · packages/toy_look/lib/src/toy_still_sky.dart · packages/toy_look/lib/src/toy_stars.dart · packages/toy_look/lib/src/toy_shaders.dart · packages/toy_look/lib/src/toy_colors.dart · packages/toy_look/shaders/toy_backdrop.frag · packages/toy_look/test
check: format analyze look puzzle host phone tv
report: docs/briefs/m13/s22-night-stars-report.md
