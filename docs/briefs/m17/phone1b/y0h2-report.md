# y0h2 report: "Try the shop" at 48 dp, _PickerBody parameters, stale comment

## Summary

- The shop button (`openShopDemo`) is now at least 48 dp tall at every tested size, menu and TV. Its minimum height is 48 / frame scale frame px, so it scales with the frame and a TV keeps its own look height.
- The card height went from 340 to 294 frame px and the picture from 186 to 140. The owner must be told the card heights changed.
- `_PickerBody` now takes three parameters. The three game callbacks and `onShop` are grouped in `_PickerActions` (same file).
- The stale "387 px" comment is rewritten with the real sums.
- The six `openShopDemo` entries are removed from `knownBelow48Host` in `touch_targets_host_test.dart`. The test fails if an entry stays after its target reaches 48 dp, so removing them is what it demands.

### Arithmetic (frame px; the body is 392 px at 568x320 and 640x360)

- Scale `s = min(W/960, H/540)`. A 48 dp button is 48 / s frame px:
  - 568x320: s = 0.5917, so 81.13 px. Real size 81.13 x 0.5917 = 48.0 dp.
  - 640x360: s = 0.6667, so 72 px. Real size 72 x 0.6667 = 48.0 dp.
  - 375x667: s = 0.3906, so 122.9 px. The body is far taller than 392 on a phone taller than 16:9 (the frame is 960 x 1707), so it fits.
  - TV 1920x1080: s = 2, so 24 px. The look's own 64 px (TV) is larger, so the TV button is unchanged.
- Fit at the tightest 16:9 size, 568x320: cards 294 + gap 16 + button 81.13 = 391.13 against a 392 body (0.87 spare).
- Fit at 640x360: 294 + 16 + 72 = 382 against 392.
- Picture: the card's non-picture stack is 146 px (title 40, line 2 x 31, gaps, padding 12, focus ring 4) plus 8 px spare. So the picture is 294 - 8 - 146 = 140.

### Checks

- `tools/mine.sh`: format, analyze and touched tests all OK (run twice; the first run failed on a missing import of `host_frame.dart` and on the scale lookup outside a frame, both fixed).
- `flutter test` from packages/party_host, the four files named in the brief: `touch_targets_host_test.dart`, `games_screen_frame_test.dart`, `screen_fit_test.dart`, `phone_fit_picker_join_test.dart`: 83 tests, all passed.
- `flutter test test/games_screen_test.dart`: 3 tests, all passed. It reads `gamePictureHeightPx` by name, so no pin needed updating.
- Not run: `tv_test_app/test/home_screen_test.dart` (in `allow:`, not required by the brief).

## Decisions

- Scale-aware minimum (`shopButtonMinDp / scale`) rather than a fixed 123 px button. A fixed height would make the TV button 123 px tall. Measured on the TV, a 48 px button at scale 2 is only 24 frame px, so the look's 64 px already exceeds it.
- Outside a `HostFrame` the scale is taken as 1 (device px are the layout px). Several tests and at least one screen path draw the picker with no frame; `HostFrameInfo.of` threw there.
- `_PickerActions` is private to `games_screen_widgets.dart` (a part file) and is not a new public type.

## Questions

1. The owner must accept the card change: cards 340 to 294 and picture 186 to 140. Without it, the 48 dp button does not fit the 392 body at 568x320.
2. A 16:9 device smaller than 568x320 (for example 480x270, scale 0.5) would need a 96 px button, and cards 294 + 16 + 96 = 406 is over the 392 body. The picker then scrolls, which the comments call the unreachable safety net. Not tested; the brief does not list that size.

## Suggestions

- Add a `tv_test_app` or a phone size below 568x320 to the touch-target test, to pin question 2.

## Hand-over

Files changed:
- `packages/party_host/lib/src/ui/games_screen_widgets.dart`: card 294, picture 140, shop button minimum by scale, `_PickerActions`, `_PickerBody` at 3 parameters, arithmetic in the doc comments.
- `packages/party_host/lib/src/ui/games_screen.dart`: passes `_PickerActions`; imports `host_frame.dart`.
- `packages/party_host/test/touch_targets_host_test.dart`: six `openShopDemo` entries removed from `knownBelow48Host`.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
phone1b y0h2: shop button 48 dp, picker params, comment sums

The "Try the shop" button was 18.8 to 42.7 dp tall on phones, below the
48 dp touch-target rule. Its minimum height is now 48 / frame scale, so
it is 48 dp at every tested size and keeps the look's height on a TV.
To fit it in the 392 px body the game cards shrink from 340 to 294 px
and the pictures from 186 to 140 px; the owner must accept that.
_PickerBody takes the four callbacks as one _PickerActions value (three
parameters), and the 387 px comment states the real 391.1 px sum.
The six openShopDemo entries leave knownBelow48Host.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

phone1b y0h2: shop button is 48 dp at all tested phone and TV sizes (scale-aware minimum), cards 294 / pictures 140 (owner to accept), _PickerBody at 3 parameters; open: the owner's answer on the card change, and 16:9 sizes below 568x320 are untested.

## Delete

- none
