# M13.4 tester guide fix — report

The six pictures drew every Material icon as an empty box because a widget test has no
icon font, and the TV frame carried a red debug ribbon because the test's own `MaterialApp`
didn't turn the banner off the way both apps do. Both are fixed, all six are re-rendered and
byte-identical between runs, and a new test fails if any of the icons the pictures show has no
glyph. **One box remains and can't be fixed from this job's files:** the `◀` and `▶` of the join
screen's side headers are text from `HostText.leftSide`/`rightSide`, and no font the app has (or
the SDK ships) contains those characters — see below. Everything else checks out.

## What was wrong

1. **No icon font.** `loadHostFonts` (`controller_app/test/support/test_font.dart`) loads Roboto,
   Fredoka and Nunito and its doc even says "icons keep their box size in any font, so the fit
   needs no icon font" — true for a fit test, wrong for a picture. An `Icon` sets a box of its
   size whatever the font; with no `MaterialIcons` family loaded the engine fell back to the
   test's own font, which draws a box for every character. Every icon in the six screens was that
   box: Start/Back, the side labels' arrows, the bar's mode tab, Settings, Diagnostics, the
   picker's Puzzle settings, the results' Rematch and Change teams, the boards' checks.
2. **The debug ribbon.** `_TvApp` in `controller_app/test/support/site_shots.dart` builds its own
   `MaterialApp`; `tv_test_app/lib/main.dart` and `controller_app/lib/main.dart` both pass
   `debugShowCheckedModeBanner: false`, and the test's copy didn't. A debug build drew the ribbon
   over the TV frame's top-right corner.

## The fix

- **`site_shots_test.dart`** calls a new `setUpAll(loadIconFont)` beside `loadHostFonts`, and a new
  test, `the pictures draw their icons: each one has a glyph, not a box`, draws each of the eight
  icons the pictures show (`pictureIcons`) in its own family and the same character in a family
  no test registers (`noSuchFont = 'NoSuchFontInThisTest'`); the two PNGs must differ. If the icon
  font is missing, every icon falls back to the same box font and the two pictures are equal, so
  the test fails for the bug's reason.
- **`test_font.dart`**: `loadIconFont()` loads the SDK's one icon face as the family
  `MaterialIcons`; `iconFont()` finds it by walking up from `Platform.resolvedExecutable` (the
  engine runs from `<flutter>/bin/cache/artifacts/engine/<os>/flutter_tester`, so the cache is a
  few folders above it). No folder is written down, and a machine without the artifacts gets
  `the Material icons are not in the Flutter SDK's cache above …: run flutter precache and try
  again`.
- **`_TvApp`** now passes `debugShowCheckedModeBanner: false`, with a comment naming the app's own
  root that does the same.

### Two things worth knowing about the font

- **This SDK's face is `materialicons-regular.otf`, lower case** (verified by listing
  `C:\src\flutter\bin\cache\artifacts\material_fonts`: `materialicons-regular.otf`,
  `materialicons_license.txt`, `codepoints`, and the whole Roboto family). The brief's
  `MaterialIcons-Regular.otf` only matched because Windows' folders ignore case — on macOS it
  would not. `iconFont()` tries both spellings (a `const List<String>` with the reason in its doc).
- **One face covers every variant.** The icons the pictures use all report `fontFamily:
  'MaterialIcons'` (`Icons.settings_outlined`, `gamepad_outlined`, `monitor_heart_outlined`,
  `sentiment_satisfied_alt_rounded` included); the filled, outlined, round and sharp sets share
  the family and differ in codepoint, and the face draws all of them. A first attempt that looked
  for `-Regular.otf` files and skipped everything when none matched left every icon a box — and
  the new test caught it, which is how it was found rather than by eye.

## The box that remains

`join.png` still shows one box before "Left" and one after "Right". They are **not** icons:
`HostText.leftSide` is `'◀ Left'` and `rightSide` is `'Right ▶'` (`packages/party_host/lib/src/
text/host_text.dart:53`), drawn in the look's Fredoka. Measured in
`zz_font_debug_test.dart` (byte compare of each character against the same family's box for
U+E000):

| family | U+25C0 ◀ | U+25B6 ▶ | U+2022 • |
| --- | --- | --- | --- |
| `packages/toy_look/Fredoka` | box | box | drawn |
| `packages/toy_look/Nunito` | box | box | drawn |
| `Roboto` (test copy) | box | box | drawn |
| `MaterialIcons` (the SDK face) | **drawn** | **drawn** | box |

So the app relies on the device's system font for those two characters: Android/iOS ship a symbol
fallback that has them, and a widget test's fallback font is the box font, by design. No test-side
change can supply a glyph to a family that lacks it; the fixes all live in `lib/`:

1. draw the arrow as an `Icon` in the card header, as the Start/Back buttons already do through a
   `WidgetSpan` (`join_screen_widgets.dart:317`), or
2. add `fontFamilyFallback: ['MaterialIcons']` to the header's text style, or
3. drop the arrows from the two strings (that also touches `host_text_test`).

I left it alone rather than work around it: the job may not change `lib/`, and choosing between
those three is a design decision (question 1).

## The pictures

Re-rendered by `tools/check.sh phone`; every file is 1440×576 and the sizes below are the bytes on
disk after the last run.

| file | bytes | old bytes | md5 |
| --- | --- | --- | --- |
| `join.png` | 209363 (204 KB) | 208727 | c11a6e7b3428b8ce6788281d9c35f994 |
| `dpad.png` | 197403 (193 KB) | 197465 | 3a7c2a93673fb88bb99c3d2f896a651e |
| `tilt.png` | 201906 (197 KB) | 201633 | 6bae7f1f76279d0e42a987ddd093a35d |
| `sticks.png` | 207115 (202 KB) | 207050 | 2a63d6d95a3487cdc1ab828a60a08602 |
| `menus.png` | 245073 (239 KB) | 245023 | f278463f86861e88212f81d8bfad3392 |
| `results.png` | 194311 (190 KB) | 193755 | bfe13ed7309ae7ad3c16d4019f1d082c |

Largest 239 KB, against the 300 KB cap (the test asserts it). Determinism: the six hashes above
were the same before and after the last `tools/check.sh phone` run (two runs, same bytes), on top
of the in-test checks that each screen and each picture is captured/drawn twice and compared.

Checked by eye, one picture at a time: `dpad`, `tilt`, `sticks`, `menus`, `results` have no box
left anywhere (the ribbon is gone from the TV frame's corner), and `join.png` has only the two
side-header boxes described above.

## Checks and tests

| check | result |
| --- | --- |
| `format` | PASS |
| `analyze` | PASS |
| `phone` | PASS (451 tests: 446 + the new icon test + 4 tests of the probe file listed for deletion; 447 once it is deleted) |

The new test was seen to fail for the right reason: with the loader finding no face (the
`-Regular.otf` mistake) it reported `Expected: not [ … ]` and the six pictures were still boxes.
`loadIconFont` itself fails loudly if the SDK cache has no icons.

## Decisions

- **Load the icons in the picture test only**, not in `loadHostFonts`: a fit test measures text
  and never looks at an icon, and adding an eighth font to ~440 other tests buys nothing.
- **One face, one family.** No speculative list of `MaterialIconsOutlined`/`Round`/`Sharp` file
  names: this SDK's folder has one face, the app's icons all name `MaterialIcons`, and the guard
  test would catch it if that changed.
- **Guard the eight icons the pictures show**, not just "the family is registered": an icon added
  to Flutter before the font has it would otherwise leave a box unnoticed.
- **The banner goes off on the test's own `MaterialApp`**, not on the captured screen: the ribbon
  is the app root's, and both apps already set it false in `main.dart`.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** Not affected: only test code and pictures changed; no app behaviour.
   The TV half is `party_host`'s screens pumped into a test's `MaterialApp`; the phone half is
   `ControllerApp` itself, so neither host's rendering changed (`site_shots_test`, 7 tests).
2. **When kept state starts and ends.** Not affected: nothing held, timed or cached. The one
   new "kept thing" is the registered font, which the binding keeps for the test file's life —
   the same lifetime `loadHostFonts` already has (`loadIconFont` in `setUpAll`).
3. **How a new state combines with the others.** Not affected: no pause, wait or input state.
   The only state is "is the icon font registered", and the guard test reads it before the
   pictures are drawn (`the pictures draw their icons…` runs in the same file's `setUpAll`).
4. **Stay in the job's folder.** Changed only `controller_app/test` (three files) and
   `site/shots` (six pictures), plus this report; the probe files under those folders are listed
   for deletion. `git status` also lists `tv_test_app/windows/flutter/generated_plugin*` as
   modified: `flutter test` (run by `tools/check.sh`) rewrites them, `git diff` shows no content
   change, only line endings — the same thing the tester-guide job reported.
5. **Stop rather than overstep.** The `◀ ▶` boxes need a `lib/` change, which this job may not
   make: reported above with the three options and left undecided. Nothing else was worked
   around, and no app file was edited.

## Questions

1. Which of the three fixes for the side-header arrows do you want (icon in the header, a
   `fontFamilyFallback`, or plain 'Left'/'Right')? Until then `join.png` keeps those two boxes,
   which a device fills with its system font.
2. Should the guard test's icon list (`pictureIcons`) be extended to every icon any future
   screen adds, or is the eight the six pictures use enough?

## Suggestions

- `docs/project-notes.md` could carry one line: "a widget test has no Material icon font; a
  picture test must load the SDK's `bin/cache/artifacts/material_fonts` face, whose file name is
  lower case — Windows hides that, macOS doesn't." It cost two failed runs here.
- `tools/check.sh phone` regenerates the pictures as a side effect; a reviewer who runs it on a
  different Flutter version gets a diff of six PNGs. Worth a note in `docs/dev-tools.md`.

## Commit message

```
Icon font for the guide's pictures, and no debug ribbon

A widget test has no Material icon font, so every icon in the six pictures
drew as an empty box; the picture test now loads the SDK's one icon face
(materialicons-regular.otf, found from the running tool's path) and a new
test fails if any icon the pictures show has no glyph.
The test's TV app now turns off the debug banner, as both apps do, so the
red ribbon is gone from the frame's corner.
All six pictures re-rendered, same bytes on every run, largest 239 KB.
Not fixed: the join screen's ◀ ▶ side-header characters, which no bundled
font has — a lib change, reported.
```

## Status row

- **Nov 10:** the guide's six pictures draw their Material icons (the SDK's icon face is loaded by
  the picture test, with a guard test that fails while any icon is a box) and the debug ribbon is
  gone; open: the join screen's `◀ ▶` side-header characters still show as boxes (needs a `lib`
  change: an icon, `fontFamilyFallback`, or plain Left/Right).

## Delete

- controller_app/test/zz_font_debug_test.dart
- controller_app/test/zz_check.dart
- site/shots/zz_fonts.png
- site/shots/zz_fonts.txt
- site/shots/zz_fallback.png
- site/shots/zz_zoom_join.png
- site/shots/zz_zoom_bar.png
- site/shots/zz_zoom_menus.png
