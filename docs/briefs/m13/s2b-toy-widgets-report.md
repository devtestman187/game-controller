# M13 step 2b — the look's widgets: report

The four widgets every menu will be built from, in `packages/toy_look`, with tests. Nothing else adopts them: the only place they appear in an app is the new gallery on the TV app's Look test screen (its second tab, beside the shader rows, which are unchanged).

## Files changed

Package `packages/toy_look`:

- `lib/src/toy_sizes.dart` — `buttonHeight` on the two instances: 48 on a menu (the touch-target minimum) and 64 on a TV (design section 4); the class doc now says the instances differ in the outline's width and the button's height.
- `lib/src/toy_colors.dart` — `dotAlpha`: 0.22 Sunny, 0.07 Night (design section 4), documented on the field.
- `lib/src/sticker_shadow.dart` — new, not exported: `paintStickerShadow(canvas, shape, ink, {offset})`, the shape's path moved by `ToySizes.shadowOffset` and filled with ink at `toyShadowAlpha` (0.35) — the hard shadow every widget uses, so no widget makes its own.
- `lib/src/toy_button.dart` — new, 351 lines: `ToyButton` (label, onPressed, color, icon, focusNode, autofocus, showFocus) and its public `ToyButtonPainter`. A pill in `color ?? colors.good` with an ink edge, the sticker shadow, the label and optional icon in `type.button` ink, height `sizes.buttonHeight`, padding `space24`. Pressed loses the shadow and moves the face `shadowOffset` down-right; focused draws a `focusRing`-wide focus band with its own 1.5 px ink edge and bounces 1 → 1.06 → 1.04 over 220 ms (1.04 at once with effects off, nothing with `showFocus` false); disabled is paper with a dashed 6-on-4 edge, no shadow, not focusable, taps ignored. Activation is the framework's `ActivateIntent` through `FocusableActionDetector` (Enter, Space, Select and the gamepad's A all map to it), and a held key keeps the button pressed until the key-up.
- `lib/src/toy_card.dart` — new, 170 lines: `ToyCard` (child, header, headerColor, padding = `space16`, popIn). Paper, ink edge `sizes.outlineWidth`, the sticker shadow, `sizes.cardCorner` corners with a clip so the band follows them; an optional band in `headerColor ?? colors.focus` with `type.button` ink and an ink line under it; a `Theme` (body/display colours and the ListTile's text and icon colours ink) and a `DefaultTextStyle.merge` in ink, so what the card holds reads on paper; pop-in 0.9 → 1.0 with `Curves.easeOutBack` over 180 ms when `popIn` and `look.effects`.
- `lib/src/toy_badge.dart` — new, 101 lines: `paintToyBadge(canvas, centre, diameter, number, look)` — player colour disc, ink edge `max(diameter / 14, 2)`, shadow scaled with the diameter (`shadowOffset * diameter / 40`), the number in Fredoka at `diameter * 0.55` in ink — and the widget `ToyBadge({number, diameter = 40})` that paints it and says "Player n" to a screen reader.
- `lib/src/toy_background.dart` — new, 79 lines: `ToyBackground({child})` = a `RepaintBoundary` round `ToyBackgroundPainter`, which paints `colors.background`, a radial glow to `colors.backgroundGlow` and white dots at `colors.dotAlpha` on a staggered 32 px grid (radius 3, odd rows 16 along). `shouldRepaint` is true only for another look. It's still; nothing animates.
- `lib/toy_look.dart` — exports the four widget files (alphabetical), and the library doc says the package now has "the widgets every menu is built from".
- `test/toy_look_test.dart` — the sizes test also checks `buttonHeight` 48 and 64.
- `test/toy_button_test.dart`, `test/toy_card_test.dart`, `test/toy_badge_test.dart`, `test/toy_background_test.dart` — new, 13 + 5 + 2 + 3 tests.

TV app:

- `lib/src/ui/toy_gallery.dart` — new, 168 lines: `ToyGallery`, a `ListView` over a `ToyBackground` under a `ToyLookScope` and `Theme(toyTheme(...))` it builds itself from `ToyLook.build(palette: …, tv: true)`; a Sunny/Night `Switch` (`Key('galleryPalette')`), four buttons (normal with an icon, autofocused, disabled, `colors.caution`), a card (header "Player 2", a line of text and a ListTile), badges 1 to 6, and one line in each of the four `ToyType` styles.
- `lib/src/ui/shader_spike_screen.dart` — `TickerProviderStateMixin`, a two-tab `TabController` disposed with the screen, a `TabBar` (`Shapes`, `Widgets`) in the app bar and a `TabBarView` holding the old `ListView` and the gallery. The rows, the frame time and the Stress button are unchanged (222 lines).
- `test/toy_gallery_test.dart` — new, 3 tests.

No other file was edited. `git status` also lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc/.h` and `generated_plugins.cmake` as modified; `git diff` on them is empty — running `flutter test` / `pub get` rewrote them with LF endings. I didn't touch them and can't restore them without a git command.

## Test counts

| | before | after |
| --- | --- | --- |
| `packages/toy_look` | 50 | 73 (+23: 13 button, 5 card, 2 badge, 3 background) |
| `tv_test_app` | 32 (+1 skipped) | 35 (+1 skipped: 3 gallery) |

## The values I computed for the tests

Button (a menu look, box 160 × 48, and 160 × 60 when a pixel under the pill is read):

- The pill is inset `outlineWidth / 2 + focusRing + 1.5 / 2` = 6.25 (menu) and 6.75 (TV), so its bottom edge is at 41.75; its ink edge reaches 43.25 and its shadow, moved (3, 4) and filled with ink at 35 %, reaches 46.75. At (80, 44) the white shows 0.35 · (30, 22, 70) + 0.65 · 255 = (176.3, 173.5, 190.3) → asserted (176, 173, 190). Pressed, the face moves 4 down: (80, 46) is the ink edge (30, 22, 70) and (80, 49) is white — no shadow below anymore.
- Focus ring: the band's own ink edge is at 0.75 from the top (6.25 − 4 − 1.5/2), so (80, 0) is ink (30, 22, 70) and (80, 3) is the focus colour (255, 210, 63); unfocused, (80, 3) is white.
- Disabled: paper (255, 246, 227) at (80, 24), white at (80, 44), and the top edge's ink comes and goes (more than two runs of colour from x 60 to 100 at y 6).
- Bounce: 1.0 on the first frame, 1.06 at 110 ms (half of 220 ms), 1.04 once settled; with effects off 1.04 on the first frame and no frame scheduled; `showFocus` false leaves it at 1.0.
- Heights: 48 on a menu, 64 on a TV.

Card: pop-in scale 0.9 on the first frame and 1.0 after 180 ms (read from the transform's x entry — `getMaxScaleOnAxis` also reads the z axis, which is always 1, so it can never report a scale below 1).

Badge (200 × 200 canvas, centre (100, 100), diameter 80, number 2): inside the disc above the number, (100, 75) = player 2's orange (255, 138, 31); the edge is ink (30, 22, 70) at 80 / 14 = 5.71 wide, so (140, 100) is ink; the shadow is the disc moved (6, 8) — 80 / 40 · (3, 4) — so (136, 126) is 0.35 · (30, 22, 70) + 0.65 · 255 = (176, 173, 190).

Background (300 × 300, Sunny): the centre is `backgroundGlow` (196, 234, 255), read with a ±1 tolerance because the gradient rounds; the glow's radius is 0.375 of the longer side = 112.5, so the far corner (208.6 away) is the plain background (124, 200, 248). A dot at (48, 32) is white at 22 % over (124, 200, 248) = (152.8, 212.1, 249.5) → asserted ±2; Night's is 0.07 · 255 + 0.93 · (36, 28, 94) = (51.3, 43.9, 105.3) → ±2.

Gallery (960 × 540): ToyBackground ×1, ToyButton ×4, ToyCard ×1, ToyBadge ×6, no exception and no overflow, in Sunny and in Night; the switch changes `colors.background` from (124, 200, 248) to (36, 28, 94). The gallery is taller than a TV's section, so the test scrolls down to the badges and back; the badge row carries `Key('galleryBadges')` so the test can scroll to it.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** Not wired into a host yet: the widgets draw whatever look a `ToyLookScope` gives them, and the tests mount them with a menu look and a TV look (`the button is 48 px on a menu and 64 on a TV`, the gallery test at 960 × 540). A joined phone, a phone on either mode and a peer one build older are not affected (no protocol, no app screen but the Look test screen changed).
2. **When kept state starts and ends.** `ToyCard`'s pop-in starts in `didChangeDependencies`, only when `popIn` and `look.effects`, runs 180 ms and is disposed with the state (`a card pops in from 0.9 to 1.0 in 180 ms`, `with effects off or popIn false it appears at 1.0 at once`); `ToyButton`'s bounce starts when the focus arrives, ends after 220 ms and its held-key flag clears on key-up, on focus loss and in dispose (`holding an activate key keeps the button pressed until the key is let go`); the gallery's look and the screen's `TabController` live until the screen is left (`the Look test screen keeps its shader rows and has the gallery beside them`, and every widget test tears its tree down without a disposal error).
3. **How a new state combines with the others.** Nothing here pauses, hides or waits on input. The button's three states are mutually exclusive in the painter, and the pair that could clash — focused and disabled — can't happen: a disabled button refuses the focus (`a disabled button ignores taps and cannot take the focus`).
4. **Stay in the job's folder.** Only `packages/toy_look`, `tv_test_app/lib/src/ui`, `tv_test_app/test` and this report were written (see the `git status` note above about the generated Windows files, which I didn't edit).
5. **Stop rather than overstep.** Nothing needed a file outside `allow:` and the brief's contract held, so I didn't stop. The one reading I had to choose is the glow's radius (question 1).

## Checks

- `tools/check.sh format analyze look tv` — all PASS (format, analyze, look 73 tests, tv 35 tests + 1 skipped).
- `tools/review.sh` — 0 fail, 7 note: `toy_button.dart` 351 lines (over the 300 aim, under the 400 limit); `toy_colors.dart` 0.22 and 0.07 (the `dotAlpha` values, documented on the field); four numbers in `shader_spike_screen.dart` (16, 8, 8, 12) that were already there before this job.

## Questions and suggestions

1. **The glow's span.** The brief says "a radial glow from `backgroundGlow` at the centre to `background` at 0.75 of the longer side". I read 0.75 as the glow's *diameter* (radius 0.375 · the longer side = 112.5 on a 300 px box), so the gradient is finished well before a corner, and the corner is the plain background as the brief's own pixel test wants. If you meant the radius (0.75 · 300 = 225, reaching a corner exactly), the corner test can't hold. Please confirm.
2. **Two painters are public** — `ToyButtonPainter` and `ToyBackgroundPainter` — so the pixel tests can drive them with a look instead of photographing a widget. Their doc comments say so. If you'd rather keep them private, the tests have to pump a widget inside a `RepaintBoundary` and read it with `toImage`.
3. **The badge's screen-reader label needs a text direction**, which `Semantics` refuses to do without one, so `ToyBadge` passes `Directionality.maybeOf(context)`; an app with no `Directionality` above it would still assert. `toy_look` has no `Directionality` of its own (the brief doesn't ask for one) — apps get it from `MaterialApp`. Worth a rule for the later widgets, or should `toy_look` add one?
4. **`dotAlpha` shows as a `number` note** in `review.sh` (0.22 / 0.07 in `ToyColors`). They're the palette's documented shares, not a tuneable — if the check should ignore named palette fields, that's a `review.sh` change for another job.
5. **The gallery's keys** (`galleryPalette`, `galleryBadges`) exist so the tests can switch the palette and scroll to the badges; the repo already does this for the shader rows and the Stress button.
6. **Suggestions, not done:** a `test/toy_colors_test.dart` case for `dotAlpha` next to the palette's other values would catch a typo in a value the pixel test only sees through alpha; and `shader_spike_screen.dart`'s remaining numbers (16, 8, 12) could read `ToySizes.space*` now that the gallery beside them is fully token-driven. Both are outside this brief's test list.

## Commit message

Add the four Toy Box widgets and a gallery on the Look test screen

ToySizes gains buttonHeight (48 on a menu, 64 on a TV) and ToyColors
dotAlpha (22 % Sunny, 7 % Night). ToyButton is a pill with an ink edge,
the hard sticker shadow, the ActivateIntent focus with its ring and
bounce, and a dashed disabled state; ToyCard has a header band, ink
inside and a pop-in; paintToyBadge and ToyBadge draw the players' dots;
ToyBackground paints the sky and its dots once. The TV app's Look test
screen gains a Widgets tab showing all four in Sunny and Night.

## Status row

| 2b | Look package widgets: ToyButton, ToyCard, ToyBadge, ToyBackground, and a gallery on the Look test screen (s2b-toy-widgets.md) | **Done**: look 73 tests (+23), tv 35 (+3); every check green; widgets exported from `toy_look`, tokens `buttonHeight` and `dotAlpha` added. Open: no menu uses them yet (step 3); the look hasn't been seen on a TV or a phone screen yet (Claude's Windows build) |

## Delete

- none

## Claude's review (Nov 8, 2026)

Accepted, after rendering the gallery in both palettes with the real fonts (a throwaway test that loaded Fredoka and Nunito with FontLoader; not committed). Buttons, the focus ring, the dashed disabled state, the badges, the dots and the type all read as in the mock-ups. Two changes made by Claude, each with a failing test first:

- **The card's header band runs across the whole top of the card** (it was only as wide as its title): the card's column is stretched inside an `IntrinsicWidth`, and the title is centred. Test: "the header band runs across the whole top of the card, its title centred".
- **The glow is wider and softer** (question 1): its radius is 0.6 of the longer side (180 on a 300 px box), still plain sky in the corners. The background test checks the half-way pixel (about 160 red) and reads its dot at (272, 288), outside the glow.

Answers: 2, public painters are fine for pixel tests; 3, the apps always have a MaterialApp above, so no Directionality of toy_look's own; 4, the dotAlpha notes stay as notes; 5, fine; 6, later. Look tests: 74; tv 35 (+1 skipped).
