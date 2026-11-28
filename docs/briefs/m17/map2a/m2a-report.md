## Summary

Static 2.5D City Rush map: pure layout geometry, a painter, and a once-per-size image cache. Nothing is wired into a game or menu; no rule or tuning change.

- `city_layout.dart`: `CityLayout.compute` puts the Centre Plaza in the middle and each district on a spoke: corner `i` on spoke `2i`, its lane on spoke `2i+1`, so corners sit on the diagonals and lanes on the axes. `tileCenter`, `tileRect`, `plazaCenter`, `tileSize`, `districtRect`. Road length comes from `rules.roadLength`.
- `city_painter.dart`: `CityPainter` draws district strips, lanes, tiles with a side face (2.5D, `toyShape`, `look.shade` or the fallback when null) and the Plaza. `CityStaticCache` renders the layer once per size (PictureRecorder, picture disposed at once, `toImage`) and exposes `buildCount`.
- Test file: 29 tests, all passing in `tools/mine.sh` (layout 21 = 7 player counts x 3 sizes, plus road length x2; cache 3; screen 3 sizes x both looks).

Test values computed: none numeric; the expectations are counts (`buildCount` 1, then 2 after a size change; one `drawImage` and nothing else on a cached frame).

### Decisions
- The Plaza is the last tile of every road (index `roadLength-1`) and returns `plazaCenter`, so "no overlap" and "distinct centres" cover the road tiles only.
- The first frame of a size draws the layer directly and requests the image, so there is never a blank frame. Later frames only `drawImage`.
- Cache is keyed on `layout.size`, at logical pixels (no devicePixelRatio scaling); fine on TV 1920x1080, slightly soft on a high-DPI phone.
- The painter takes a `ToyLook`: colours from `look.colors`, outline from `look.sizes`, shader `look.shade`.
- A real shader can't be loaded in tests, so only the fallback (`shade == null`) is proven.
- `CityPainter` plaza is drawn 1.25x a tile; it can touch the nearest road tile diagonally (not covered by a test).

### Self-check (review-rules part A)
1. Host setups: not applicable, no screen or host wiring.
2. Kept state: the cache lives as long as its owner and is disposed by it; nothing going on means no build (test: builds once per size).
3. Pause, away, results and the like: not applicable, not wired.
4. Only the allowed files were changed.
5. Nothing needed outside `allow:`.
6. Every look: "paints under every look" test, menu and TV, at 1920x1080, 360x640 and 640x360; tile size comes from the layout, no fixed pixel height.

## Hand-over
Job m2b can add tokens, gate and cone on top: `CityLayout.tileCenter` and `tileSize` are the anchors. The owner should check the look on a device.

## Commit message

map2a: static 2.5D city painter with image cache

CityLayout.compute lays corner and lane roads out on spokes round the
Centre Plaza; CityPainter draws them in the toy look; CityStaticCache
renders the static layer once per size to a ui.Image. Not wired into
any screen yet.

## Status row

map2a m2a: static city layout, painter and image cache done and tested (29 tests); open: tokens, gate, cone and Bolts (m2b), wiring into a screen, device look check.

## Delete

- none
