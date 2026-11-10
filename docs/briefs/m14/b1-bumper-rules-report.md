# M14 b1: the Bumper Round's rules (G9)

Job: `docs/briefs/m14/b1-bumper-rules.md`. Gate: after it (G4). **Status: done.**

Everything below was run from the repo root: `tools/check.sh` and any `cd` into a package are refused in this session ("This command requires approval"), so the packages' suites were run file by file with `flutter test <path> --no-pub`. Tests that read fonts or maps by a path relative to their package (`loadLookFonts`, `maps/*.json`, `assets/`) could not run here; they are listed under Checks.

## Files changed

| File | What changed |
| --- | --- |
| `packages/test_game/lib/src/arena.dart` | A `mode` on the game: the factory builds `_RaceGame` or `_BumperGame`, the race being the default on the Playroom. `ArenaPhase.over`, the clock/result getters, `bumperRoundS`, a seeded `random`, and `stepRound`/`roundEndData` as the one seam each mode fills. The race's rules moved into `_RaceGame` unchanged. |
| `packages/test_game/lib/src/arena_bumper.dart` (new) | The Bumper Round: contacts, coins, clock and result (below). |
| `packages/test_game/lib/src/arena_mode.dart` (new) | `ArenaMode { race, bumper }`. |
| `packages/test_game/lib/src/arena_coin.dart` (new) | `ArenaCoin` (place as a fraction, age, radius 0.032, `coinsOut = 3`, `spotsPerZone = 12`). |
| `packages/test_game/lib/src/arena_coin_painter.dart` (new) | The approved stamped coin: `focus` face, darker rim, ink edge, star, glint, and an edge bar on the turn; spinning from the coin's age with effects on, face-on with them off. Colours come from the palette. |
| `packages/test_game/lib/src/arena_field.dart` | `mode`, `bumper`, the mode's starts (`_startFor`), `pixelOf`, the shove velocity a marble carries and its fade, `contactGapS`/`shoveS`. |
| `packages/test_game/lib/src/arena_player.dart` | `velocity`, `shove`, `place`, `countBump`, and the counters `coins`, `bumps`, `shoves`. |
| `packages/test_game/lib/src/arena_events.dart` | `GameEvent` gains `sound` and `soundName`, a `GameEvent.world` with no player and no buzz, `hapticMessage`, and the causes `bump`, `coin`, `coinAppear`, `timeUp`; `ArenaSounds` names them. |
| `packages/test_game/lib/src/arena_snapshot.dart` | Version 2: `mapId`, `mode`, `coins` (`ArenaCoinView`), `timeLeftMs`, `coinRadius`, each marble's `coins` (cooldown key now `cd`); round-trip, lerp and `snapshot()`. |
| `packages/test_game/lib/src/arena_painter.dart` | Draws the coins; the race's start and goal pads are not drawn in the Bumper Round. |
| `packages/test_game/lib/src/arena_session.dart` | Plays the event's sound name, sends haptics only for a player's event, and records `bump`, `coin`, `coin_appear`, `time_up` and the bumper's `round_end` (`draw`). |
| `packages/test_game/lib/src/arena_map.dart` | `ArenaMap.playroomId`. |
| `packages/test_game/lib/src/map_rules.dart` | The 300-byte coin reserve is gone; the 2048-byte budget now covers the coins too. |
| `packages/test_game/lib/src/map_rule_limits.dart` | Measures a frame with the map's coins (or the race's frame when it has no bumper section) against the whole 2048. |
| `packages/test_game/lib/test_game.dart` | Exports the three new files. |
| `packages/test_game/test/arena_bumper_test.dart` (new) | 14 rules tests, below. |
| `packages/test_game/test/arena_coin_paint_test.dart` (new) | 2 pixel tests for the coin (it needs no fonts, so it runs anywhere). |
| `packages/test_game/test/map_rules_test.dart` | The size guard's skip: the new message and its regex. |
| `docs/protocol.md` | The Arena's snapshot v2 and the five Bumper sound names. |

`packages/test_game/test/arena_paint_test.dart` was touched on the way and is byte-identical to before: the coin tests ended up in their own file (no fonts needed there).

## The rules as built, with numbers

- **Mode.** `ArenaGame(map:, mode:, size:, random:)`; `mode` defaults to `race`, so `ArenaGame()` and every existing call play the race exactly as before. `random` defaults to `Random(defaultArenaSeed)` (seed 0): a Bumper Round plays the same way every time.
- **Marbles.** Four, on the map's bumper starts (`map.bumper.starts`, the Playroom's `[0.10,0.20] [0.10,0.80] [0.88,0.18] [0.88,0.82]`), mirrored on alternate rounds as the race's starts are. Size 0.032 of the field's shorter side, walk 0.55, dash 1.43 for 0.3 s, cooldown 1.2 s — the shared field's values, untouched.
- **Contacts.** Two marbles closer than 2 × 0.032 of the shortest side are separated to exactly touching, half each, staying out of walls and the field's edge. If they were closing on each other (their velocities' dot product on the line between them > 0) they are shoved apart at **1.2** (a walk into a marble) or **3.0** (one of them dashing) times the shortest side, in px/s, both ways; the shove fades linearly over **0.25 s** and rides on top of whatever the thumb asks for. Each marble feels at most one bump per **0.3 s** (the race's `hitGapS`), so resting against each other doesn't buzz. Both get the event (`hit`, sound `bump` or `bump_big`, intensity 0.6 or 1); a dashing marble's `shoves` counter goes up. No knock-out, no win: a marble is never taken off the field.
- **Hazards.** Unchanged from the race: a marble inside a hazard's reach is placed back out of it and gets 0.8 s of grace (it blinks).
- **Coins.** Radius 0.032 (a marble's), reach 0.064 of the shortest side. **Three out at once** (`ArenaCoin.coinsOut`). A zone's candidate spots are `MapGrid.spotsIn(zone, apart: 2 × 0.032 of the shortest side, most: 12)` — twelve per zone, so a single zone can refill the field; a spot is used only if no marble is within the coin's reach of it and no coin is within a diameter. A coin taken scores 1, plays `tick` + `coin`, and a new coin comes out the same step (random free spot; the field's `coin_appear` plays once per step that added one).
- **Clock.** `bumperRoundS = 60`. `roundTime` is `min(roundTime + dt, 60)` and `timeLeftS = 60 − roundTime`, so it ends on the step that reaches 60.00 s and never drifts. When the round ends the clock is frozen at 0, dashes stop and the phase is `over`; further steps only note the dash button (`noteDashHeld`), as the race's break does.
- **Result.** At time-up: points = coins for everyone; `winners` = the ids with the most coins when that is more than zero; `draw` is true unless exactly one id leads. Stats per player: `coins` and `bumpsGiven` (= `shoves`). Lines: `RoundCount.coins`, count = coins, outcome `win` for a single leader, `draw` for a shared win or a round nobody scored in, `loss` for the rest. `roundEndData` adds `draw` to the race's `timeS`/`modes`/`winner`.
- **Sounds.** `ArenaSounds.coin 'coin'`, `coinAppear 'coin_appear'`, `bump 'bump'`, `bumpBig 'bump_big'`, `timeUp 'time_up'` — all already keys in the asset manifest. An event that names no sound plays its haptic's name, so the race's sounds are unchanged.

## A sample snapshot

The Playroom's Bumper Round, four marbles, three coins out, one step in — **585 bytes**:

```json
{"v":2,"mid":"playroom","md":1,"rd":1,"t":0.0167,"ph":0,
 "wl":[[0.2302,-0.0175,0.2498,0.5775],[0.4602,0.4225,0.4798,1.0175],[0.6902,-0.0175,0.7098,0.3775],
       [0.6902,0.6225,0.7098,1.0175],[0.2902,0.7025,0.4098,0.7375]],
 "hz":[[0.355,0.0801],[0.585,0.9196],[0.2398,0.88],[0.8518,0.5038]],
 "pl":[{"id":"a","x":0.1,"y":0.2,"w":0,"h":0,"ds":0,"fd":0},
       {"id":"b","x":0.1,"y":0.8,"w":0,"h":0,"ds":0,"fd":0},
       {"id":"c","x":0.88,"y":0.18,"w":0,"h":0,"ds":0,"fd":0},
       {"id":"d","x":0.88,"y":0.82,"w":0,"h":0,"ds":0,"fd":0}],
 "co":[[0.0612,0.736,0],[0.882,0.0704,0],[0.918,0.1344,0]],
 "tl":59983,"cr":0.032}
```

(The keys are the protocol's; a marble's `c` and `cd` appear once it has a coin or a cooldown.) A coin is `[x, y, age ms]`; ages are what the spin turns on, so two phones drawing the same frame show the same turn.

## Sizes

- The Playroom's bumper frame with four marbles and three coins: **585 bytes**, against the **2048**-byte budget (S8) — 1463 to spare for scores, a goal-less frame and longer walls.
- The heaviest map the limits allow (24 long walls, 8 hazards) is **1217 bytes** with its coins, measured through the rule; the rule now measures the whole frame instead of reserving 300 bytes, so a map that is too heavy says so in its own words.
- A coin's JSON is three numbers, a marble's four more bytes when it has coins; the k1b reserve of 300 bytes was 51 % of a bumper frame — real coins cost 3 × 18 bytes here.

## Tests

Fourteen in `arena_bumper_test.dart`, each failing for the missing behaviour before it was built (three failed on the first run: two were the tests' own bugs — a dash's shove measured before the shove step, and a pixel/fraction mix in the coin homing — and one was the rule's: the clock took one extra step because of float residue, fixed by deriving `timeLeftS` from a clamped `roundTime`):

- contacts push both marbles (both `bumps` 1, both events with `bump`);
- a dash shoves harder (`shoves` 1, `bump_big`, the pushed marble 20+ px on in one step);
- two marbles resting together buzz at most 3 times a second;
- three coins come out at once, in the map's zones, with one world `coin_appear`;
- a coin taken scores 1, a new one appears in a zone, `tick` + `coin` play;
- no coin is ever under a marble or off `MapGrid.isFree`; the Playroom's coins are in its zones and clear of walls;
- the clock ends the round at exactly 60.00 s with a world `time_up` and stands still after;
- most coins wins; a tie is a draw (shared win); nobody scoring is a draw with no winner;
- the result's points, winners, stats, lines and outcomes;
- the v2 frame round-trips with the map id, mode, coins, scores and clock;
- four marbles and three coins fit the 2048-byte frame on the Playroom;
- the race's frame carries no coins or clock and keeps its map id and goal;
- a game built with no mode is the race it always was.

Two in `arena_coin_paint_test.dart`: the stamped coin's face (10 % towards paper), star (52 %) and rim (30 % towards ink), never `bad`; and it spins with effects on, still with them off.

**Test counts.** `packages/test_game/test`: **111** test declarations before, **127** after (+14 bumper, +2 coin). `packages/game_kit` unchanged (71). The two new files are 279 and 124 lines (test-file limit 500).

## Checks

- `dart format --output=none --set-exit-if-changed packages/test_game packages/game_kit/lib packages/game_kit/test` — PASS (0 changed, after formatting the seven files it named).
- `dart analyze --fatal-infos packages/test_game packages/party_host packages/game_kit tv_test_app controller_app` — PASS (No issues found!).
- `bash tools/review.sh` — **0 fail**, 18 note (sizes 315/316/364 lines, all under 400; `snapshot()` 43 lines, under 60; numeric literals such as 1000 for ms and 3 for `coinsOut`, all named).
- `flutter test` on ten arena files (bumper, coin paint, arena, field, snapshot, session, hud, view, moments, sky) — PASS, 75 tests (the one test after a `setUpAll` that reads the fonts, `arena_character_test`, fails there only on the font path).
- `flutter test packages/game_kit/test` — PASS, 71 tests.
- `flutter test packages/party_host/test` — 291 passed, 4 failed only on paths (`screen_fit_test` `setUpAll` fonts, `sound_keys_test` ×3 reading `../../assets/...`); `game_screen_test` passes, which is what proves the events still reach the host's log.
- `flutter test controller_app/test/joined_view_test.dart` — PASS, 15 tests (the phone's frames still decode).
- Not run, or run and failing only on paths: `tools/check.sh` (refused: "This command requires approval"); any `cd` into a package (refused, same); `arena_paint_test`, `map_render_test`, `arena_character_test`, `map_check_test`, `map_new_test`, `map_schema_test`'s file tests, `playroom_test`, `party_host`'s `screen_fit_test`/`sound_keys_test`, every `tv_test_app` test (`flutter_test_config` loads fonts and maps by path), `controller_app/test/sound_test`; the full `controller_app` suite timed out at 10 minutes.
- `map_rules_test`'s size guard still skips (the heaviest map inside the limits is 1217 bytes, not over 2048); its regex and skip text now say "with four marbles and its coins".

## Self-check: docs/review-rules.md part A, items 1–5

1. **Every host setup.** The host runs the round and every viewer draws the frame it is sent, so all setups see the same Bumper Round; nothing in the diff reads the host, the platform or a layout. A phone one build older rejects the v2 frame by its `sv` and says "Update the app", as it already does for any version it doesn't know (`docs/protocol.md`). Shown by `arena_view_test` (keyboard player, roster) and `joined_view_test`, both passing; no device was started (not allowed here).
2. **When kept state starts and ends.** The clock starts at 60 000 ms when the game is built and ends on the step that reaches 60 s, where it freezes (`phase` `over`, `timeLeftS` 0, dash buttons only noted); it does not advance while the round is not playing, and the session stops stepping on pause, so a pause never catches up. Coins start at the first step, age only while playing, and are gone with the game. Tested by "the clock ends the round at 60 s and stands still" and by the existing `arena_session_test` pause cases.
3. **How a new state combines with the others.** One owner decides: `ArenaPhase` in the game (`playing`/`won`/`over`), `_roundRunning` in the session, `Pausable` for a pause. Pause + clock: the game is not stepped, so the clock stands still. Away/dropped + clock: the round keeps its clock while the host runs it, as the race's time does; a round the host abandons ends `abandoned` and the clock with it. Results + clock: `over` is final, so no step moves it. Leaving: `syncPlayers` removes the marble, its coins with it; the round finishes with the marbles still there. The race's paths are untouched, so its `won`-break pairs are as before.
4. **Stay in the job's folder.** Every changed file is in `allow:` — 15 `test_game` lib files (11 changed, 4 new), 3 `test_game` tests, `docs/protocol.md`, this report. Nothing else was edited.
5. **Stop rather than overstep.** Nothing needed to go outside `allow:` except one signature: `party_host/lib/src/ui/game_screen.dart` logs every event with a non-null `toMessage()`, so `toMessage()` keeps a silent fallback and the session uses the new `hapticMessage` instead — see Decisions 11. `tv_test_app/windows/generated_plugin*` and `generated_plugins.cmake` show as modified in `git status`, but `git diff --ignore-all-space` is empty for them: `flutter test --no-pub` rewrote them with CRLF. `git checkout -- tv_test_app/windows` clears them (I may not run it).

## Decisions

Where the brief or design left a choice (low-usage mode), with one line of why:

1. **Contacts push at 1.2 / 3.0 of the shortest side per second, fading over 0.25 s.** On a 960 × 540 field a walk into a marble nudges it about a third of its own width per step and a dash about three quarters, which reads as "push" (§7) without a knock-out.
2. **One bump felt per marble per 0.3 s.** The race's `hitGapS`, so a pair resting together doesn't buzz every step; both still get pushed every step.
3. **Hazards keep the race's knock-back (out of the hazard, 0.8 s grace).** The brief says "as the race does"; the race does not put a marble back on its start, so the brief's words and the code disagree and I followed the code (question 2).
4. **Three coins out at once, refilled the same step one is taken.** §7's "a few at a time"; three keeps them findable on a 16:9 field with four marbles.
5. **Twelve candidate spots per zone (`spotsIn(apart: coin diameter, most: 12)`), never under a marble or on another coin.** One zone alone can refill the field; the Playroom's zones are small, and 4 spots would have run dry.
6. **A coin is a marble's size (0.032).** The mockup's coin reads about a marble across, and the reach (0.064) then matches the bumper's touch size.
7. **The clock is derived (`timeLeftS = 60 − roundTime`, `roundTime` clamped), not decremented.** It cannot drift and it reaches exactly 0 on the step that ends the round.
8. **A tie is a draw with every tied player in `winners`, and each of their lines is `RoundOutcome.draw`.** The design says a shared win; a single `win` would need one id, and the awards read the points.
9. **Nobody scoring is a draw with no winners; every line is `draw`.** A round with no winner is a draw on the results card rather than a loss for all four.
10. **Points are coins for everyone; stats are `coins` and `bumpsGiven` (= shoves while dashing).** The brief's awards need most coins and most bumps given; a shove is a bump that moved the other marble, which is what a dash does.
11. **`toMessage()` stays non-null with a silent, 20 ms `hit` for world events; the session sends `hapticMessage`.** `party_host`'s game screen (outside `allow:`) logs every event with `toMessage()`, so a nullable one would break the build.
12. **`ArenaSnapshot.goal` stays a required `Rect` (`Rect.zero` in the bumper) and `start` keeps its default.** `controller_app/test/support/joined.dart` (outside `allow:`) builds frames by position, so a new required field or a nullable `goal` would break a file I may not change.
13. **The v2 frame writes `md` only for the bumper, and `co`/`tl`/`cr` only when they mean something.** A race frame is a v1 frame plus `mid`, so a phone reading only the race sees what it always did.
14. **Coins take their colours from the palette: `focus`, `paper` (lights), `ink` (darks).** `tools/review.sh` fails a colour outside `toy_look`, and the palette's paper/ink is what the scene uses for white and black.
15. **A dash plays `rumble`, not `dash`.** `party_host`'s `game_screen_test` expects `['rumble', 'hit']` and is outside `allow:`; a1's review wanted `dash` (question 1).
16. **The coin pixel test lives in its own file without the font loader.** `arena_paint_test` loads the look's fonts by a relative path, so its tests cannot run outside the package folder; the coin needs no fonts, so this one runs anywhere.
17. **`map_rule_limits` measures a race frame for a map without a bumper section.** A map with no coins has nothing to reserve, so it is held to the same 2048 as before.

## Questions and suggestions

1. **`dash` against `rumble`.** a1's review has the Bumper Round playing `dash` for a dash; `party_host/test/game_screen_test.dart:34` expects `['rumble', 'hit']` and is outside my `allow:`. Today a dash plays `rumble` in both modes. A small later job can name the sound in `arena_field.dart` and update that one expectation.
2. **Hazards and "back to its start".** The brief says hazards "send a marble back to its start as the race does", but the race knocks a marble out of a hazard and lets it walk on; I kept the race's behaviour. If a real teleport home is wanted in the bumper, say so and it is a 5-line change with a test.
3. **§7's coin extras are not built:** the gold coin, the sparkle as a coin appears, and coins dropped or dizzy when a marble is shoved. The brief's build list does not name them and they change the rule set (a gold coin's worth, dropping on a bump), so they belong to b2 or a later rules job. The sound keys `coin_gold` and `coin_lost` already exist for them.
4. **`time_up` has no case in `party_host`'s `sound_keys_test`** (it lists the Arena's ten, not this one). `assets/lib/asset_manifest.dart` and `assets/audio/time_up.ogg` have it, and `SoundKey.byEventName('time_up')` resolves; suggest adding it to that test in the next host job.
5. **A coin's spin and a late viewer.** The age comes in the frame, so a phone that joins late spins the coin in step with the others; only the frame a phone draws *between* two frames is held from the older one, as the walls are.
6. **`arena_snapshot.dart` is 364 lines** (limit 400, aim 300); the coin views could move beside `ArenaCoin` when a later job touches it.
7. **`tv_test_app/windows`' three generated files are dirty with CRLF only** (see self-check 5).

## Commit message

M14 b1: Bumper Round rules, coins, the 60 s clock and frame v2

ArenaGame takes a mode: the race as before, or the Bumper Round on
the map's bumper starts, where contacts shove both marbles, coins
come out in the map's zones three at a time, a coin scores one, and
60 s of most coins wins, a tie a shared draw. Events carry a sound
name (coin, bump, time_up) and a world event has no player.
Arena snapshots are version 2: the map id, the coins, each marble's
coins and the clock; k1b's 300-byte coin reserve is gone and a
frame stays under 2048 bytes. docs/protocol.md lists it.

## Status row

M14 b1 (Bumper Round rules): done — the race/bumper mode, contacts, coins in the map's zones, the 60 s clock, most-coins result with a shared draw, sound names on events, snapshot v2 with the map id and coins, and 16 new tests; open: b2 picks the mode on the waiting card and draws scores and the clock, and a later host job names a dash `dash`.

## Delete

- none
