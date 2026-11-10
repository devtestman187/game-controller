# M14 b3: Robo, the CPU marble — report

Job: docs/briefs/m14/b3-robo.md. Gate: the job's own end (`stop: after it`).

## What was built

### `CpuPilot` (party-night §7a, design table in `cpu_tuning.dart`)

One `GameInput` a step, played on the host from the game's own state:

- **Plans on a `MapGrid` path**: `cpuGrid(map)` builds the map's grid with its
  sliding movers blocked, then each look takes the shortest path to a reachable
  coin (`grid.path`). The previous coin is kept while its path is at most 1.3×
  the shortest, so two coins either side of a wall don't pull it back and forth.
- **Steers round hazards**: the aim is pushed away from every hazard within the
  level's berth (`hazardMargin` × the field's shorter side), harder the closer
  it is; hazards are read at each look, so Easy dodges 0.5 s late.
- **Never stuck**: it checks the step is free before taking it, backs onto free
  ground when it stands in a wall's berth, turns out after 1.2 s of not moving,
  and gives up on a coin it has circled for 1 s (never more than 2 s anywhere:
  measured below).
- **Seeded**: wobble and the way out of a corner come from `Random(roboSeed)`,
  so a round replays the same way (tested).
- **Never faster than a marble may go**: the move's length is the level's top
  speed times the distance left, never more than the rules allow (tested).

### The seat (design: "the rules don't know Robo is a CPU")

`ArenaSession` adds Robo's input to the same map the phones fill, under
`roboPlayerId`, when the round is the Bumper Round and has exactly one player
(`_roboIn`, `_pilot`). Robo's events are recorded with no player id and its
phone-less seat never gets a haptic. Every viewer merges a derived roster entry
(`arenaRosterFor`, `roboNumberFor`) so the marble and the host's cards draw the
same colour; the marble wears that colour with the antenna
(`arenaCharacterFor`); the HUD shows a robot head and "Robo".

### The host's cards

- Results: Robo's row (`arenaResultRow-robo`), the crown when it won
  (`arenaCrown-robo`), its coins (`arenaResultCoins-robo`), and the band says
  "Robo wins!" when it took the round.
- Waiting card: the same `RoboBadge` the results and the scoreboard draw.
- Scoreboard: Robo's row wears the robot disc and "Robo" (it can win the night,
  design: "It can win a round and the night, honestly"), and awards are people's
  alone (`decideAwards` only sees `NightState.seen`, tested).
- Joined phones: a win Robo takes is named "Robo" in the winners list.

## The levels' numbers (`CpuTuning`)

| | Easy | Medium | Hard |
| --- | --- | --- | --- |
| Reacts (`reactionS`) | 0.5 s | 0.3 s | 0.15 s |
| Top speed (`speedShare`) | 75% | 85% | 95% |
| Wobble (`wobbleRad`) | 0.45 rad | 0.2 rad | 0.05 rad |
| Hazard berth (`hazardMargin`) | 13% | 10% | 7.5% |

The design's "coins it goes for" and "shoves" rows are not separate numbers:
every level goes for the nearest coin it can reach (gold and dropped coins
aren't in the rules yet, see **Decisions** 9–10), and no level dashes.

## Per-map timings (seeds 1, 2 and 3, 60 s rounds)

| Map | Easy | Medium | Hard |
| --- | --- | --- | --- |
| Playroom | 0.10 s, 81 coins | 0.10 s, 110 | 0.08 s, 115 |
| Pinball | 2.27 s, 99 | 2.05 s, 125 | 1.88 s, 127 |
| Block Castle | 3.30 s, 12 | 2.85 s, 11 | 2.52 s, 14 |
| Toy Factory | 2.22 s, 90 | 1.72 s, 132 | 1.48 s, 157 |
| Spinning Tops | 2.15 s, 113 | 1.65 s, 192 | 1.52 s, 248 |
| **Total** | **395** | **570** | **661** |

The "s" is the slowest of the three seeds to its first coin. Longest time held
within a marble's diameter anywhere (the "stuck" measure): 0.75 s (Block Castle
on Easy), against the brief's 2 s bound.

Block Castle is the one map where a harder level is not always ahead over three
seeds (Easy 12, Medium 11): its keep gates are movers the grid blocks, so all
three levels lose coins behind them and the difference is noise. The levels are
ordered over the five maps, which is what the brief's test asks.

The test deadlines are 4.0 s (Easy), 3.5 s (Medium) and 3.0 s (Hard), a little
above the table's worst, so a slower machine or a changed map still reads as a
failure of the levels, not of the machine.

## Files changed

- `packages/test_game/lib/src/cpu_pilot.dart` (new): `CpuPilot`, `roboSeed`,
  `cpuGrid`, `step` and its planning, steering, escape and progress code.
- `packages/test_game/lib/src/cpu_tuning.dart` (new): `CpuTuning` (the table)
  and the pilot's steering constants; `cpu_pilot.dart` was 458 lines with them.
- `packages/test_game/lib/src/arena_robo.dart`: `roboNumberFor`, the next free
  player number every card and the roster ask for.
- `packages/test_game/lib/src/arena_roster.dart`: `arenaRosterFor` now asks
  `roboNumberFor`; new `arenaCharacterFor` (the marble's character, Robo's with
  the antenna).
- `packages/test_game/lib/src/arena_marble_painter.dart`: draws
  `arenaCharacterFor` instead of its own Robo branch.
- `packages/test_game/lib/src/arena_session.dart`: Robo's level, the seat
  (`_roboIn`, `_pilot`), its input in the step, and its records and haptics
  kept player-less.
- `packages/test_game/lib/src/arena_view.dart`: passes its `roboLevel` to the
  session and merges Robo into the board's roster.
- `packages/test_game/lib/src/arena_module.dart`: a viewer's board merges Robo
  into the roster (a joined phone draws it too).
- `packages/test_game/lib/src/arena_hud_widgets.dart`: Robo's HUD row is a
  robot head and its name.
- `packages/test_game/lib/src/map_grid.dart`: `blockMovers` (a map's sliding
  movers as walls) for the pilot's grid.
- `packages/test_game/lib/test_game.dart`: exports `cpu_pilot.dart` and
  `cpu_tuning.dart`.
- `packages/test_game/test/cpu_pilot_test.dart`: the pilot's tests (below).
- `packages/test_game/test/arena_robo_test.dart` (new): the free colour, the
  roster merge, the marble's character and the level table.
- `packages/test_game/test/arena_session_test.dart`: a "Robo's seat" group.
- `packages/test_game/test/arena_hud_test.dart`: Robo's HUD row.
- `packages/party_host/lib/src/ui/game_screen.dart`: passes the saved
  `roboLevel` to `ArenaView`.
- `packages/party_host/lib/src/ui/arena_results.dart`: Robo's row and
  "Robo wins!", both from the round's own lines and winners.
- `packages/party_host/lib/src/ui/player_badge.dart`: `RoboBadge`, drawn by the
  waiting card, the results and the scoreboard.
- `packages/party_host/lib/src/ui/arena_waiting_card.dart`,
  `arena_waiting_widgets.dart`: the waiting card's robot disc is the shared
  `RoboBadge` in the next free colour.
- `packages/party_host/lib/src/ui/night_scoreboard_screen.dart`,
  `night_scoreboard_widgets.dart`: Robo's scoreboard row (disc, name, points,
  crown).
- `packages/party_host/lib/src/night/round_results.dart`: a win Robo takes is
  named "Robo" on the phones' results.
- `packages/party_host/test/night_robo_test.dart` (new): the scoreboard row, the
  crown, and no award for Robo.
- `packages/party_host/test/arena_results_test.dart`: Robo's row and banner.
- `packages/party_host/test/arena_waiting_test.dart`: Robo's disc takes the next
  free colour.

## Tests

Failing first: the pilot and the seat did not exist before this job, so the
tests below could not compile before it; the ones that read the seat were also
run with the seat switched off (the input line guarded by `when false`) and the
two that need it failed ("a lone player's Bumper Round gives Robo a marble",
"Robo's play is no player's"), while the race and two-player tests passed, as
they should. The seat was put back and the whole file passed before anything
else ran.

- `cpu_pilot_test.dart` (8): Robo reaches a coin on all five maps within each
  level's time (three tests), Easy < Medium < Hard over seeded rounds, never
  held up for 2 s, the same seed plays the same round twice, never asks to move
  faster than a marble may, asks for nothing without a marble.
- `arena_robo_test.dart` (6): the free number; the roster merge; a frame without
  Robo leaves the roster; the marble's antenna; a player's character untouched;
  the level table's numbers.
- `arena_session_test.dart` (+4): a lone player's Bumper Round gives Robo a
  marble; a race never does; two players leave it no seat; no record and no
  haptic ever carries Robo's id.
- `arena_hud_test.dart` (+1): Robo's row is a robot head and its name.
- `night_robo_test.dart` (3): the scoreboard's row and points; Robo's crown on
  the final scores; no award ever names it (and a person still wins the award it
  beat them at).
- `arena_results_test.dart` (+1): Robo's row, crown, coins and "Robo wins!".
- `arena_waiting_test.dart`: the existing Robo test now also checks its disc's
  free colour.

Counts:

| Suite | Before | After |
| --- | --- | --- |
| arena (`test_game`) | 161 | 180 (+19) |
| host (`party_host`) | 359 | 363 (+4) |
| phone (`controller_app`) | 445 | 445 (untouched) |
| tv (`tv_test_app`) | 53 passed, 1 skipped | 53 passed, 1 skipped (untouched) |

## Checks

`tools/check.sh` and `tools/review.sh` were refused by this job's sandbox
("requires approval"), so their steps were run one by one:

- `dart analyze packages/test_game packages/party_host controller_app
  tv_test_app`: **No issues found**.
- `dart format --output=none --set-exit-if-changed -l 120` over `packages/`,
  `controller_app` and `tv_test_app`: **0 changed**.
- `flutter test --no-pub` in `packages/test_game`: **180 passed**;
  `packages/party_host`: **363 passed**; `controller_app`: **445 passed**;
  `tv_test_app`: **53 passed, 1 skipped**.
- `tools/review.sh`'s 400-line rule by hand: the longest library file this job
  touched is `cpu_pilot.dart` at 368 lines (458 before the split); the others
  are 36–309. No function is over 60 lines (the longest, `CpuPilot._look`, is
  45).
- Not checked: `git status`/`git diff` were refused too, so the working tree
  could not be listed. `test_game`'s `map_render_test` rewrites
  `docs/design/maps/*.png` whenever the full suite runs; its output is
  deterministic and no map or painter changed, so the files should be
  byte-identical, but this could not be confirmed here.

## Decisions (the brief's low-usage mode)

1. **Robo is a session-only seat id** (`roboPlayerId`), merged into the same
   inputs map as the phones': the rules, the frames and the clock know it as a
   seat and the host's player list never holds it (design: "the rules don't know
   Robo is a CPU").
2. **Its points and round wins count; its stats do not.** The night's totals
   take Robo's points and its wins, because design 7 says it "can win a round and
   the night, honestly"; its events are recorded with no player, it gets no
   haptics, and awards are decided from the night's `seen` people, so it never
   wins one (tested).
3. **One free-colour rule for every card.** `roboNumberFor` (the lowest number
   nobody has) feeds the viewers' roster, the waiting card, the results and the
   scoreboard, so the marble and every badge are the same colour (design: "the
   next free player colour"). The b2 waiting card drew slot 6; it now follows
   the same rule as the marble.
4. **One `RoboBadge` widget** for the waiting card, the results and the
   scoreboard: three cards that must not drift, and the b2 test's
   `Key('roboBadge')` still finds it.
5. **`arenaCharacterFor` moved the marble's character out of the painter**, so a
   test can read Robo's antenna instead of counting pixels.
6. **`MapGrid.blockMovers` blocks only sliding movers**, and `cpuGrid` uses it:
   Block Castle's keep gates and the Toy Factory's press are slides a plan must
   not cross (blocking them took the Toy Factory from 2 to 56 coins on Hard);
   swings and spins are left out because they leave a spot as fast as they come.
7. **The table and the steering constants are `cpu_tuning.dart`**: with them,
   `cpu_pilot.dart` was over the 400-line rule; the table is still one place to
   change a level.
8. **Hysteresis, stuck and progress constants** (`cpuKeepShare`, `cpuStillS`
   thresholds, `cpuEscapeS`, `cpuProgressS`, `cpuEscapeCells`, `cpuFreeCells`)
   are numbers the design's table doesn't have; without them the pilot
   ping-pongs round a wall or presses at a shut gate for the whole round. They
   sit beside `CpuTuning` for a device-tuning change.
9. **No dash.** Design 7a wants a dash toward a far coin and the odd shove; that
   is a rules-level behaviour (the shove, the 4 s/2 s limits, the aim at walls)
   that wants device tuning, and the brief's tests don't measure it. `CpuPilot`
   returns `GameInput` only, so `dash: true` is a one-line addition (question 1).
10. **Nearest reachable coin for every level.** Gold coins and dropped coins
    aren't in the rules yet (`ArenaCoin` has no worth; the field's coins respawn
    plain), so Hard's "gold first" and "coins others drop" have nothing to read
    (question 2).
11. **The seat is made once per session** (`_robo`, seeded) and reads
    `roboLevel` at construction; the waiting card's pick reaches the round
    because the game screen builds the session when the round starts. Whether
    Robo plays follows the round's own player set, fixed on its first step (b2),
    so a phone joining after that waits for the next round either way.
12. **The waiting card's Robo disc changes colour with the roster.** It used to
    be colour 6 whatever the players were; it is now the same free colour the
    marble wears (design 7a), which is the only visible change on b2's card.

## Questions and suggestions

1. Should Robo dash and shove? Design 7a's table has "Shoves: never seeks one /
   at most one every 4 s / at most one every 2 s" and a dash toward a far coin.
   It is a device-tuned feature of its own; the pilot today never dashes. I'd
   make it a small job after the device tests, and keep the level table's rows
   for it.
2. Gold coins in the last 15 s (design §7) aren't in the rules: `ArenaCoin` has
   no worth and every coin is the same. Once they are, Hard's row ("gold first
   in the last 15 s") is a filter in `_look` and a test.
3. The phones' round standings (`ViewStanding`) still name only players with a
   number, so Robo's row of the scoreboard has no line in the standings a phone
   shows. If it should, `ViewStanding` needs a "robot" form (a name and a colour,
   no number) — a protocol change, so it was left out.
4. `_name` in `round_results.dart` gives a win taken by Robo the name "Robo";
   nothing else in a phone's card knows about Robo. A phone that draws the
   standings from a frame could take the same name from its roster.
5. Block Castle's keep gates cost all three levels most of their coins (11–14
   over three rounds against 80–250 on the other maps). A map whose coins sit
   behind movers is a fair Robo map, but if the device tests find it dull, either
   the coins could move outside the keep or the gates' timing could widen.
6. `tools/review.sh`'s 400-line rule now catches `cpu_pilot.dart` first if the
   pilot grows; the escape and progress code is the part that could become
   `cpu_steering.dart` if it does.

## Self-check: docs/review-rules.md part A

1. **Every host setup.** TV/PC hosts and both phone-host modes run the same
   `ArenaView` and cards; the seat itself is in `ArenaSession`, which every
   host setup builds the same way (`arena_session_test`'s Robo group), and a
   joined phone draws Robo from the snapshot with the roster merge
   (`arena_robo_test`, `arena_view`'s board, `arena_module`'s viewer). A phone
   or host one build older: no protocol change (the snapshot stays v2), the
   older viewer draws Robo's marble with its number's default character and
   plays.
2. **When kept state starts and ends.** `_robo` starts on the session's first
   Robo step and lives as long as the session (seeded, so replays repeat);
   `_bumperPlayers` is the round's players, fixed on its first step as b2 set;
   the seat exists only while the mode is Bumper and that set has one id
   (tests: a race, and two players, leave no seat); with no players no seat is
   made, and nothing steps while the round is paused or over (the pilot is only
   called from `ArenaSession.step`).
3. **How a new state combines.** Robo adds no pause, input or lock: it shares
   the phones' input map and has no pad to release, so the pause menu, the host
   away, a player away and leaving are unchanged (`pause_menu_test`,
   `abandon_test`, the full host suite pass); the round's `_roboIn` reads the
   round's fixed players, so a phone joining mid-round cannot take the seat away
   (`arena_session_test` + b2's round-roster tests); `Pausable` stays the one
   owner of a round's pause and phase.
4. **Stay in the job's folder.** Only `docs/briefs/m14/b3-robo-report.md`,
   `packages/test_game/{lib,test}` and `packages/party_host/{lib,test}` changed.
   Running the full `test_game` suite also rewrites `docs/design/maps/*.png`
   (`map_render_test`'s known side effect, deterministic, no map or painter
   changed); `git` was refused here, so that no-byte-diff could not be confirmed
   (see **Checks**).
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`, and no
   rule had to be broken: `cpu_pilot.dart` passed 400 lines, so the table and
   the constants moved to `cpu_tuning.dart` inside the folder. The choices the
   brief and design left open are listed under **Decisions**.

## Commit message

Arena: Robo, the CPU marble, for a lone player's Bumper Round

Robo plays the second marble in a lone player's Bumper Round, steered by
CpuPilot on the host: MapGrid paths to the nearest reachable coin, hazards
given a berth, seeded wobble and escapes, and never faster than a marble may
go. Its three levels are one table (reaction, top speed, wobble, berth), and it
reaches a coin within each level's deadline on all five maps.

It is a seat of the session, not a player of the host: its events carry no
player and it takes no haptics, so stats and awards never count it, while its
points and wins count in a night. Its marble wears the next free colour and an
antenna, and the waiting card, results and scoreboard draw one robot badge in
that colour.

## Status row

M14 b3 done: Robo's seat in a lone player's Bumper Round, CpuPilot on every
map at Easy/Medium/Hard from one table, seeded for tests, its badge and name on
the host's cards and the scoreboard, points and wins counted and awards and
stats untouched; open: Robo's dash and shove, gold coins, and a robot form in a
phone's standings (questions 1–3).

## Delete

- none
