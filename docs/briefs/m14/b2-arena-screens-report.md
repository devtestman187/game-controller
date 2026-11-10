# M14 b2: the Arena's screens — report

Job: docs/briefs/m14/b2-arena-screens.md. Gate: G4 (after it); stopped there.

## What was built, screen against its frame

Frame numbers are docs/design/party-mockups.html's (the m14-night-\*.png set);
design section numbers are docs/design/party-night.md's.

### The Arena's waiting card (frame 8, design section 8)

`ArenaWaitingCard` + `part` widgets, drawn over the still sky inside
`GameScreen` while its stage is `waiting`:

| Frame 8 shows | The card |
| --- | --- |
| Paper card titled "Arena", 940 px wide | `ToyCard` with the Arena's header colour, `Key('arenaWaitingCard')`, the same width as the results card, so the two don't jump |
| The pairing code | `Code` and the four digits, `Key('arenaCode')` |
| Each joined phone: badge, number, nickname, ✓/✗ | `_PlayerRow` per player: `PlayerBadge`, "P1 Mia", a ✓ disc or a ✗ until then; tapping a row readies that player |
| "Press A when you're ready." | `ArenaText.ready`, with the same line for every joined phone |
| Bumper / Race buttons, Bumper lit | `HostButton`s `Key('arenaMode-bumper' | 'arenaMode-race')`, the chosen one in its colour; a night passes `bumperOnly` and shows Bumper alone |
| The maps as small cards with their pictures, then "Surprise me" | `_MapCard` per map of `ArenaMapLibrary` playable in the chosen mode (260 × 146, 16:9), `ArenaMapPicture` drawing the map's own `ArenaSnapshot`, a tick on the chosen one; `_SurpriseCard`, chosen when the settings hold no map id |
| — | Cards wrap three, two or one across, as the frame's three-in-a-row does on a narrower screen |

Only `playroom.json` has a `race` section, so Race offers the Playroom alone
and Bumper offers all five, as design section 7b says a map that leaves out a
mode is only offered for the other. The map picture is the round's own start
field, built by `ArenaMapPicture.fieldOf`, so the picture can't drift from play.

### The waiting card with Robo (frame 9, design section 7a)

With exactly one joined player and Bumper chosen, a Robo line appears under the
mode buttons: a robot badge (`Key('roboBadge')`), "Robo" and "joins you", then
Easy / Medium / Hard (`Key('roboLevel-easy' | …-medium' | …-hard')`), the
chosen one ticked. Picking one stores it in `arenaSettingsProvider`. There is no
Robo seat in the round yet: the level is one named place b3 reads
(`RoboLevel` in `arena_robo.dart`, `arenaSettings.roboLevel`), as the brief
asks. Race, or two joined players, takes the line away.

### The 3-2-1 before an Arena round, on the TV too (design section 8)

`Pausable` gained an optional `beat`; the Arena passes `Pausable.ready` (3 s), so
the countdown runs on a TV host as well as a phone host, whatever the host's
`readyCountdownProvider` says. The field, the pause menu, the host away and the
start grace are unchanged once the round plays.

### The Bumper Round's field and music (frame 10, design section 7)

The field is `ArenaView` under `Pausable`, as before; it now reports its clock
(`onClock`) and its result once (`onFinished`). `MusicLoop` gained `arena`,
`arenaHurry` and `arenaFinal` (`arenaHurryS` 15, `arenaFinalS` 5) and
`forArena`; `HostMusic.roundScreenOpened(this, arena: true)` makes the screen's
round play that trio by the Bumper Round's clock, the race's staying on `arena`
with no clock to hurry it. A tempo change cross-fades at the same share, and
the results fade the round out, as Shape Race's do.

### The results card (design section 7, Shape Race's card as the mock-up)

`ArenaResults` under `Key('arenaResults')`, 640 px wide (narrower than the
waiting card, like Shape Race's results):

- the header names the winner in their colour ("P1 Mia wins!") or says "Draw!"
  (`Key('arenaResultTitle')`); a tie or a round nobody scored in is a draw;
- a row per player: badge, number and nickname, the winner's crown
  (`Key('arenaCrown-…')`), the coin icon and "7 coins" / "1 coin"
  (`Key('arenaResultCoins-…')`);
- a player with no line this round (joined too late) gets "P2 Sam joins next
  round" (`Key('joinsNextRound-…')`) instead of a row;
- Play again (`Key('arenaAgain')`, focused for the remote's OK and a phone's A) /
  Change mode (`Key('arenaChangeMode')`) / Back (`Key('arenaResultsBack')`), or,
  in a night, Next alone (`Key('next')`).

Play again builds another round on the same map and mode; Change mode returns
to the waiting card with its picks kept; Back leaves for the game picker. In a
night, Next records the round (`recordRound`) and pushes the scoreboard with
`pushAndRemoveUntil(..., isGamePickerRoute)`.

### The night's Bumper Round (design section 2 N6, section 8)

`nightBumperRoundReady` is true. The start card's Bumper Round button and the
scoreboard's start the night (`partyNightProvider.notifier.start`) and open the
Arena, as Shape Race's rounds do through their pick and join screens. The
night's card shows Bumper alone; a round it starts is built with
`ArenaMode.bumper`, at `nightPointsScale` (1) or `lastRoundPointsScale` (2) when
`isNextRoundTheLast`, and its `RoundResult` (coins, plus `bumperWinBonus` 5 for
each winner, scaled) records into the night on Next.

### The sounds and the words

No sound keys were added: b1's `arena`, `arena_hurry` and `arena_final` (and the
coin and bump sounds) are the ones the round plays. The Arena's words live in a
new `ArenaText` (waiting card, Robo, "joins next round", "Change mode", coins,
wins), as the night's live in `NightText`, because `HostText` is near its 400
lines. The old unused `HostText.arenaHint` / `arenaHintKeyboard` are gone.

### D-pad, A and B on every new screen

- On the waiting card: A readies the phone's player (a second press lets go of
  ready), B leaves the Arena (`Key` handling in `ArenaWaitingCard._tick`, reading
  the pad itself while `Controls.game()` is claimed — the phone shows no menu).
- On the results: the controls claim switches to `Controls.menus()`, so A/OK
  presses the focused button and B/Back goes back (which, in a night, records
  the round first), as the other results screens do.
- The remote: the card opens with its chosen mode button focused (frame 8 draws
  it lit), then the arrows walk the card's buttons; OK presses. The screen's own
  focus takes the round back as it starts, so the keyboard player and Escape keep
  working during play.
- On the host's own player (a keyboard or a phone on "Play on this device"): it
  readies like any other, with a press; a simulated controller is ready at once,
  since nobody can press for it.

## Files changed

Library:

- `packages/party_host/lib/src/arena_settings_provider.dart` (new): the Arena's
  maps as a provider and `ArenaSettings` (mode, map, Robo's level, last map),
  saved in the host's prefs.
- `packages/party_host/lib/src/text/arena_text.dart` (new): the Arena's words,
  beside `HostText` and `NightText`.
- `packages/party_host/lib/src/ui/arena_waiting_card.dart` (new): the card's
  state — pads read for A and B, ready set, starts when all are ready — and its
  layout.
- `packages/party_host/lib/src/ui/arena_waiting_widgets.dart` (new, part): the
  player rows, the mode buttons, Robo's line, the map cards and Surprise me.
- `packages/party_host/lib/src/ui/arena_results.dart` (new): the Bumper Round's
  results, winner or draw, rows with coins, and Play again / Change mode / Back
  or Next.
- `packages/party_host/lib/src/ui/game_screen.dart`: the round's three stages;
  builds the game from the card (and the night's mode and scale); the beat; the
  clock and result hooks; focus taken back for the round; Next records.
- `packages/party_host/lib/src/ui/game_debug_overlay.dart` (new): the debug
  overlay, the "no controller" note and their constants, moved out to keep the
  screen under 400 lines.
- `packages/party_host/lib/src/music_loop.dart`: the Arena's `arena`,
  `arenaHurry`, `arenaFinal` and `forArena` (15 s, 5 s).
- `packages/party_host/lib/src/ui/lobby_music.dart`: an Arena round plays the
  Arena's piece by its clock; `roundScreenOpened(arena: true)`.
- `packages/party_host/lib/src/ui/pause_menu.dart`: `Pausable.beat`, so the
  Arena's 3-2-1 runs on a TV host too.
- `packages/party_host/lib/src/night/party_night.dart`: `nightBumperRoundReady`
  true.
- `packages/party_host/lib/src/ui/night_start_screen.dart`: the Bumper Round
  button starts the night before opening the Arena.
- `packages/party_host/lib/src/ui/night_widgets.dart`: the buttons' doc says the
  Bumper Round is live.
- `packages/party_host/lib/src/providers.dart`: exports the Arena's settings.
- `packages/party_host/lib/src/text/host_text.dart`: the two unused Arena hints
  removed (their words are `ArenaText`'s now).
- `packages/party_host/lib/party_host.dart`: exports `ArenaText`,
  `ArenaResults` and `game_debug_overlay.dart`.
- `packages/test_game/lib/src/arena.dart`: `bumperWinBonus` (5) and
  `pointsScale` on the game and its result's points.
- `packages/test_game/lib/src/arena_bumper.dart`: a round's points are
  (coins + the winner's bonus) × `pointsScale`.
- `packages/test_game/lib/src/arena_session.dart`: the Bumper Round's roster is
  fixed at its first step, so a player who joins mid-round waits and their pad
  still shows the round.
- `packages/test_game/lib/src/arena_view.dart`: `onClock` every frame with a
  clock and `onFinished` once with the result.
- `packages/test_game/lib/src/arena_robo.dart` (new): `RoboLevel`, its saved
  names and the place b3 reads the level from.
- `packages/test_game/lib/src/arena_map_picture_widgets.dart` (new): the map's
  picture over the round's start field, as a look-drawing widgets file.
- `packages/test_game/lib/src/arena_map_picture.dart`: one-line re-export of the
  above; listed under **Delete**.
- `packages/test_game/lib/test_game.dart`: exports Robo's level and the picture.

Tests: `arena_waiting_test.dart`, `arena_results_test.dart` and
`arena_night_test.dart` (new); `arena_bumper_test.dart`, `round_music_test.dart`,
`game_screen_test.dart`, `support/host_harness.dart`, `abandon_test.dart`,
`host_focus_ring_test.dart`, `pause_menu_test.dart`, `night_screens_test.dart`,
`party_night_test.dart` and `screen_fit_test.dart` changed (below).

## Tests

Each test was written first and failed for the missing behaviour (the failures
were the missing card, the missing results, the missing night wiring, the
`Soon` button and `nightBumperRoundReady == false`).

New, `packages/party_host/test`:

- `arena_waiting_test.dart` (8): the card's contents, the code and the two
  ready marks; a phone's A readies it and the round starts when every phone is;
  the remote's focus (the card's chosen mode is `FocusManager`'s primary focus,
  arrow right reaches Race, select picks it and the snapshot says `race`); the
  map picked is the map the round plays (`pinball`); Surprise me picks another
  map than the last played; one player in Bumper brings Robo and Hard is stored,
  Race takes him away; B leaves; the TV's 3-2-1 ("3" is up, then gone).
- `arena_results_test.dart` (5): each player's coins, the winner's crown and the
  three buttons; the draw (`'Draw!'`, no crown); "joins next round"; Play again
  and Change mode call back, and "1 coin" is singular; a night's Next alone,
  which records.
- `arena_night_test.dart` (4): the night's Bumper button starts the night and
  opens the card with Bumper alone; Next after the clock runs out records round
  1 and shows "Round 1 of 3"; a round before the last has `nightPointsScale`
  (1); the night's last round has `lastRoundPointsScale` (2).

Changed:

- `arena_bumper_test.dart`: the result's points carry `bumperWinBonus` 5
  (`{'a': 2 + 5, 'b': 1, …}`), and a new test plays a `pointsScale: 2` round:
  `{'a': (2 + 5) * 2 = 14, 'b': 2, 'c': 0, 'd': 0}`, with the line's count still
  2 coins.
- `round_music_test.dart`: the Arena's race plays `arena` and never hurries; the
  Bumper Round plays `arena`, `arena_hurry` at 14.9 s left and `arena_final` at
  4.9 s; the results fade the round out.
- `game_screen_test.dart`, `support/host_harness.dart`: `openArena` is now
  card → `readyUp` → `roundStarted`; `openArenaCard` stops at the card; the
  harness hands in `testMaps()` and gained `arenaSnapshot(tester)`; `readyUp`
  releases A first, because the card readies a phone on a press of its own.
- `abandon_test`, `host_focus_ring_test`, `pause_menu_test`, `screen_fit_test`
  follow the new `openArena(tester, fake)`; `screen_fit_test` also checks the
  card itself fits at each look.
- `night_screens_test`: the night's Bumper button is enabled and "Soon" is gone.
- `party_night_test`: `nightBumperRoundReady` is true.

Counts (tools/check.sh):

| Suite | Before | After |
| --- | --- | --- |
| arena (`test_game`) | 160 | 161 (+1) |
| host (`party_host`) | 321 | 340 (+19: 8 waiting, 5 results, 4 night, 2 music) |
| phone (`controller_app`) | 445 | 445 (untouched) |
| tv (`tv_test_app`) | 53 passed, 1 skipped | 53 passed, 1 skipped (untouched) |

format and analyze are clean at 120 columns.

## Decisions (the brief's low-usage mode)

1. **The card opens on Bumper.** Frame 8 draws Bumper lit and all five maps;
   only the Playroom has a `race` section, so a Race default would open the card
   on one map. `ArenaSettings.defaults` therefore starts in Bumper, on Surprise
   me, with Robo on Easy (design 7a's "Easy the first time").
2. **A phone readies on a press of its own.** The A that joined a phone was
   pressed for the join screen; the card skips each phone's first sighting and
   only counts a new press, so nobody is started into a round by a finger that
   was already down (and the TV app's sample pad keeps its behaviour).
3. **A simulated controller is ready at once.** Nobody can press for one, and
   the widget tests' local pad is simulated.
4. **The host's own player readies like a phone.** A keyboard player or a phone
   host's thumb presses A; nothing starts a round without a press.
5. **A night's card starts on Surprise me.** It passes `surpriseFirst` unless the
   host picks a map on that card. Design 7b wants a map the night hasn't used;
   `NightState` has no set of used maps yet, so the safest stand-in is the map
   the last round played (`ArenaSettings.lastMapId`). Written down as question 1.
6. **Results outside a night offer Play again / Change mode / Back**, as Shape
   Race's card does; in a night they are Next alone (design section 2 N6).
7. **The Arena's words live in `ArenaText`.** `HostText` is at 357 lines and
   the brief asks for a new file near the old ones' limit; the two unused hint
   lines it had are removed rather than moved.
8. **The card asks for the focus after its first frame.** The game screen's
   `Focus(autofocus: true)` wins over a descendant's, so the card requests its
   chosen mode's button once drawn (frame 8 shows it lit); the round requests the
   screen's own focus back in `_start` and `_again`, so the keyboard and Escape
   keep reaching it.
9. **The map picture lives in a widgets file.** `tools/review.sh`'s layers rule
   only lets a file named painter/view/widgets/module import `toy_look`;
   `ArenaMapPicture` draws with the look, so it is in
   `arena_map_picture_widgets.dart` and the old `arena_map_picture.dart` is left
   as a one-line re-export to be deleted (see **Delete**).
10. **`DebugOverlay` moved out of `game_screen.dart`.** The screen's three
    stages took it past 400 lines; the overlay, the note and their constants
    are in `game_debug_overlay.dart`, still exported from the package.
11. **`ArenaSession` fixes the Bumper Round's roster on its first step.** A
    player who joins during the round gets the frame stream and their pad (their
    own result card says they wait), but no marble until the next round; the race
    keeps joining at once, as design section 8 says.
12. **The night's scale reaches the game, not the card.** `ArenaGame` gained
    `pointsScale`; the coins the card counts are the ones won (`count`), the
    points (coins + winner's 5, scaled) are the night's, as N3 says.

## Questions and suggestions

1. `NightState` remembers rounds and points, not maps. If design 7b's "a map it
   hasn't used yet" should hold over a whole night, it needs that set; today
   Surprise me only avoids the last round's map (decision 5).
2. The layers rule in `tools/review.sh` could accept a `*picture*` name (or
   `*card*`), which would remove the need for the shim file listed under
   **Delete**.
3. Robo's level is stored and shown; the CPU seat is b3's. The session today
   steps only joined phones' marbles, so a lone player in a Bumper Round plays
   alone over a full clock. This matches the brief ("Robo's seat itself is job
   b3"), but a night started from b2's night screen before b3 lands will look
   quiet for one player.
4. `Pausable.beat` is the first thing a round can set for itself; if Shape Race
   ever wants its own beat, the same field serves it.
5. The `tv_test_app` generated Windows plugin files show line-ending-only diffs
   in `git status` on this machine. They are not from this job (no Dart changed
   there) and were left alone.

## Self-check: docs/review-rules.md part A

1. **Every host setup.** TV/PC and both phone-host modes run the same card (no
   host-specific branch; the card reads every pad through the host, and
   `screen_fit_test` mounts the card at each look); a joined phone readies with
   A, leaves with B, and sees its own result from `showResults` (`arena_waiting_test`,
   `arena_results_test`); a build one older is unaffected (no protocol change; the
   snapshot stays v2 from b1, so a phone too old shows the update text as N11 says).
2. **When kept state starts and ends.** `ArenaSettings` (mode, map, Robo level,
   last map) starts at `defaults`, saves on each pick and survives a restart
   (`arenaSettingsProvider`, tests set/read it); the card's ready set drops a
   player who leaves and starts empty each time the card opens
   (`_before.removeWhere`, `arena_waiting_test`'s toggle test); the card's timer
   runs only while the card is mounted; `HostMusic._arena` clears on close and
   on a new round; `_bumperPlayers` is fixed at the round's first step and
   cleared with the session; a card with no players can't start (the start
   needs at least one joined player).
3. **How a new state combines.** `_Stage` is the one owner: the card before the
   round, `Pausable`/`RoundHold` during it, the results after (the card can't
   pause and the results can't be paused). The pause menu, the host away and a
   player away still belong to `Pausable` (`pause_menu_test`, `abandon_test`);
   leaving from the results records the round in a night (`_leave` → `_next`,
   `arena_night_test`); leaving from the card pops with B/Escape (`arena_waiting_test`).
4. **Stay in the job's folder.** Only `docs/briefs/m14/b2-arena-screens-report.md`,
   `packages/party_host/{lib,test}` and `packages/test_game/{lib,test}` changed;
   `tv_test_app` and `docs/protocol.md` are untouched.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`; no
   rule had to be broken; the choices the brief left open are listed under
   **Decisions**.

## Commit message

Arena: the waiting card, results card and a night's Bumper Round

The Arena opens on its waiting card: the code, each phone's ready mark, the
mode buttons, the five maps with their pictures and Surprise me, and Robo's
level for a lone player. The 3-2-1 runs on the TV too, the round plays the
arena/hurry/final music by its clock, and the results card shows coins, the
winner or the draw. A night's Bumper button is live: the round records into
the night, doubled in the last round. Arena words move to ArenaText, the
debug overlay out of game_screen.dart.

## Status row

M14 b2 done: the Arena's waiting card (modes, five maps with pictures,
Surprise me, Robo's level), the TV's 3-2-1, the results card, the round music's
clock, and the night's Bumper Round recording into the scoreboard (doubled in
the last round); open: Robo's seat (b3) and a night's used-map memory.

## Delete

- packages/test_game/lib/src/arena_map_picture.dart
