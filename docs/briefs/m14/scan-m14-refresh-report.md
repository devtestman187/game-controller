# M14 refresh scan: the party touchpoints at HEAD, with the Bumper Round (G9)

Read-only; nothing changed but this report. Facts from the tree at `bfbe3f9` (70 commits after `36322dd`); every claim
cites `file:line` at HEAD, and a path is given once, then by bare name.

## 1. What moved since the old scan

- **The puzzle's tick is no longer one function.** `update()` is `game.dart:236-270` (35 lines), calling `_noteTime`,
  `_presses`, `_moveAll`, `_turnAll`, `_keepHeldInField`, `_highlight`, `_tapAll`; `ec3ed70` split it after the old
  scan, so "`game.dart:231-333`" and "`update()` is 103 lines" (old §1, §10) no longer hold. The file grew 365 → 399,
  one line under the hard limit; `tray.dart` already holds the tray.
- Still where the old report says: counters `game.dart:37-47`; speed 48 `:83`; `_filled` `:100`; `puzzle_report.dart`
  `write()` `:23` (now 50 lines, a NOTE) with `player_result` `:31`, `round_end` `:58`, winners `:67`;
  `puzzle_session.dart` labels `:23`, again after a resume `:121`, report-once `:136-140`, `abandon()` `:159-165`;
  `session_recorder.dart` (`onRecord` `:59`) and `metrics/session.dart:198-234` unchanged.
- Moved a little: `_layOutTray` `game.dart:129-147` (old `124-142`); `round_start` `puzzle_session.dart:75` (old
  `67-76`); `puzzleSettingsProvider` `providers.dart:371` (old `347-370`); `games_screen.dart` picker `:30-85`, Shape
  Race `:91`, Arena pushed `:62`, join `:127-128`.
- **New since the old scan:** `puzzle_rules.dart` (391) — the puzzle *library* rule book (`check`), not the tick, so
  not the "split" the old cut meant; `tray.dart`, `start_angles.dart`, `piece_colors.dart`, `worker_stride.dart`; in
  `party_host` `music_loop.dart` (51), `sound_loop.dart` (204), `ui/lobby_music.dart` (308, `RoundHold`/`LobbyHold` as
  its parts), `ui/leave_round.dart`, `ui/round_phase.dart` (83); `test_game` `arena_moments.dart` (85),
  `arena_hud_widgets.dart` (209).
- **The sound player changed shape.** Old §8's "no loop, volume or mute" is gone: it loops, fades, pauses, sets volume
  and restarts (`sound.dart:41-56`; `SoundLoop` `sound_loop.dart:15-204`), and `HostMusic` (`ui/lobby_music.dart:49`)
  plays the lobby's loop and the round's three tempos. The manifest grew from 10 keys to 16
  (`assets/lib/asset_manifest.dart:21-37`).
- **The round's music knows a clock now, but only Shape Race's.** `PuzzleScreen` reports `roundScreenOpened` `:111`,
  the clock (`_clocked` `:156`, wired `:277`), `roundScreenClosed` `:116` and `roundEnded` `:147` to `HostMusic`
  (`lobby_music.dart:130-166`); `MusicLoop.forRound` picks one of three tempos (`music_loop.dart:43-47`).
- **The Arena screen did not move.** `game_screen.dart` is unchanged (285 lines): `Pausable(enabled: true)` `:135` (no
  `players`, so everyone may pause), `RoundHold` `:126`, no `roundScreen*` call. `arena.dart` is unchanged at 487
  lines; `arena_session.dart` gained 22 lines (`856fa55`, the dash label and the flag).
- **What the old "Suggested M14 cut" relied on that no longer holds:** "split first, `game.dart` into rules and a
  per-side tick" — the tick exists, so a pure move of a 399-line file is left, needed before any addition but cheaper
  than planned; old §8's sound picture; old §9's PRD lines (G9 at `PRD-v2.md:172`, M14 at `723-766`). Still true:
  nothing above a round remembers one (`round_phase.dart:7-19`), the snapshot has no new keys, and the per-player
  counters are still only the puzzle's.

## 2. Groundwork still needed

- **Shape Race's rules file split.** `game.dart` 399 of 400; no function is over 60 (the nearest is `write()` 50 in
  `puzzle_report.dart`). The seam is by content, as `tray.dart` shows: `PuzzlePlayer` and the counters (`:17-62`), the
  tick helpers (`:256-330`), the drop/turn calls. Blocks every M14 addition to Shape Race (G1's points, G3's cat).
- **The snapshot's new top-level keys and version.** Unchanged: `PuzzleSnapshot.version = 1` (`snapshot.dart:63`),
  budget 2048 (`:66`), keys `:98-119`, `MatchSnapshot.version = 1` (`:209`); the Arena's is version 1 too
  (`arena_snapshot.dart:121`), keys `:144-161`, with a literal 2048 in its test (`arena_view_test.dart:255`, no
  `maxBytes`). Blocks any points, coins or score a joined phone must draw (review-rules B5); an optional top-level
  key is additive and needs no bump, a field that changes play does.
- **The three puzzle rules into the rule book** (R4 finding 5). `puzzle_rules.dart` is 391 of 400; `_level` `:244`
  (47 lines), `_fit` `:319` (56). Still only in tests: no two tray boxes overlap at seeds 0–199 and two pieces start
  turned (`rules_test.dart`), every piece is at least `minPieceMm` on the narrowest phone
  (`controller_app/test/puzzle_size_test.dart`). Blocks "`check` is the whole check"; no room, so a split comes first.
- **The round music on an app hidden mid-round** (R4 finding 8). On hide it stops at once (`lobby_music.dart:278-290`);
  on show `_start` runs with no current loop and plays from share 0 (`:252-262`), and the wish keeps the loop's name,
  not its place (`sound.dart:126-132,270-276`; `sound_loop.dart:133-140`). One field in `HostMusic` plus a test;
  blocks G2's music holding between rounds after a backgrounded app.
- **The empty-rounds stats bug.** Both `abandon()` paths record a `round_end` with only a reason
  (`arena_session.dart:132-139`, `puzzle_session.dart:159-165`); the recorder turns it into
  `roundEnded(timeS: 0, modes: {})` (`session_recorder.dart:67-81`), so metrics adds a round with `players: 0`,
  `timeS: 0` (`metrics/session.dart:208-218`). One branch in `onRecord` (52 lines, a NOTE) or an early return; blocks
  G2's scoreboard and awards counts and every rounds-per-format number.

## 3. The Arena today, for the Bumper Round (G9)

- **Rules.** `ArenaGame` `arena.dart:180-487`: a race to the goal, `ArenaPhase{playing, won}` `:108-114`; `update()`
  `:327-358`; `_updatePlayer` `:360-401` (42 lines); `_move` `:405-426`; `_resolve` `:430-455`; `_checkHazards`
  `:457-475`; `_newRound` `:477-486` after a 2 s break (`:196`). Players never touch each other (`ArenaPlayer` doc
  `:116-117`): there is no pair loop. Constants `:184-206`, walls and hazards `:208-220`.
- **Sizes.** `arena.dart` 487 lines, the one `review.sh` size FAIL at HEAD; `arena_snapshot.dart` 276;
  `arena_session.dart` 156; the two view files 243; `arena_hud_widgets.dart` 209.
- **Snapshot.** `ArenaSnapshot.version = 1` (`arena_snapshot.dart:121`), keys `v rd t ph wl g hz pl st win last br
  best bestId` (`:144-161`); per marble `ArenaPlayerView` (`:9-96`) with `w h ds fd`, `lerpTo` (`:75-95`). Names are
  not in it: a roster rides beside the frame (`game_session.dart:288`), drawn at `arena_hud_widgets.dart:172`.
- **Session.** `step()` `arena_session.dart:81-117`: buttons per player `:86`, `round_start` with the frame rate as
  soon as one player is present `:89-92`, each event → that player's haptic, `sound(e.event.name)`, the screen's
  `onEvent`, a record `:97-101`; `round_end` on playing→won with `timeS`, `modes`, `winner` `:103-113`;
  `abandon()` `:132-139`; `_eventName` `:149-155`.
- **Events → sound and buzz.** `GameEvent` (`arena.dart:48-63`) is a player, a `HapticEvent`, a `GameEventCause`
  (`wall, hazard, goal, dash, cooldown`), intensity, duration. The buzz goes to that controller only (`:98`), the sound
  is the haptic's name (`:99`): a cue needs a haptic event to exist, which coins are not (section 5).
- **What the music knows.** Nothing: `GameScreen` reports no clock and no end, so `HostMusic` asks
  `forRound(timeLeftMs: null)` and stays on `MusicLoop.round` (`lobby_music.dart:195-197`), and the music only stops
  when the screen goes. `MusicLoop` names Shape Race's three files only (`music_loop.dart:9-47`).
- **What each G9 piece would touch.**
  - *Marble-to-marble contact*: a pair pass in `update()` (6 pairs at 4 players) with a push-out and a new cause,
    order-stable (guidelines §5); `arena.dart`, after its split.
  - *Coins (3, 1 s sparkle, drop on hazard or shove, 1 s dizzy + 1 s safe, gold worth 2 in the last 15 s)*: rules state,
    a per-coin snapshot key (lerped, or this-frame like the flags), a HUD line, new causes in `_eventName`, resets in
    `_newRound`: `arena.dart`, `arena_snapshot.dart`, `arena_session.dart`, `arena_hud_widgets.dart`.
  - *A 60 s clock*: `roundTimeS` is already in the snapshot (`t`, `:124,147`) and drawn by the HUD
    (`arena_hud_widgets.dart:113`) — counting up. A countdown needs a time-up path in the phase (a third value, or
    `won` with no winner) and the screen reporting its clock to the music.
  - *A score*: `ArenaPlayer` counters `:139-143`, `ArenaPlayerView` fields and the HUD `_PlayerRow`
    (`arena_hud_widgets.dart:150-156`); per-player JSON is keyed, so adding is safe, unlike the puzzle's arrays.
  - *A winner (most coins, ties shared)*: `winnerId` serves a race round (`:387`); a coin round needs a set. The
    record allows it (`winners`, `draw`, `session_recorder.dart:79-80`) but the Arena writes `winner` only (`:111`).
- **Pause, away, ready, countdown vs Shape Race.** Both rounds sit in `Pausable` (`game_screen.dart:135`,
  `puzzle_screen.dart`), the one owner of pause, the host away, a dropped player's wait and the phase
  (`pause_menu.dart:64-77, 90-94`); the 3-2-1 `ready` beat is a provider override only the phone host sets
  (`host_overrides.dart:40`), so the TV gets none. The M14 card "the Arena waits for its players" has nothing yet:
  no waiting card and no gating — a round starts as soon as one controller is present (`arena_session.dart:89`),
  where Shape Race waits on its join screen for A (`join_screen.dart:287`).

## 4. A night across two games

- **Today's flow.** Picker (`games_screen.dart:30-85`) → Shape Race's levels `:91-129` → `JoinScreen`
  (`join_screen.dart:287-292`, teams kept there) → `PuzzleScreen`; the results card `puzzle_screen.dart:282-291`
  with Play again / Rematch, Change teams and Back (`:164-190`) replaces the route (`:161`).
- **The Arena is not that flow.** The picker pushes `GameScreen` straight (`games_screen.dart:62`): no join screen, no
  sides, no results, no route replacement; it runs round after round until the screen is left.
- **Nothing above a round remembers one.** `RoundPhase` is none/ready/playing (`round_phase.dart:7-19`);
  `LobbyHold`/`RoundHold` exist only to tell the music. A night (round index, game, scores, doubles) is a new
  `party_host` state, as the old scan said (old §5), with nothing built toward it.
- **Teams vs one field.** Shape Race's sides live in `JoinScreen` and `PuzzleMatch.teams`; the Arena keys everything
  by player id (`ArenaPlayer.id`, roster) and has no side. A scoreboard by side needs a `teamOf(playerId)` the host
  owns, or per-player points for both games — a decision for the design, not this scan.
- **What a scoreboard needs from a result.** One shape with the round's winner(s) and each player's points. The puzzle
  writes `round_end` {winner, winners, draw} and `player_result` (`puzzle_report.dart:23-68`); the Arena writes
  `round_end` {timeS, modes, winner} (`arena_session.dart:103-113`). Both reach `session_recorder.dart:59-109` →
  `metrics/session.dart:198-234`, a metrics sink: no screen hears of a round except through its route, and
  `ViewEndMessage` carries a reason only (`protocol/lib/src/view.dart:129-150`).
- **Where points could live so both report them alike.** In each game's rules and snapshot for the players (the
  snapshot is the joined phone's only channel) and in one record shape for the host's night: the puzzle already
  writes `player_result` per player (`puzzle_report.dart:31`, stored at `session_recorder.dart:92-100`). The other
  seam is a result handed back to a screen — the puzzle has `onFinished` (`puzzle_session.dart:139`), the Arena has
  none. Which the night reads is a design decision.

## 5. Sounds

- **At HEAD.** 16 `SoundKey`s (`assets/lib/asset_manifest.dart:21-37`), each file derived from the event name
  (`:53`), a missing file silent (`:62-71`); `sound_keys_test.dart` pins the spellings and that the files exist.
- **The ten a1 files are there and wired to nothing**: `assets/audio/{dash,bump,bump_big,coin,coin_gold,coin_lost,
  coin_appear,arena,arena_hurry,arena_final}.ogg`, owner-approved ("Arena sounds are good", a1 report `:138`); no
  `SoundKey`, no `CREDITS.md` row (the table ends at `round_final`, `assets/CREDITS.md:35`). An unknown name plays
  nothing, so nothing breaks today — and nothing plays.
- **Wiring needs:** ten enum entries with their wire spellings (`bumpBig`→`bump_big`, `coinGold`, `coinLost`,
  `coinAppear`, `arena`, `arenaHurry`, `arenaFinal`, `dash`, `bump`, `coin`), ten CREDITS rows, and the spellings in
  `sound_keys_test.dart`.
- **The events that play them.** The Arena plays the haptic's name (`arena_session.dart:99`): `dash` needs a sound
  beside its `rumble` haptic, and `bump`, `bump_big` and the four coins have no event at all. Two shapes: a sound name
  on `GameEvent` (`arena.dart:48-63`) played in place of `e.event.name`, or a cause→sound map in `arena_session`. A
  new `HapticEvent` costs a `defaultDurationMs` case (`haptic.dart:36-46`) and a pattern in the phone's exhaustive
  switch (`haptic_patterns.dart:57-67`) — right for a bump or a shove, wrong for coins.
- **Music.** `HostMusic` chooses one trio (`MusicLoop`, `music_loop.dart:9-47`); the Bumper Round needs a second,
  picked per game, and `GameScreen` must report its clock and end for the hurry and the fade
  (`lobby_music.dart:130-166`). The design says how: `docs/design/look-and-sound.md:243-255` — `arena`, hurrying at
  15 s and 5 s, the race Arena staying on `arena`.

## 6. Results on joined phones and nicknames (C20)

- **Results.** `view_end` carries `reason` only (`protocol/lib/src/view.dart:129-150`); an optional field is
  additive and an older phone ignores it. The phone reads the end at `providers/view.dart:35,147`, drops the drawing
  (`joined_view.dart:100`) and shows an "abandoned" notice for 4 s (`providers/view.dart:205-240`). A result card
  needs `JoinedView` to keep the last frame after `viewActive` goes false (`joined_view.dart:97-100`), or it sits over
  the pad instead of the final board.
- **Nicknames.** The hello already carries a `name` (`protocol/lib/src/messages.dart:52-99`) from
  `ControllerIdentity` (`controller_identity.dart:34-41`), built in the phone's `storage.dart:16-43` as "Android phone
  1A2B" from the persisted `controllerId` (`:107`). The host turns it into `GamePlayer.nickname`
  (`server_game_host.dart:181`), the frame carries a roster of names (`game_session.dart:288`) and both games draw them
  (`arena_hud_widgets.dart:172`, `arena_roster.dart:9-11`). A typed nickname therefore needs a saved string beside
  `_controllerIdKey` (`storage.dart:107`), the name built from it at `:33` (cut to 10 characters, `PRD-v2.md:113`) and
  a phone-side field: no protocol change, and it never leaves the host.

## 7. Risks at HEAD

- **Over 400, a FAIL:** `arena.dart` 487 — G9 must split it before adding (`project-notes.md:53`).
- **At or near the limit, and M14 changes them:** `game.dart` 399, `providers.dart` 394, `pause_menu.dart` 391
  (waiting card), `join_screen.dart` 376, `messages.dart` 361 (`view_end`), `lobby_music.dart` 308, `sound.dart` 302,
  `puzzle_screen.dart` 297 (scoreboard), `game_screen.dart` 285 (ready, waiting, results, music), `arena_snapshot.dart`
  276.
- **Functions near 60:** `session_recorder.onRecord` 52 (the empty-round fix), `puzzle_report.write` 50,
  `arena._updatePlayer` 42. Pre-existing FAILs, in files M14 need not change: `_computeScreen` 120, `packTray` 104,
  `_stickLayout` 92.
- **Joined phones draw from snapshots only** (review-rules B5): coins, score, clock and winner must be in the
  snapshot; a version mismatch shows the update text (`frame_view.dart:15,275`).
- **4 marbles touching.** 6 pairs, and `_move` already sub-steps by speed (`arena.dart:405-426`), so the cost is
  small; what must hold is determinism (a fixed roster order) and a shove never pushing a marble through a wall
  (`_resolve`).
- **Review-rules part A, per job.** A1: the six host setups differ (the ready beat is phone-host only, no waiting
  card), so a change is tried on a TV, a phone host and a joined phone. A2: the 60 s clock, the 1 s sparkle, the
  dizzy/safe and shove cooldowns need an owner and must not run while the round stands still. A3: waiting, pause, the
  host away, a player away, the results and leaving need exactly one owner — `Pausable` today.

## Suggested M14 order

Smallest first. Jobs with no file in common can run side by side.

1. **The empty-rounds record** — `party_host/lib/src/session_recorder.dart`, one test. Beside 2, 3, 4, 12.
2. **The music's place across a hidden app** — `ui/lobby_music.dart` (+ `sound.dart` if the wish must carry the
   share), `test/round_music_test.dart`. Beside 1, 3, 4.
3. **Split `arena.dart`** (pure moves) — `test_game/lib/src/arena*.dart`; the size FAIL goes green, G9 needs it.
   Beside 1, 2, 4, 12.
4. **The rule book's three rules** — `puzzle_rules.dart` (split if needed), `docs/puzzles.md`. Beside 3, 5, 12.
5. **The Arena's keys** — `asset_manifest.dart`, `assets/CREDITS.md`, `sound_keys_test.dart`; plays nothing yet.
   Beside 1–4; 9 needs it.
6. **Split `game.dart`** (pure moves) — `game.dart` + new files. Beside 1, 2, 3, 5, 12.
7. **Points in Shape Race** — `game.dart` (after 6), `snapshot.dart`, `puzzle_report.dart`, the HUD/painter,
   `puzzle_session.dart`.
8. **The Bumper Round's rules** — `arena.dart` (after 3), `arena_snapshot.dart`, `arena_session.dart`,
   `arena_hud_widgets.dart`: clock, coins, contacts, score, winner. Needs 3 and 5.
9. **The Arena's music and cues** — `music_loop.dart`, `lobby_music.dart`, `game_screen.dart`; needs 5 and 8's clock
   and takes 2 with it. Conflicts with 10 on `game_screen.dart`.
10. **The waiting card and the ready** — `game_screen.dart`, `leave_round.dart`, `lobby_music_widgets.dart`,
    `host_text.dart`; after 9.
11. **The night state** — a new `party_host` provider, `puzzle_screen.dart`'s results, `games_screen.dart`; needs 1, 7
    and 8's result shape. The design-heavy one.
12. **Nicknames** — `controller_app`'s `storage.dart`, a phone settings screen, `host_text.dart`; beside any host job.
13. **Results on joined phones** — `protocol`'s `view.dart`, the phone's view providers, `joined_view.dart`; needs 11's
    scoreboard shape and a spec line (guidelines §8).

## Checks

- `tools/review.sh --all` (read-only), for the risks section; its FAILs at HEAD are pre-existing, in files this job
  does not touch (`arena.dart` 487, `_computeScreen` 120, `packTray` 104, `_stickLayout` 92). No test, no build, no app
  started.
- `git status` shows `tv_test_app/windows/flutter/generated_*` modified; their diff is empty (line endings) and this
  job wrote nothing but this report.

## Self-check: docs/review-rules.md part A

1. Every host setup: not affected; the scan records where they differ (section 3's ready beat, no waiting card).
2. When kept state starts and ends: not affected; section 7 lists the states each job must own.
3. How a new state combines: not affected; named per job in section 7.
4. Stay in the job's folder: only this report was written.
5. Stop rather than overstep: nothing blocked; nothing outside `allow:` was needed.

## Questions and suggestions

1. `arena.dart` at 487 lines is the only size FAIL and G9 lands on it. Suggested: the split is job 3, a pure move
   like the m12 c-jobs, and G9 waits for it.
2. G9's "ties shared" makes a result a set of ids; the `round_end` record allows it (`winners`), but the Arena writes
   one `winner`. Suggested: the Bumper Round writes `winners`/`draw` as the puzzle does.
3. Coins are sound-only but the Arena's sound is the haptic's name (`arena_session.dart:99`). Suggested: a sound name
   on `GameEvent` (or a cause→sound map) rather than new `HapticEvent`s, each needing a pattern and a duration case.
4. The games share no result object and the Arena has no `onFinished`. Suggested: the design picks one seam (a
   `player_result` record both write, or a result from `GameSession`) before job 11.
5. A nickname reaches the TV from `hello.name` already; only the phone's field and the 10-character cut remain.

## Commit message

docs(m14): refresh the touchpoints scan for the Bumper Round

The M13 scan re-read at bfbe3f9: the puzzle's tick was split
(update() 35 lines, the file 399), the sound player gained loops and
volume, and the round music follows Shape Race's clock only. The Arena
is unchanged (487 lines, one size FAIL) with no clock, coins or
contacts; its sounds are rendered but unwired. Groundwork left: the
game.dart split, snapshot keys, three rules into the rule book, the
hidden app's music, the empty-rounds record.

## Status row

Refresh scan done: seven questions answered at `bfbe3f9` with file:line, the Bumper Round's seams mapped, a
smallest-first order given; open: the design's calls (a shared result shape, points per side) and the groundwork.

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted. Spot-checked at HEAD: `arena.dart` 487, `game.dart` 399, `puzzle_rules.dart` 391, the Arena playing the
haptic's name (`arena_session.dart:99`) and writing one `winner` (`:111`), `onRecord`'s `round_end` branch
(`session_recorder.dart:67-81`), the Arena music spec (`look-and-sound.md` §8). Title typo fixed (G0 → G9).
Answers to its questions, settled in docs/design/party-night.md:
1. Yes: `arena.dart` is split by a pure move before any Bumper Round code.
2. Yes: the Bumper Round writes `winners`/`draw` as the puzzle does.
3. Yes: a sound name on `GameEvent`, not new `HapticEvent`s for coins; a bump keeps a haptic.
4. One seam: a `RoundResult` both games hand back to the host (`onFinished`), which the night reads; the
   records stay metrics only.
5. Agreed: nicknames are phone storage plus the 10-character cut, no protocol change.
The order is taken mostly as given; the design regroups it into groundwork, then three feature lanes.
