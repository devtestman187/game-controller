# M16 identity1 i1f report: the Arena draws players by their chosen character

## Summary

- Tests first: NEW `packages/test_game/test/arena_identity_test.dart`, 8 tests, each in the menu
  look and the TV look. They fail on the old code (the `characters` parameter and
  `arenaCharactersOf` don't exist, `arenaCharacterFor` takes no characters).
- `arena_roster.dart`: `ArenaRoster`'s type is unchanged; NEW `ArenaCharacters`
  (`Map<String, PlayerCharacter>`), `arenaCharactersOf(host.players)` (only the players who chose
  one), and `arenaCharacterFor(roster, id, {characters})` now reads `ToyCharacter.of(characters[id],
  number)` and falls back to the number's default only when missing. Robo keeps the next free
  number's colour with the antenna.
- Threaded `characters` beside `roster`, as an optional map so every existing call site and test
  compiles unchanged: `ArenaBoard` → `ArenaHud` and `ArenaField` → `ArenaPainter` →
  `ArenaMarblePainter`; `ArenaView` fills it from `arenaCharactersOf(widget.host.players)`.
- The HUD dot is `character.colourIn(colours)` instead of `colours.player(player.number)`; the
  winner's band is the winner's *character* colour (the one its marble wears), `good` unchanged
  when no player won.
- `_PlayerRow`'s parameters went from 7 to 5 (its four layout flags are one `layout` record), so
  the extra character didn't add to a count already over the guideline's five.
- Tests seen: `tools/mine.sh` → ok (16 tests, 8 of them the new file);
  `tools/check.sh format analyze arena` → PASS (248 tests, the suite is named `arena`).

## Files changed

- `packages/test_game/lib/src/arena_roster.dart`: `ArenaCharacters` typedef,
  `arenaCharactersOf`, `arenaCharacterFor` takes the chosen characters and falls back per player.
- `packages/test_game/lib/src/arena_marble_painter.dart`: an optional `characters` map, passed to
  `arenaCharacterFor`.
- `packages/test_game/lib/src/arena_painter.dart`: an optional `characters` map, passed to the
  marble painter.
- `packages/test_game/lib/src/arena_view_widgets.dart`: `ArenaBoard` and `ArenaField` take
  `characters`; the board passes it to the bar and the field; the winner's band uses the winner's
  character colour.
- `packages/test_game/lib/src/arena_hud_widgets.dart`: `ArenaHud` takes `characters`; `_PlayerRow`
  takes the resolved `ToyCharacter` and a `layout` record; the dot wears the character's colour.
- `packages/test_game/lib/src/arena_view.dart`: passes `arenaCharactersOf(widget.host.players)`.
- `packages/test_game/lib/src/arena_module.dart`: doc note only — a frame's `chars` don't reach a
  `ViewContext`, so the joined phone still draws defaults (question 1).
- `packages/test_game/test/arena_identity_test.dart`: NEW, the 8 tests below.

## Decisions

- The host path carries the characters (`GamePlayer.character`); the joined-phone path can't yet,
  because `ViewContext` has no `chars` (question 1). So the change is complete on the TV and the
  phone-host screen, and the viewer keeps drawing defaults, as it does today.
- `characters` is an optional named map everywhere, so no test that builds a roster or a board
  needed an edit, as the brief asked.
- The winner's band follows the character colour: "identity shows everywhere players are drawn",
  and the band is the winner's own colour next to its marble. No-behaviour-change guard: with no
  characters it is `player(number)`, the old value (`arena_hud_test`'s two banner tests, green).
- `arenaCharactersOf` uses a null-aware map element (`p.id: ?p.character`), so a player with no
  choice adds no entry.
- The HUD's private `_PlayerRow` would have reached 8 parameters; its four layout flags are now one
  record with a doc comment, so it is at the guideline's 5.

## Computed test values

- Chosen character: colour slot 5 (Pink) + crown; player 1's default: slot 1 (Blue) + ears.
- Marble radius: 0.05 × 540 = 27 px in the menu look; 27 × 1.5 (`tvPlayerScale`) = 40.5 px on the
  TV.
- Body sample: 0.4 × radius below the middle → y = 324 + 10.8 = 334.8 (menu) and 324 + 16.2 =
  340.2 (TV); in the fallback's bands of `player(5)` and *not* of `player(1)`.
- Accessory band: y from −1.5 to −0.9 radii, x ±0.8 radii (the crown's points reach 1.38 radii up,
  its valleys sit at −0.88, per `toy_look`'s `crownPoints`): share with a slot-5 crown reference
  > 0.95, with player 1's ears < 0.5.
- Crown paper point: 1.15 radii above the middle (y = 293.0 menu, 277.4 TV): within 30 of the
  look's `paper`, where a player with no choice draws the field.
- Default band (as `arena_character_test`): y −1.85 to −1.05 radii, x ±2 radii: ears > 0.95,
  antenna < 0.5, with no characters given.
- Robo: number 2 → `ToyCharacter(colourSlot: 2, accessory: antenna)`, dot `player(2)`, while the
  player's dot is `player(5)`.
- `arenaCharactersOf([a with slot 5 + crown, b with none])` = `{'a': chosen}` (one entry);
  `arenaCharacterFor` gives `b` `ToyCharacter.forPlayer(2)`.
- Winner's band: `player(5)` in both looks.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** TV and phone-host: `ArenaView` passes the host's players' characters —
   `arena_identity_test` "the host's players give only the characters they chose…" plus the board
   and field tests. Joined phone and "Show on this device": `ArenaViewer` gets no `chars` from
   `ViewContext`, so it draws the number's default exactly as before (question 1). A peer one build
   older: nothing on the wire changed in this job.
2. **Kept state.** None added: the map is rebuilt from `host.players` each frame (or from the
   frame's `chars` once a viewer gets them), and a player missing from it wears the default, so
   there is no state to start or end and nothing happens when nothing is going on.
3. **With the pause menu, host away, a player away, "Get ready", a dropped link, results,
   leaving.** The characters come from the host's live players on each build, so none of those
   change them; a player who leaves drops out of the roster and the map together; a player whose
   choice isn't known falls back to their number's colour; the results' banner takes the winner's
   character ("the winner's band is the winner's chosen colour"); Robo is never in the map and keeps
   the next free number's colour ("Robo keeps the next free number's colour…").
4. **Job folder and `allow:`.** Only the seven allowed lib files, the one allowed new test file and
   this report changed. (`docs/briefs/m16/identity1/DRIVER-NOTES.md` and `run.log` are the driver's
   own changes in this worktree, not mine.)
5. **Stop rather than overstep.** `packages/game_kit/lib/src/game_module.dart` (`ViewContext`) is
   outside `allow:`, so the joined phone's characters wait for a job that owns it (question 1);
   named, not edited. `arena_module.dart` documents the gap.
6. **Every look.** Both the menu look (`support/look.dart`'s `sunny`, tv false) and the TV look
   (`ToyLook.build(palette: ToyPalette.sunny, tv: true)`) run every changed drawing: marble colour,
   marble accessory, the default player, the HUD dot (chosen and default), Robo's dot, and the
   winner's band. No look-sized widget got a fixed pixel height.

## Questions

1. **`ViewContext` has no characters.** `packages/game_kit/lib/src/game_module.dart:69` carries
   roster, player, pads and density, but not a frame's `chars`; game_kit is in no job's `allow:` in
   this wave, so a joined phone (and a phone on "Show on this device") still draws number defaults.
   Which job adds a `characters` map to `ViewContext` and passes it in `frame_view.dart`'s build?
2. `tools/check.sh` has no suite named `test_game`; the package's suite is `arena` (`--list`). I ran
   `format analyze arena`. Confirm the runner maps the brief's name.
3. `ArenaPainter` and `ArenaMarblePainter` now take 6 constructor parameters (roster and characters
   side by side), one over the guideline's five. Bundling them in one value object would change the
   positional `roster` arguments in `map_flags_test`, `map_picture_test`, `support/map_sheet.dart`
   and party_host's `look_midgame_test`, all outside `allow:`. Is a cast value object wanted in a
   later job?
4. I changed the winner's band to the winner's character colour (it was `player(number)`). Confirm
   that is the intent; if the band should stay on the number, it's a two-line revert plus the one
   test.

## Suggestions (not acted on)

- Have `ViewContext` carry the frame's characters so the Arena's viewer line reads
  `characters: view.characters` and every screen agrees without a second lookup.
- An `ArenaCast` value object (roster + characters) would bring both painters back to five
  parameters and give one seam for the viewer's two maps.
- `arenaCharactersOf` gives the host's side; the frame's `chars` decodes to the same shape
  (`Map<String, PlayerCharacter>`), so the two paths could share one type once the viewer gets them.

## Hand-over

- The joined phone needs `ViewContext.characters` (game_kit) and `ArenaViewer` to pass it; the
  Arena's painters, bar and banner already take it.
- Robo's rule is unchanged: next free number's colour, antenna, never in the characters map.
- The marble, the dot and the winner's band now all ask `arenaCharacterFor`, so any later change of
  a player's look has one place to change.

## Commit message

arena: draw players by the character they chose

Add ArenaCharacters and arenaCharactersOf so the roster carries each
player's chosen character beside their number and name.
arenaCharacterFor reads the choice and falls back to the number's default
only when missing; Robo keeps the next free number's colour and antenna.
Thread the map through the board, bar, field and painters; the HUD dot and
the winner's band now wear the player's own colour.
The host screen fills it from the host's players; a joined phone keeps the
defaults until a ViewContext carries the frame's chars.
Eight new tests draw a slot-5 crown player in the menu and TV looks.

## Status row

| identity1 i1f | done: Arena marble, HUD dot and winner's band wear the character each player chose, on the TV and the phone host (roster + optional characters map, Robo unchanged); tests 8 new, arena 248 green | open: `ViewContext` carries no characters, so a joined phone still draws number defaults (game_kit outside this job's allow) |

## Delete

- none
