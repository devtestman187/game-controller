## Summary

**small fixes.** The change does what the brief asked, is tested, and the suites pass; the report needs correcting.
- must 0 · should 2 · could 6
- The report names the new file `arena_player_scale.dart`; the commit adds `arena_player_scale_painter.dart` — a reader following the report finds no file.
- Self-check 4 says "No other file changed", but `git status` lists three modified `tv_test_app/windows/flutter/generated_plugin_*` files, which the next commit would carry.
- The report's TV width figure (74.2 px) is computed at 0.4 × the *TV* radius, while the test measures at 0.4 × the *phone* radius (78.1 px); the asserted range still passes.

## Findings

- **should** docs/briefs/m14/bugs3/a2-arena-size-report.md:13 names `packages/test_game/lib/src/arena_player_scale.dart` as the new file, but the commit adds `arena_player_scale_painter.dart` → correct the path in the report (or rename the file, see the next finding).
- **should** docs/briefs/m14/bugs3/a2-arena-size-report.md:76 says "No other file changed", but the working tree has `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h` and `generated_plugins.cmake` modified (guideline §2 "don't edit generated files"), so a `git add -A` commit picks them up → revert those three files before committing and say so in the report.
- **could** packages/test_game/lib/src/arena_player_scale_painter.dart:16 is named `_painter` but holds no painter, only the factor and its function → rename it `arena_player_scale.dart`, which also puts it in order at packages/test_game/lib/test_game.dart:21 (it now sorts before `arena_painter.dart`, against the list's alphabetical order).
- **could** packages/test_game/test/arena_paint_test.dart:357 asserts `tvWidth > phoneWidth + 20` after lines 355–356 already pin both widths to disjoint ranges, so it can never fail on its own → drop it, or keep it and drop the two ranges.
- **could** packages/test_game/test/arena_player_scale_test.dart:7–8 declare `tvLook` and `phoneLook` that repeat `test/support/look.dart:9` (`sunny`) and the TV look `arena_paint_test.dart:44` also declares → put one `tvLook` in `test/support/look.dart` and use it in both tests.
- **could** docs/briefs/m14/bugs3/a2-arena-size-report.md:54–56 computes the TV body width as 2 × 40.5 × √0.84 = 74.2 px, but `arena_paint_test.dart:350–354` measures the TV frame at 0.4 × `marbleRadius` (the phone's 27 px), where the chord is 2 × 40.5 × √(1 − (10.8/40.5)²) = 78.1 px → state the width at the row the test measures, and keep 68–75 only if the shading really takes 6–10 px off.
- **could** docs/briefs/m14/bugs3/a2-arena-size-report.md:66 says the scale is tested "for the three kinds of look", but `arena_player_scale_test.dart` tests two kinds (TV and phone) plus palette and effects variants → say two kinds and name the variants.
- **could** docs/briefs/m14/bugs3/a2-arena-size-report.md:17–19 says the accessory, the dash glow, the cooldown ring, the aim cursor and the coin-count pill "grow with it", but the new paint test measures only the body (`arena_paint_test.dart:346`) → add a Bumper-round pixel check for the pill, or say in the report that those follow the radius and are untested.

## Decisions to confirm

- The classifier is the look's `sizes` (`ToySizes.tv` against `ToySizes.menu`): a Windows PC host therefore draws at 1.5 too, and a phone host feeding a TV over HDMI or casting stays at 1.0 — is that the intent?
- 1.5 is a compile-time constant in `test_game` (`arena_player_scale_painter.dart:9`), not a `ToyLook`/`ToySizes` field nor a settings value with a range (guideline §2, "playtest values go in the game's settings class"); `toy_look` was outside the job's allow list, so it could not go there — the owner may want it tunable when it is looked at on a device.
- The aim cursor, the dash glow and the cooldown ring grow with the picture (radius is shared, `arena_marble_painter.dart:100`), though the brief named the body, face, coin count and number — a growing aim cursor and cooldown ring on a TV was not explicitly asked for.
- The picture (radius 0.048) is larger than the collision radius (0.032) and the start pad stays 1.8 × the rules radius (`arena_painter.dart:116`), so on a TV marbles overlap before touching and sit tight in the pad — the brief said picture only; confirm the owner accepts it.

## Could not check

- That the two new tests fail on the old code: that needs the old tree, which a review may not create; the TV range (68–75) against the phone range (41–47) makes the paint test's failure for the right reason believable, and the scale test could not compile before the function existed.
- The report's exact measured values 44 px and 72 px: I confirmed only that they fall in the asserted ranges (the test passes).
- Whether the Windows PC host runs `tv_test_app` (and so gets the TV look): the report asserts it, and I read `tv_test_app/lib/main.dart:40` but not the PC host's own setup.
- My own `flutter test` runs may have rewritten the three `tv_test_app/windows/flutter/generated_plugin_*` files again; they were already modified before this review.

Checks run: `flutter test` in `packages/test_game` (219 pass), `packages/party_host` (396 pass), `tv_test_app` (53 pass, 1 skipped), and the two arena test files alone; `dart format --output=none --set-exit-if-changed` on the five changed Dart files (no change); `flutter analyze` in `packages/test_game` (no issues).

## Commit message

Review a2-arena-size: change right, report to correct

The TV scale is a pure function of the look, costs no host screen and is
tested at both function and pixel level; phone hosts and joined phones are
untouched. To fix: the report names a file that does not exist, self-check 4
is false while three generated plugin files sit modified in the tree, and the
TV chord in the report is measured at the wrong row. Also small: file name,
a redundant assertion, duplicated test looks, and untested pill and accessory.

## Status row

a2-arena-size reviewed: B-014 fix right and tested (arena 219, host 396, tv 53 pass); open: report corrections (2 should, 6 could) and reverting the three modified generated plugin files.

## Delete

- none
