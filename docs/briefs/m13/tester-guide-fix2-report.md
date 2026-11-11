# M13.4 tester guide fix 2 — report

The join screen's `◀ Left` and `Right ▶` now draw in `join.png`. The fix is the one the brief
chose: the picture test loads the machine's symbol face as a fallback family and the pictures'
theme names it, so nothing in `lib/` changes and a machine without such a face draws boxes and
says so instead of failing. The other five pictures are byte-identical to the previous job's
(their md5s below match its report), which is also the proof the fallback fires only where a
glyph is missing. All three checks pass.

## What was wrong

`HostText.leftSide` is `'◀ Left'` and `rightSide` is `'Right ▶'`
(`packages/party_host/lib/src/text/host_text.dart:53`), drawn in a `ToyCard` header with the
look's Fredoka. Neither Fredoka nor Nunito has U+25C0 or U+25B6, nor does the test's Roboto copy;
a device fills them from its system symbol font, a widget test from its own box font.

## The fix

- **`controller_app/test/support/test_font.dart`**: `symbolFallbackFamily = 'SymbolFallback'`,
  the three candidate paths as `_symbolFontPaths` (Segoe UI Symbol, Apple Symbols, DejaVu — the
  first that exists wins), and `loadSymbolFont()`, which registers that face under the fallback
  families and, when none of the paths exists, prints
  `no symbol font on this machine (tried …): the join screen's ◀ ▶ are drawn as boxes` through
  `debugPrint` (the way this repo's tests report values) and returns — never a failure.
- **`controller_app/test/support/site_shots.dart`**: `shotTheme(look)` is the look's
  `toyTheme(look)` with `fontFamilyFallback: [symbolFallbackFamily]` applied to every style of its
  text theme, and `_TvApp` uses it instead of `party.toyTheme(look)`. The phone's screen keeps
  its own theme (`ControllerApp` builds it), so this touches the pictures only.
- **`controller_app/test/site_shots_test.dart`**: `setUpAll(loadSymbolFont)`, beside the icon
  font's.

The card's header is not drawn from the theme — `ToyCard._header` uses `look.type.button` — so
the fallback reaches it by inheritance: `Material` sets its default text style from
`theme.textTheme.bodyMedium`, and `Text` merges the header's own style over that one, which
keeps the ambient `fontFamilyFallback` because the header's style has none of its own. The probe
below is what showed the difference.

## The package prefix (what the first attempt missed)

The first version registered the face as `SymbolFallback` and added that to the theme, and
`join.png` still had two boxes. Probes (`zz_symbol_probe_test.dart`, deleted after this job),
each drawing `'◀ Left'` at 40 px:

| style | result |
| --- | --- |
| `fontFamily: 'SymbolFallback'` alone | arrow drawn (the face has U+25C0) |
| `Roboto` + `fontFamilyFallback: ['SymbolFallback']` (no package) | arrow drawn |
| `'packages/toy_look/Fredoka'` + fallback (no package) | arrow drawn |
| `Fredoka`, `package: 'toy_look'` + fallback | **box** |
| the same, with the face also loaded as `packages/toy_look/SymbolFallback` | arrow drawn |

So Flutter puts a style's `package` in front of every family the style falls back to, not only
the style's own family. Every style the look hands out carries `package: 'toy_look'`
(`ToyType`), so the engine looked up `packages/toy_look/SymbolFallback` and found nothing. The
face is now loaded under both names (`_symbolFamilies`), and the theme keeps the plain
`SymbolFallback` the brief named. Nothing in the pictures' code has to know why; `_lookPackage`
carries the reason in its doc.

## The pictures

Re-rendered by `tools/check.sh phone`; every file is 1440×576 and the bytes are those on disk
after the last run.

| file | bytes | size | md5 | was |
| --- | --- | --- | --- | --- |
| `join.png` | 209378 | 204 KB | 145be409b9b6b8d50dcd4621170334f3 | 209363 B, c11a6e7b3428b8ce6788281d9c35f994 |
| `dpad.png` | 197403 | 193 KB | 3a7c2a93673fb88bb99c3d2f896a651e | unchanged |
| `tilt.png` | 201906 | 197 KB | 6bae7f1f76279d0e42a987ddd093a35d | unchanged |
| `sticks.png` | 207115 | 202 KB | 2a63d6d95a3487cdc1ab828a60a08602 | unchanged |
| `menus.png` | 245073 | 239 KB | f278463f86861e88212f81d8bfad3392 | unchanged |
| `results.png` | 194311 | 190 KB | bfe13ed7309ae7ad3c16d4019f1d082c | unchanged |

Largest 239 KB, against the 300 KB cap the test asserts. Determinism: the six hashes above were
the same on two separate renders (13:02 and 13:06) on top of the test's own double captures and
double drawings.

Checked by eye, one file at a time: `join.png` shows `◀ Left` in the blue header and `Right ▶` in
the orange one, and no box anywhere; `dpad`, `tilt`, `sticks`, `menus` and `results` are the
previous job's pictures, still with no box.

## Checks and tests

| check | result |
| --- | --- |
| `format` | PASS |
| `analyze` | PASS |
| `phone` | PASS (448 tests: 447 + the 1 probe test listed for deletion; 447 once it is deleted) |

The probe was also run on its own: `probe: the pictures theme draws the header arrows` draws the
`◀ Left` card header with `shotTheme` and with plain `toyTheme` and requires the two PNGs to
differ — the check that would have caught the package-prefix mistake, which the eye caught here.

## Decisions

- **Both family spellings, plain name in the theme.** The theme should not have to know the look's
  package, and a style without a package (`Roboto` in a probe) resolves the plain name; loading
  the face twice costs one file read.
- **`debugPrint` for the "no face" line**, as `puzzle_size_test`, `piece_colors_test` and
  `split_layout_test` already do for values a reviewer needs to see.
- **No new permanent test.** A "the fallback drew" test can only pass on a machine with a symbol
  face, and the brief asks for no failure on another machine; the probe proves the mechanism for
  this review and goes away with it.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** Not affected: test code and pictures only, no app file changed, so a TV,
   a PC host, a phone on "Play on this phone", one on "Show on this device", a joined phone and
   an older peer all behave as before. The TV half of the pictures is `party_host`'s screens in
   a test's `MaterialApp`, whose theme gained a fallback list that only a missing glyph reaches
   (`site_shots_test`, 7 tests).
2. **When kept state starts and ends.** Not affected: nothing held, timed or cached. The one new
   "kept thing" is the registered font, which the binding keeps for the test file's life — the
   same lifetime `loadHostFonts` and `loadIconFont` already have (`loadSymbolFont` in
   `setUpAll`).
3. **How a new state combines with the others.** Not affected: no pause, wait or input state.
   The only state is "is the symbol face registered", and it is registered once before any
   picture is drawn.
4. **Stay in the job's folder.** Changed only `controller_app/test` (three files plus the probe
   listed for deletion) and `site/shots` (six pictures plus the six probe images listed for
   deletion), and this report. `git status` still lists
   `tv_test_app/windows/flutter/generated_plugin*` as modified: `flutter test` rewrites them and
   `git diff` shows only line endings — the same thing the last two jobs reported.
5. **Stop rather than overstep.** Nothing needed outside `allow:`, so nothing was stopped on. The
   package-prefix behaviour was solved inside the test files the job allows, without an app
   change.

## Questions

1. Should the guide's pictures keep this fallback at all, or would you rather the join screen draw
   its arrows as an `Icon` so the app, not the picture test, owns the glyph? The pictures now look
   right either way; this is about where the fix lives when the arrows are next touched.
2. Is `packages/toy_look/SymbolFallback` an acceptable test-side family name, or would you prefer
   the look to expose its package so the test can build the name from it?

## Suggestions

- `docs/project-notes.md` could carry one line: "Flutter prefixes a style's `package` onto every
  family in its `fontFamilyFallback` too, so a test font a look's style falls back to must be
  registered as `packages/<look package>/<family>`." It cost two probe rounds here.
- If the join screen's arrows ever move to an `Icon`, `pictureIcons` in `site_shots.dart` grows by
  two and this fallback can go.

## Commit message

```
Symbol fallback for the guide's join-screen arrows

The join screen heads its sides "◀ Left" and "Right ▶"; no font the apps
bundle has those symbols, so the pictures drew them as boxes. The picture
test now loads the machine's symbol face (Segoe UI Symbol, Apple Symbols
or DejaVu, first that exists) as a fallback family the pictures' theme
names, and a machine without one prints a line and still draws them.
Flutter prefixes a style's package onto its fallback families, so the face
is also loaded as packages/toy_look/SymbolFallback, the name the look's
styles look up. Only join.png changed; the other five are byte-identical.
```

## Status row

- **Nov 10:** the guide's six pictures are box-free — the join screen's `◀ ▶` draw from the machine's symbol face, loaded as a fallback family for the picture test only, with a printed line instead of a failure on a machine that has none; open: nothing (the app itself still gets those two glyphs from the device's system font).

## Delete

- controller_app/test/zz_symbol_probe_test.dart
- site/shots/zz_probe1.png
- site/shots/zz_probe2.png
- site/shots/zz_probe3.png
- site/shots/zz_probe4.png
- site/shots/zz_probe5.png
- site/shots/zz_probe6.png
