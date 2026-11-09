# M13 9: fixing what the full review found (r1 the look and the games, r2 the host, r3 the apps)

Job: `docs/briefs/m13/s9-review-fixes.md`. Stop after it.

## What changed

### toy_look
- `lib/src/toy_shape.dart`, `lib/src/toy_background.dart`: the two shader comments now agree (item 2): one shape, one
  `FragmentShader`, its uniforms set just before its own draw; the sky has one shader because it has one draw per frame.
- `shaders/toy_shade.frag`: the glint is the fallback's — 8 % × 5 % of the bounds, at 27 % across and 24 % down, turned
  −30°, white at 0.75 (item 3; lines before and after below).
- `lib/src/toy_theme.dart`: `focusColor: _focusWash(look)`, the look's `focus` at `toyShadowAlpha` (item 14). `toyTheme`
  is 60 lines, with the slider comment on one line.
- `lib/src/toy_colors.dart`: `matDot` per palette (Sunny `Color(0x1F1E1646)`, Night `Color(0x12FFFFFF)`), with its doc
  line (item 9).
- `lib/src/toy_font_licenses.dart`: `registerToyFontLicenses()` reads both `OFL.txt`s through `rootBundle`; the test-only
  `load` parameter is gone (item 20).
- `test/toy_theme_test.dart`: +1, "the Material controls' focus wash is the look's focus token, at the shadow's strength",
  in both palettes (item 14).
- `test/toy_font_licenses_test.dart`: reads the two licences through the real bundle and compares the licence page's own
  paragraphs with each asset's text, whitespace-normalised (item 20).

### puzzle_game
- `lib/src/puzzle_painter.dart`: the targets' dashed edge is toy_look's `paintDashedEdge` with the old `_dashPx` and
  `_dashGapPx` as `on`/`off`; the private `_dashed` helper is gone; the stale ✓/✗ doc above `_mark` is removed (items 7,
  9).
- `lib/src/match_hud.dart`: the numbers are named constants with a doc line each — `_clockSize`, `_stripCountSize`,
  `_stripPad`, `_stripRightCap`, `_dividerAlpha`, `_dividerWidth`, `_stripBarTop`, `_stripBarHeight`, `_gapClockTop`,
  `_gapCountTop`, `_gapSecondCountTop`, `_gapCountSize`, `_gapBarTop`, `_gapBarHeight` (item 8).
- `lib/src/mirror_painter.dart`: `_targets` and `_players` take the `px` `paint` already read (item 9).
- `test/look_paint_test.dart`: +1, "a hinted target glows in focus, and none does without the hint"; its `snapshot`
  helper gained `hints` (item 6).

### test_game
- `lib/src/arena_hud_widgets.dart`: `_PlayerRow.build` is split, with `_name` (the colour dot and the number and name) and
  `_dash` (the ready dot) beside it; `build` is 27 lines and draws the same widgets with the same keys (item 1).
- `lib/src/arena_painter.dart`: the start pad's dashed edge is `paintDashedEdge` with the lengths it had, and the
  private `_dashed` helper is gone (item 7); `matDotAlpha` and the sunny/night choice of the mat's dot are gone, the dot
  is `look.colors.matDot` (item 9).
- `lib/src/arena_view_widgets.dart`, `lib/src/arena_module.dart`: `ArenaBoard` draws in `ToyLookScope.of(context)` and so
  throws with no scope; `defaultArenaLook` moved to the module, which wraps its view only when nothing above it has a
  look (item 5, and question 1).
- `test/arena_character_test.dart`: player 1's ears are compared with a reference marble of `ToyCharacter.forPlayer(1)`
  drawn on the same screen, and must not match player 2's antenna — a silhouette match, as toy_look's accessory test
  does (item 9).
- `test/support/look.dart`: doc line only ("a view drawn with none throws").

### party_host
- `lib/src/look_providers.dart`: `roundHoldsProvider` is a plain `RoundHolds` object with a count, and `refresh()` does
  nothing while the count is not zero (item 22).
- `lib/src/ui/round_palette_hold.dart` (new): `RoundPaletteHold({child, held = true})`, which takes and releases the hold
  from its life-cycle (a plain object, so no provider is modified as the tree builds); `part_host.dart` exports it.
- `lib/src/ui/lobby_music_widgets.dart`: `RoundHold` wraps its child in `RoundPaletteHold`, so the host's round screens,
  their results and pause hold the palette.
- `lib/src/ui/away_card.dart`: `HostText.ok` (item 11).
- `lib/src/ui/pause_menu.dart`: `_noteHostAway` stops the countdown the moment the host app goes away (item 12).
- `lib/src/ui/lobby_music.dart`: `_looping` remembers the player, and `dispose` stops the loop; doc updated (item 13).
- `test/countdown_test.dart` +1 (item 12), `test/lobby_music_test.dart` +1 (item 13), `test/look_palette_test.dart` +1
  (item 22) and its look-up now reaches the host navigator through `PuzzleScreen` (the stub home is offstage under it).

### controller_app
- `lib/src/ui/controller_screen.dart`, `lib/src/ui/controller_parts.dart`: no whole-screen `ToyStillSky`; the pad holds
  the sky and the joined view holds its own (item 18).
- `lib/src/ui/joined_view.dart`: the view wraps itself in `RoundPaletteHold(held: showsGameProvider)`, so a joined game
  freezes the palette and the next page after it does not (item 22).
- `test/sky_holds_test.dart`: rewritten — Connect drifts, the pad holds, the joined view holds, a hosting phone's picker
  drifts (item 18).
- `test/round_palette_test.dart` (new): a joined game at 18:59 keeps Sunny past 19:01 and a page after it is Night
  (item 22).
- `test/look_prefs_test.dart` (new, 2 tests): the real root overrides, hosting and joined, read and save this phone's
  Look and sound (item 19).
- `test/support/pump_app.dart`, `test/support/host_app.dart`: `clock` and `stillSky` parameters (question 4).

### tv_test_app
- `lib/src/ui/shader_spike_rows.dart`, `lib/src/ui/shader_spike_screen.dart`: the painter takes the look and draws
  `look.colors.player(index + 1)`; the `playerColors` import is gone (item 17).
- `lib/src/ui/home/controllers_panel.dart`: the body's size is read once into `latencyWidth` with a comment on why the
  `!` is safe (item 23).
- `test/tv_fit_test.dart`: +1, "the home fits a 1280 x 720 TV, with its tiles in view" (item 21).

### docs and assets
- `docs/design/look-and-sound.md`: the "Decided at step 9" line under section 6's clock (item 4).
- `assets/CREDITS.md`: the six puzzle audio rows are in the table, after the arena's four (item 15).
- `docs/briefs/m14/scan-party-touchpoints-report.md`: one line on a scoreboard's lobby-music hold (item 16).

## Test counts

From `tools/check.sh format analyze look puzzle arena host phone tv kit`, before this job and after it:

| target | before | after |
| --- | --- | --- |
| look | 109 | 110 (+1: the focus wash) |
| kit | 48 | 48 |
| arena | 62 | 62 (one character test strengthened) |
| puzzle | 171 | 172 (+1: the hint glow) |
| host | 236 | 239 (+3: countdown, lobby music, the palette freeze) |
| phone | 428 | 433 (+5: 2 new sky holds, 1 palette freeze, 2 real-root prefs) |
| tv | 52 passed, 1 skipped | 53 passed, 1 skipped (+1: 1280 × 720) |

## Tests first

The behaviour changes (items 12, 13, 14, 18 and 22, and the phone's hold) were written as tests first and seen failing
against the old code. Two were re-broken and re-run after the work to prove the tests still catch it: the whole-screen
`ToyStillSky` in `ControllerScreen` made the picker test fail (Expected 6.0, Actual 0.0), and `held: false` in
`JoinedView` made the joined palette test fail (Expected sunny, Actual night); both were restored at once. Items 6, 19,
20 and 21 pin behaviour or wiring that already worked (a hint's glow, the prefs link, the bundled licences, the home at
720p), so they had no failing-first step; 20 is still a test change over the real bundle, which the old fake loader hid.

## Each numbered item

1. Done: `_PlayerRow.build` split into `build`, `_name` and `_dash`, 27 lines; no draw changed. The arena's HUD tests
   (`arena_hud_test.dart`, which pin `hud-<id>`, `wins-<id>`, `hits-<id>`, `dashes-<id>`, `dashReady-<id>`) pass
   unchanged.
2. Done: both comments now say one shader per draw, its uniforms set just before it, and why the sky keeps one.
3. Done: the glint, see below. No test (Claude checks it on Windows, as the brief says).
4. Done by inspection: the "Decided at step 9 (Claude, Nov 9, 2026)" line under section 6, beside step 6's.
5. Done, with one deviation (question 1): `ArenaBoard` throws without a scope, its doc says so, and `test_game`'s
   `withLook` doc no longer mentions a default. `defaultArenaLook` did not go away entirely: it moved into
   `arena_module.dart` for `game_kit/test/frame_view_test.dart`, which is outside `allow:`. The board itself no longer
   uses it.
6. Done: "a hinted target glows in focus, and none does without the hint" reads one point inside the outline with the
   hint and without it: the hinted one is `focus` at 0.5 under the target's own 0.25 fill, the other only the fill on the
   board. It pins the glow the painter already drew; no code changed.
7. Done: both painters call `paintDashedEdge` with the lengths they had (`_dashPx`/`_dashGapPx`, `startDashShare`/
   `startGapShare`); both private `_dashed` helpers are gone. No test pins the dashes' pixels; the mirror and arena
   paint tests still pass.
8. Done by inspection: fourteen named constants, each with a doc line; the drawn numbers are unchanged.
9. Done: `mirror_painter` passes its `px`; `ToyColors.matDot` carries the mat's dot (the arena paint test that finds
   the mat's dots still passes); the stale `_mark` doc is gone; the ears test now matches
   `ToyCharacter.forPlayer(1)`'s silhouette (share above 0.95) and not player 2's (below 0.5), in both palettes.
10. No change, as decided. The motion setting's own tests still pass (`toy_background_test`, `toy_card_test`,
    `toy_button_test`); the games follow the effects setting.
11. Done by inspection (`away_card.dart`); its layout tests still pass.
12. Done: "a host-away hold stops the countdown at once, with no beat tick in between" — the away signal alone puts
    `countdown` in the fake's stopped list, with no frame pumped.
13. Done: "a scope disposed with the loop playing stops it" — pumping a bare widget (the host's scope gone) leaves the
    fake's loop null.
14. Done: the focus wash is the look's `focus` at `toyShadowAlpha` (0.35) in both palettes (see below).
15. Done by inspection: the six puzzle rows sit after the arena's four, in their old order, and the stray rows above the
    heading are gone.
16. Done by inspection: one line in the touchpoints report's sound row on a scoreboard's hold.
17. Done: the spike rows take `look.colors.player(index + 1)`; the screen passes its `ToyLookScope`'s look down; no
    `Color(playerColors[...])` is left. The spike screen's tests pass.
18. Done: "the pad holds its sky still", "the joined view holds its sky still" (and finds a `ToyStillSky` over the joined
    view), "the Connect screen's sky drifts" and "a hosting phone's picker drifts"; the picker test failed with the old
    whole-screen hold (Expected 6.0, Actual 0.0) and passes now.
19. Done: two tests on the real root overrides, one joined (Look reads Night, a tap saves Sunny; the music slider saves a
    higher volume) and one hosting (the host's `lookPrefsProvider` is the phone's prefs, the sound volume is read while
    hosting, and the picker's music and Look choices are saved). The harness keeps its own override.
20. Done: the test registers the licences through `rootBundle` (no fake reader) and compares the licence page's text
    with the asset's; the missing-file path would now fail the test.
21. Done: "the home fits a 1280 x 720 TV, with its tiles in view" checks no overflow, the title whole, every sample
    tile on the screen, and the header's buttons in at most two rows. It passed on the current home, so no layout change
    was needed: 720p is a new pinned size beside 960 × 540's, not a fix, and the case was added because the review asked
    for it.
22. Done on both: host "a round freezes the palette, and a page pushed after it turns Night" (18:59 round, Settings at
    19:01 still Sunny, the picker after the round Night) and joined "a joined game freezes the palette, and the next
    page after it turns Night" (same clock, `openSettings` still Sunny, `viewEnd` then Settings Night). The joined one
    failed before the hold (Expected sunny, Actual night).
23. Done: `latencyWidth` is computed once, after a comment that every `ToyType` sets its `body` size, so the `!` is
    safe; the tile's tests pass.

## The shader change

`packages/toy_look/shaders/toy_shade.frag`, the glint, before (HEAD):

```glsl
  // Glint: a small tilted oval near the top-left.
  vec2 g = p - vec2(-0.42, -0.48);
  g = vec2(g.x * 0.87 + g.y * 0.5, -g.x * 0.5 + g.y * 0.87) * vec2(1.0, 1.7);
  float glint = 1.0 - smoothstep(0.13, 0.19, length(g));
  col = mix(col, vec3(1.0), glint * 0.9);
```

after:

```glsl
  // Glint: the fallback's own (body_fallback.dart): an oval 8 % by 5 % of the
  // bounds at its centre 27 % across and 24 % down them, turned -30 degrees,
  // white at 75 %.
  vec2 g = p - vec2(-0.46, -0.52);
  g = vec2(g.x * 0.866 - g.y * 0.5, g.x * 0.5 + g.y * 0.866);
  float glint = 1.0 - smoothstep(0.9, 1.0, length(vec2(g.x / 0.08, g.y / 0.05)));
  col = mix(col, vec3(1.0), glint * 0.75);
```

`p` runs −1…1 over the bounds, so the centre's `(−0.46, −0.52)` is 27 % across and 24 % down, and the semi-axes
`0.08`/`0.05` are the fallback's 4 % × 2.5 % halves of `glintSize` (0.08 × 0.05 of the bounds). The turn is the
fallback's −30° (a coordinate turn by +30°), and the last tenth of the radius is the soft rim the fallback's antialiased
oval has. So a shaded shape and a flat one now show the same glint.

## The focus strength

`toyShadowAlpha`, 0.35 (in `toy_shape.dart`, where the fallback's shadow uses it). `toyTheme`'s `focusColor` is the
look's `focus` (`Color(0xFFFFD23F)`, both palettes) at that alpha, so a Material control's focus reads over paper and
over the Night sky, and it takes the look's colour instead of Material's 12 % black.

## Self-check, review rules part A

1. **Every host setup.** A TV host and a phone host share `RoundHold`, so both freeze the palette and stop the countdown
   (host tests, and `pumpHostApp` is the phone host there); a joined phone freezes it from `JoinedView` (round palette
   test); a host one build older sees nothing new, as no message changed. The phone on "Show on this device" is a
   viewer drawing the same frames, so the sky and palette rules are the joined phone's.
2. **When kept state starts and ends.** `RoundHolds` takes a hold in `initState`, follows `held` in `didUpdateWidget`
   and gives it back in `dispose`; with no round it is 0, so `refresh()` works (the picker turning Night after the
   round). `LobbyMusic._looping` is set when the loop starts and cleared when it stops, and `dispose` stops a loop
   still playing (its test). The countdown now stops on the away edge and the round's end, and restarts when the beat
   starts again (its two tests).
3. **How a new state combines with the others.** The palette hold stands through the pause menu, a player away, the
   results and a host away, because `RoundHold` is above all of them and never unmounts mid-round; it goes when the
   round does (round palette test: the next push turns Night). The countdown's away stop combines with the pause: away
   pauses the round and stops the countdown, and the beat starting over plays it again (the old test and the new one).
4. **Stay in the job's folder.** Every file written is in `allow:`; `git status` also lists the three
   `docs/design/m12-mirror-*.png` (rewritten by the puzzle tests, question 3), the tv Windows plugin registrant files
   (already modified at 08:35, before this job's first edit) and the brief itself.
5. **Stop rather than overstep.** One file outside `allow:` was needed for item 5 as written (`game_kit`'s frame test
   mounts the arena with no scope); I kept the default inside `test_game` and raised it as question 1 rather than edit
   `game_kit`.

## Questions and suggestions

1. **Item 5's `defaultArenaLook`.** `packages/game_kit/test/frame_view_test.dart:365` mounts `arenaModule` on a bare
   widget with no `ToyLookScope` and expects the arena key to be found, so a board that throws with no scope fails a
   test outside `allow:`. The board does throw now; `ArenaViewer.build` reads the scope above it and, when there is none,
   wraps the board in `defaultArenaLook` (Sunny, phone, effects on), which is the old doc's promise kept in one place.
   If the viewer should throw as the puzzle's views do, `game_kit`'s test needs a scope — a one-line change outside
   this job's files.
2. **A Look change mid-round.** `LookPaletteNotifier.build` still watches `lookSettingsProvider`, so changing the Look
   setting while a round is on re-runs `build` and the palette can change under the round's screens; only `refresh()`
   (a route push) is guarded. If D1 means no change at all mid-round, `build` needs the guard too, and the answer to
   "when does the setting apply" becomes the next route change. Not done, as the brief named `refresh` only.
3. **The mirror PNGs.** `packages/puzzle_game/test/mirror_png_test.dart` rewrites `docs/design/m12-mirror-*.png` on
   every puzzle test run, and they are outside `allow:`. Their bytes now differ from HEAD because `paintDashedEdge`
   draws each dash as its own path where the old `_dashed` bundled them into one, so the dashed edges antialias
   slightly differently (proved by hashing the same test with each version). `git checkout -- docs/design/m12-mirror-*.png`
   restores HEAD's bytes, which the next test run rewrites anyway; the images' content did not change.
4. **Test harness parameters.** `pumpApp`/`pumpFaked` gained `clock`, and `pumpHostApp` gained `stillSky`, rather than a
   second `Override` of the same provider: Riverpod asserts when one scope overrides a provider twice.
5. **The tv Windows files.** `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
   `generated_plugins.cmake` were modified at 08:35:47, before this job's first edit, by a tool run; they are not this
   job's and cannot be committed by it. Confirm before committing.

Suggestions (not acted on):

- `mirror_png_test` writing into `docs/design` on every run makes PNG churn in every diff that touches the puzzle; it
  could write beside the test and compare, or only regenerate behind a flag.
- `toyTheme` is now 60 lines — at the limit `tools/review.sh` notes. The next setting added there wants a helper.

## Commit message

M13 9: fix the full review's findings in the look, host and apps

The arena HUD's row splits under 60 lines, match_hud's numbers are named, and the shader comments say why one
shader per draw is safe; the glint is now the fallback's 8 x 5 % oval at 0.75, the mat's dot is a ToyColors token,
and both dash painters use paintDashedEdge. The arena board no longer falls back to a default look; its module
supplies one only when no scope is above it.
The host's countdown stops the moment the app is hidden, lobby music stops with its scope, 'OK' is HostText.ok, and
the theme's focus wash is the look's focus at toyShadowAlpha; a round freezes the palette on the host and a joined
phone. The phone's sky holds only under the pad and the joined view, both font licences load from rootBundle, and
the TV fit covers 1280 x 720.

## Status row

M13 9: the full review's 23 fixes are in (arena HUD split, shader comment and glint, design's step-9 line, the arena's default look removed from the board, hint-glow test, one dashed edge, match_hud constants, mirror px and matDot, HostText.ok, countdown stops on host away, lobby music stops with its scope, focus wash at toyShadowAlpha, CREDITS table, M14's scoreboard hold, spike rows' look colours, the phone's sky holds only on the pad and joined view, real-root prefs test, rootBundle licences, 1280 x 720 fit, the palette frozen mid-round on host and phone, controllers_panel's `!` explained); open: a Look-setting change mid-round still rebuilds the palette (Q2), and the mirror PNGs the puzzle test rewrites want a `git checkout` before the commit (Q3).

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted, with Claude's additions below. All twelve checks are green (look 111, puzzle 172, arena 62, host 240, phone 433, tv 53 + 1 skipped, kit 48, protocol, connection and metrics), and review.sh has no FAIL.

- **The job's changes were applied by hand.** The worker's run of the puzzle tests rewrote `docs/design/m12-mirror-*.png`, so flash held the whole job back. Their bytes changed only because `paintDashedEdge` antialiases each dash on its own; they're committed as rewritten, so later test runs leave the tree clean. The Windows plugin registrant files were left out.
- **Q1:** `defaultArenaLook` is gone. game_kit's frame test puts a `ToyLookScope` above the Arena (toy_look is now a dev dependency there), and the Arena's viewer reads the screen's scope, so a screen without one throws.
- **Q2:** a Look change during a round waits for the round to end. `LookPaletteNotifier.build` keeps the palette while `roundHoldsProvider` counts a round; the setting is saved, and shows from the first page after the round. New test in `look_palette_test`.
- **Windows check, focus:** a switch row now lights in the look's yellow. A slider still drew Material's grey halo, because its focus is its overlay colour, so `sliderTheme.overlayColor` is the same focus wash (test in `toy_theme_test`).
- **Windows check, the glint:** the shader's glint was the fallback's size, but it stayed fixed in the shape's own box, so it turned with a spinning shape while the fallback's stays on the light's side. The shader now turns the glint's place and tilt by the angle from the resting light to `uLight`. Seen on Windows: the shader and fallback glints sit together on the circle, square and triangle; 1.2 ms frames.
- **Still for a device:** the sky drifting on a host phone's menus; the lobby music, countdown and volumes by ear; the warm-up on a cold start; the shaders on the Android TV box and an iPhone.
