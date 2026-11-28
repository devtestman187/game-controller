# map2a m2b report: dynamic layer over the cached map

## Summary

Added the dynamic layer of the City Rush board: a pure scene model, token and label drawing, and an overlay painter that paints one scene over the static map. Nothing is wired into a game or menu; `city_layout.dart`, `city_painter.dart`, `board.dart` and `rules.dart` are unchanged, and nothing imports `night/`.

- Test run: `tools/mine.sh` → `OK 34 tests packages/party_host`, format and analyze clean (5 files formatted, 1 package analyzed).
- Tests fail on an empty stub by construction is not claimed: the five files are new, so the tests-first rule is exempt for them.
- Line counts: `city_scene.dart` 216, `city_tokens.dart` 69, `city_overlay_painter.dart` 127, `city_scene_test.dart` 187, `city_overlay_painter_test.dart` 219 (all under 380).

## Files changed

- `packages/party_host/lib/src/city/art/city_scene.dart` (new): `CitySnapshot`, `CityRoadScene`, `CityTokenScene`, `CityGateScene`, `CityChipScene`, `CityScene` and `CityScene.from(snapshot, layout)`, plus the constants `cityChipSpacingTiles`, `cityChipDropTiles`, `cityConeRiseTiles`, `cityColouredSlots`.
- `packages/party_host/lib/src/city/art/city_tokens.dart` (new): `cityTokenColour`, `cityShapeStyleOf`, `paintCityDisc`, `paintCityLabel`, and the share constants for token, gate, cone, chip and absent dimming.
- `packages/party_host/lib/src/city/art/city_overlay_painter.dart` (new): `CityOverlayPainter`, which paints built tiles, a complete road, the gate, the cone, tokens with badges, and Bolts chips, in that order.
- `packages/party_host/test/city/art/city_scene_test.dart` (new): scene table tests (empty board, mid-night, gate shut and open, roadworks, complete road, clamping, 8 players, late joiner, determinism, chips off).
- `packages/party_host/test/city/art/city_overlay_painter_test.dart` (new): one painter test per layer at TV (1920×1080) and phone portrait (360×640) sizes, plus the colour rules and `shouldRepaint`.

## Computed values used in expectations

- Standard rules: `roadLength` 6, so a road has 5 buildable tiles before the Plaza; `complete` is `builtTiles >= 5`.
- Built-tile painting: 3 built tiles → 3 side faces (`drawRRect`) and 9 `drawPath`; 6 built → 5 faces and 15 paths (Plaza skipped).
- Complete road: 5 built open → 15 `drawPath`; complete → 16 (one stroke added).
- Each `toyShape` disc, cone, gate and chip → 3 `drawPath` (shadow, body, outline; the fallback body path is used because `shade` is null in tests).
- Badged token → one extra `drawParagraph`; 8 tokens → 24 `drawPath` and 2 labels (badges 7 and 8).
- 2 chips → 6 `drawPath` and 2 labels.
- Chip row spacing: `tileSize × 1.1`; row drop: `tileSize × 1.0` below the Plaza centre; the test checks the two chips sit at ±½ spacing.
- Absent dimming: `cityAbsentMix` 0.6 toward `look.colors.board`, checked with `Color.lerp`.
- Colour slots: good, focus, caution, bad, faceX, ink (six distinct in Sunny); slots 6 and 7 use the tray colour with badge numbers 7 and 8.

## Decisions

- `CityRoadScene.builtTiles` is clamped to `0..roadLength` as the brief says. The painter draws at most `roadLength - 1` slabs, because the Plaza is never built on. `complete` means every tile before the Plaza is built.
- The sixth player colour is `look.colors.ink`. In Sunny, `faceA`, `faceB` and `faceY` repeat `good`, `bad` and `focus`, so there were only five distinct colours. The first test run caught this (4 distinct colours) and I fixed it.
- The gate marker is a disc coloured good when open and bad when shut. The gate's `kind` is left out of `CityGateScene` because the painter does not use it.
- Chips sit in one row under the Plaza, not on each player's tile. A chip is painted in paper colour with no player colour.
- The roadworks cone is a triangle above the Plaza.
- The painter takes a `CityScene` (not a `CitySnapshot`), so `shouldRepaint` compares scene identity; a new scene each frame repaints.
- No Bolts chip is shown when `bolts` is null. A player with a token but no Bolts entry gets a chip showing 0.

## Hand-over

Questions:
1. Should the sixth colour be `ink`? It is dark and may vanish on the Night palette; please confirm or give a distinct colour.
2. Should `builtTiles` be clamped to `roadLength - 1` rather than `roadLength`? The brief says `roadLength`, which I followed; the painter guards the Plaza either way.
3. Should chips sit under the Plaza (as built) or on each player's road? Under the Plaza is my reading of "Bolts chips" with no placement in the brief.
4. `CityScene.from` throws `RangeError`/`ArgumentError` (from `tileCenter`) when a token is off its road. Is that the right behaviour, or should it skip the token?

Suggestions:
- The painter test duplicates the board builder and counting canvas from `city_painter_test.dart`; a shared test support file would remove the copy once a third user exists.

## Commit message — a draft

map2a m2b: dynamic layer over the cached city map

Add the City Rush dynamic layer: CityScene.from turns a CitySnapshot
(built tiles, tokens, gate, roadworks, Bolts) into a pure scene, and
CityOverlayPainter paints it over the static map. Tokens beyond six
players get number badges. Absent players are dimmed. Nothing is wired
into a game or menu; layout, board and rules are unchanged.

## Status row

map2a m2b done: dynamic layer (scene model, tokens, gate, cone, Bolts chips, overlay painter) with 34 tests passing. Open: wiring into a game or menu (not in this job); sixth player colour is `ink` (owner to confirm); chip placement and clamp reading (see questions).

## Delete

- none
