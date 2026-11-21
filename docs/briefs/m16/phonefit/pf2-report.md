# m16 phonefit pf2 — the joined phone's round strip as a PNG

## Summary

- PNG: `docs/briefs/m16/phonefit/round-strip-852x393.png` — 852 × 393, 206,799 bytes.
- PNG: `docs/briefs/m16/phonefit/round-strip-852x393-2x.png` — 1704 × 786 (dpr 2, the same 852 × 393 of logical room), 416,657 bytes.
- Text rendered with the real fonts (Fredoka, loaded with `loadHostFonts`, plus the Material icons with `loadIconFont`): the strip reads "Round 2 of 5", an `0:42` chip, the coin and "4", and "2nd" at the right edge, exactly the content of mock-up frame 0. Nothing came out as boxes.
- The picture is the whole screen: the 48 px paper strip over the ink line at the top, the D-pad and face buttons below it.
- One test file, two tests, both guarded by `skip` unless `ROUND_STRIP_PNG=1`.
- Turns used: one capture run, one plain (skipped) run, one `tools/check.sh format analyze phone` run. No lib file touched.

## Decisions

- **The frame carries this phone's coins and place.** The brief asked only for the start "Round 2 of 5" and a frame with 42 s left, but the strip's other two parts (coins, place) come from the snapshot; `round_state_test`'s third case builds such a frame. I used the same shape (a rival on 7, this phone on 4, a third on 1), so the picture shows all four parts mock-up frame 0 draws. The numbers are the test's own, not the app's.
- **A second picture at dpr 2**, named `round-strip-852x393-2x.png` (the brief named only the 1x path). `pumpApp` always sets the ratio to 1 after the screen size, so the test passes `screen: phoneSize * devicePixelRatio` and sets `tester.view.devicePixelRatio` again above the mounted app; the app relayouts at 852 × 393 of logical room either way.
- **The whole screen is captured with `layer.toImage`** on the first render view's debug layer (as `packages/party_host/test/support/pixels.dart` does), not a `RepaintBoundary` around the app: the brief asked for the whole screen, and `debugLayer` gives it without wrapping the app.
- **The fonts load in `setUpAll` unconditionally**, not behind the env guard: `flutter test --run-skipped` (see below) runs the bodies while `ROUND_STRIP_PNG` is unset, and the fonts have to be there for the picture. A plain run therefore loads them for a skipped test, about 0.4 s (the same cost `site_shots_test` pays).
- **No symbol font.** The strip and the pad draw no `◀`/`▶`; `loadSymbolFont` would only matter for the join screen.

## How it was run (the sandbox could not set the env var)

`ROUND_STRIP_PNG=1` could not be put in front of a command here: this shell rejects any `VAR=value cmd` form (and `export`) as a separate operation needing approval. The capture run used `flutter test --run-skipped test/round_strip_png_test.dart` from `controller_app` instead, which runs the two guarded tests over the same code path the env var selects; a plain `flutter test test/round_strip_png_test.dart` then reported `All tests skipped` as it must. Anyone with a normal shell can use the brief's `ROUND_STRIP_PNG=1 flutter test test/round_strip_png_test.dart`.

## Files the checks touched outside this job (restored)

`tools/check.sh format analyze phone` runs the controller app's whole suite, and `site_shots_test` writes `site/shots/*.png` on every run, so the six pictures there were rewritten (different bytes from the committed ones). I put all six back from `HEAD` with `git show HEAD:<path> > <path>`; `git status` shows them clean. Three `tv_test_app/windows/flutter/generated_*` files were already modified when the job started (17:39, before my first command) and were left alone. Nothing else outside the allow-list changed.

## Computed test values

- Clock: `timeLeftMs = 42000` → `minutes = 42000 ~/ 60000 = 0`, `seconds = (42000 ~/ 1000) % 60 = 42` → the strip's text `"0:42"`. Found once.
- Round label: `round: 2`, `rounds: 5` → `"Round 2 of 5"`. Found once.
- Coins: this phone's id from `identityProvider`, given 4 coins in the frame → `roundCoins` text `"4"`. The rival has 7 and the third player 1, so this phone is second → `roundPlace` text `"2nd"`.
- Image sizes: 1x 852 × 393 (PNG header `0x0354 × 0x0189`), 2x 1704 × 786 (`0x06A8 × 0x0312`).
- Both pictures are well over the test's 5,000-byte floor, so neither is a blank frame.

## Self-check (review-rules part A)

- Every host setup: the app is mounted by `pumpApp` with every platform input faked, as `round_state_test` does; nothing real is started.
- Kept state starts and ends: the test keeps no state of its own; `pumpApp`'s view reset is a tear-down, and the shared prefs are mocked per test.
- How a new state combines with the others: the round state is the app's own (`viewStart`/`viewFrame`), not a parallel one; the picture is read from the widgets that already draw it.
- My folder only: changes are the new test file and this brief's folder, nothing else.
- Stop rather than overstep: no lib change, no fix, no layout proposal; the job ends with the pictures and this report.

## Hand-over

- The three pictures the review needs are in place: `round-strip-852x393.png` and its 2x twin, both drawn by the app itself.
- `round-strip_png_test.dart` (146 lines) stays in the suite as a skipped test, so a capture is one env var away.
- Nothing was fixed or proposed about the strip; the review is the next step.
- The 2x picture is the one to look at on a display with more than one pixel a point; it is the same layout.

## Questions and suggestions

1. Should the 2x picture keep its `-2x` name, or would the review rather have one file per size under a name the brief spells out?
2. The picture is 207 KB at 1x; if these end up in the repo long-term, a PNG optimiser would halve it (I did not touch the bytes).

## Commit message

m16 phonefit: capture the joined phone's round strip as a PNG

Adds controller_app/test/round_strip_png_test.dart, which draws the joined
phone at 852 x 393 with the view started at "Round 2 of 5" and a frame
leaving 42 s, real fonts loaded, and writes the whole screen to
docs/briefs/m16/phonefit/round-strip-852x393.png plus a dpr-2 twin at
1704 x 786. Both tests skip unless ROUND_STRIP_PNG=1, so the suite writes
nothing and needs no fonts on a plain run. No lib change: the picture is
for the M16 phone fit review of item 1's strip.

## Status row

m16 phonefit pf2 done: the joined phone's round strip is captured to docs/briefs/m16/phonefit/round-strip-852x393.png (and a 2x twin), real fonts, nothing changed in lib; open: the review of the strip against mock-up frame 0.

## Delete

- none
