# M14 bugs3 a2-arena-size — report (B-014: players look too small on a TV)

## Summary

**Root cause.** A marble's drawn radius is `snapshot.playerRadius × size.shortestSide`
(`arena_marble_painter.dart`), a fixed share of the field (0.032). It is the right
share at arm's length and too small from three metres: the field fills the TV, so the
share of the screen is the same as on a phone, but the screen is far away. Nothing in
the view knew which screen it was drawing on.

**What changed, by file.**

- `packages/test_game/lib/src/arena_player_scale_painter.dart` (new): `tvPlayerScale`
  (1.5) and `arenaPlayerScale(ToyLook look)` — 1.5 for the TV's look, 1 for a phone's.
  (The report first named it `arena_player_scale.dart`; the commit's file is this one.)
- `packages/test_game/lib/test_game.dart`: exports the new file.
- `packages/test_game/lib/src/arena_marble_painter.dart`: the marble's radius times
  `arenaPlayerScale(look)`; one doc paragraph. Everything the painter derives from that
  radius (body, eyes, accessory, dash glow, cooldown ring, aim cursor, coin-count pill
  and its number) grows with it; nothing else does.
- `packages/test_game/test/arena_player_scale_test.dart` (new): the scale function.
- `packages/test_game/test/arena_paint_test.dart`: one test that the drawn marble is
  larger in the TV's look, plus the `tvLook` and `bodyWidth` helpers it uses.

**Decisions.**

- **The classification is the look, not `LayoutTarget` or a new flag.** `ToyLook.sizes`
  is already `ToySizes.tv` or `ToySizes.menu` (M13), built from `toyTvProvider` in
  `party_host`, which the TV app overrides to true. The painter already takes the look
  (design D5), so the factor needs no new parameter, no new switch, and no
  `party_host/lib/src/ui` change. `game_screen.dart` is 399 lines, over this brief's
  380-line limit, so a change there would have forced a split; this avoids it.
- **A TV host and a PC host both scale (1.5).** Both run the TV app, both set the TV
  look, and both are watched from a seat. A phone or tablet host, and a joined phone,
  keep the phone look and so the look they had.
- **Only the marble's picture grows.** The start pad, the coins, the walls and the
  pieces are field markings at the field's scale and stay as they are; the brief names
  the characters.

**Not done.** No rule, speed, map or collision radius changed; no text added. A marble
on a TV is now drawn 0.048 of the shorter side across against a collision radius of
0.032, so two marbles in a Bumper Round can overlap a little before they touch, and one
can look as if it touches a wall. The brief asked for the picture alone, so that is
left as it is — flagged below for a device look.

**What the owner should try on a device.** Start an Arena round on the TV (or the
Windows TV app): marbles, eyes, coin counts and the winner's number should read from
the couch at about 1.5× their old size, the map unchanged. Then host on a phone with
"Play on this phone" and with "Show on this device", and join with a phone: the arena
should look exactly as it did before on all three.

**Computed test values.** `tvPlayerScale` = 1.5. Scale: TV look 1.5, phone look 1.0
(both palettes, effects on and off). Drawn radius in the tests' 960 × 540 TV box: at
the test radius 0.05, 27 px on a phone, 40.5 px on a TV; at the game's 0.032, 17.28 px
and 25.92 px. Body width measured along the chord 0.4 × radius below the middle
(2 × r × √0.84 = 1.833 × r: 49.5 px on the phone, 74.2 px on the TV, less the ink edge
and rim shading): phone 44 px, TV 72 px, so the ranges 41–47 and 68–75. Both new tests
failed first: the scale test did not compile, and the paint test measured 44 px for the
TV before the change (same as the phone).

## Self-check: docs/review-rules.md part A

1. **Every host setup.** TV host and PC host (TV look, `toyTvProvider` true) draw at
   1.5; a phone host on "Play on this phone" and "Show on this device", and a joined
   phone (its own app's phone look) draw at 1.0, unchanged. An older phone build draws
   as it always did: it uses its own look and this change sends nothing over the wire.
   Tested by `arena_player_scale_test` for the three kinds of look and
   `arena_paint_test` ("a TV's look draws the marbles half again as big").
2. **Kept state.** None: the scale is a pure function of the look passed to the
   painter, with nothing held, timed or counted, so there is nothing to start or end.
   Tested by the same two tests.
3. **How it combines.** It is drawing only: pause, host away, player away, "Get ready",
   a dropped link, the results card drawn over the field, and leaving all draw the same
   look, so the scale is the same in each and touches no state. Not tested separately:
   there is no state to combine.
4. **Folder.** Wrote only `docs/briefs/m14/bugs3/a2-arena-size-report.md` and files
   under `packages/test_game/` — the job's allow list. The tree also shows three
   modified `tv_test_app/windows/flutter/generated_plugin_*` files: this job did not
   touch them — the suites rewrite them, as s1's report says (`s1-progress-bar-report.md`
   lines 46 and 74) — and they are still modified, so a `git add -A` carries them.
5. **Stop rather than overstep.** Not needed: the factor comes from data the painter
   already had, so no file outside `allow:` was required.

## Suggestions and questions

1. **The look decides, not the device kind.** `HostKind` (`tv`/`pc`/`phone`/`tablet`)
   would also work and is closer to "a TV"; I used the look because it is already in
   the painter's hand and needs no new plumbing. They agree today (the TV app sets both
   `toyTvProvider` true and `HostKind.tv`/`pc`). Say if `HostKind` is preferred and I
   will route it in (it needs a `game_screen.dart` split first).
2. **A PC host scales too** (Windows runs the TV app). If a desk PC should stay at 1.0,
   the TV flag would have to carry the distinction; it does not today.
3. **The start pad** stays 1.8 × the *rules* radius, so on a TV it now looks slightly
   tight around a marble. Grow it with the picture too, if the owner wants.
4. **Overlap.** As above: the picture (0.048) is larger than the collision radius
   (0.032). If marbles touching should keep looking touching, the alternative is to
   scale the rules radius — which the brief rules out.
5. **Not mine:** `git status` also lists `tv_test_app/windows/flutter/generated_plugin_*`
   as modified. Those are Flutter's generated plugin files, rewritten by the toolchain
   when the checks built `tv_test_app`; I did not edit them and left them as they are.

## Commit message

Arena: draw the marbles half again as big on a TV (B-014)

The owner: arena players look too small on a TV. A marble's drawn radius was a fixed
share of the field, so it shrank with the map as seen from the couch. The arena now
scales a marble's whole picture (body, face, accessory, coin count) by
`arenaPlayerScale(look)`: 1.5 in the TV's look, 1 in a phone's. The classification is
the look's own sizes (`ToySizes.tv` against `ToySizes.menu`), so no new flag, no new
parameter and no host screen changed; phone hosts and joined phones look as before.
Rules, collision radius and speeds are untouched. New test for the scale function and
one that the drawn marble is larger in the TV's look.

## Status row

B-014 done: the arena draws the character's picture 1.5× in the TV's look, 1× on a phone (arena 219, host 396, tv tests pass). Open: a device look on a TV and a phone host; whether the start pad should grow with the marble.

## Delete

- none
