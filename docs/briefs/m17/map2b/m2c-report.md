# map2b m2c report

## Files
- `city/art/city_map_view.dart` (new): `CityMapView`, owns a `CityStaticCache`, layout kept while size/board/rules are the same, base painter plus overlay in a `RepaintBoundary`; consts `cityMinTokenDiameterDp` (24) and `cityChipMinTileSize` (20, see question 1).
- `city/art/city_overlay_painter.dart`: optional `minTokenDiameter` (default 0), public `tokenRadius` getter = max(tile*share, min/2), in `shouldRepaint`.
- `test/city/art/city_map_view_test.dart` (new): 5 sizes x 2/4/8 players x both looks, no exception; non-vacuous overflow case; phone token floor; chips dropped on phone / shown on TV; cache builds once per size.

## Computed values
- 360x640, 8 players: tileSize 17.41 dp, so the share radius is 5.57 dp and the floor lifts it to 12 dp.
- Badge numbers at 8 players: 2 (slots 6 and 7).
- Chips at 1920x1080, 8 players: 8; cache buildCount 1 per size, 2 after one size change.

## Questions
1. The brief's `cityChipMinTileSize` of 14 contradicts its own test: at 360x640 with 8 players the tile is 17.4 dp, so chips would stay. I raised the const to 20 so the stated outcome holds. Please confirm or give another number.
2. Tests use `pumpHostLook`, so the view sits inside the host frame harness; the layout size is asserted equal to the view size.

## Commit message
map2b: CityMapView fits phone and TV, token floor

Adds CityMapView (cached static map plus overlay, layout kept per
size/board/rules). CityOverlayPainter gets minTokenDiameter so tokens stay
at least 24 dp on a phone; Bolts chips are dropped on tiles under 20 dp.
Tests cover 5 sizes, 2/4/8 players, both looks, and the cache.

## Status row
m2c done: CityMapView with phone token floor and chip density; open: chip threshold 20 vs brief's 14 needs confirming, not wired into any screen.

## Delete
- none
