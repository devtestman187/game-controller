# M12 bug 1107d A1 — G4 report: a dropped player keeps their slot for 30 s

Done at G4, the gate the brief names. The plan's §1 and job A1, with Claude's five answers: `awayGrace` is a
`ServerGameHost` constructor `Duration` defaulting to 30 s (`hostGraceS`), the verb is `goOnWithout(String playerId)`,
the slot ends with the round, End round is Quit (B's job), and `n` travels in the message (A2's job). No file outside
`allow:` was edited.

## Files changed

- `packages/connection/lib/src/game_types.dart` — `GamePlayer.away` (doc: the phone dropped and the round still holds
  its slot), added to `==` and `hashCode`, so a live → away change is a roster change for `_samePlayers` and
  `gamePlayersProvider._same`. 95 → 103 lines.
- `packages/connection/lib/src/game_host.dart` — `players`' doc says the list includes the players who are away; new
  `goOnWithout(String playerId)`: the round goes on without an away player, "does nothing for a player who is here or
  already gone". 107 → 113 lines.
- `packages/connection/lib/src/away_slots.dart` — **new**, 63 lines: `AwaySlots`, the slots of the players whose phone
  dropped (`players`, `ids`, `isEmpty`, `contains`, `hold(player, timer)`, `end(id)`, `endAll()`, `dispose()`). It owns
  each timer from `hold` on and cancels it in `end`/`endAll`/`dispose`; `hold` stores the player as `away: true` with
  the same ID, number, nickname and mode. Internal: `connection.dart` doesn't export it.
- `packages/connection/lib/src/server_game_host.dart` — 323 → 388 lines (it was 412 with the slots inline, over the
  400 limit, so they moved to `away_slots.dart`):
  - the constructor's `awayGrace` (default `defaultAwayGrace`), plus `hostGraceS = 30` and `defaultAwayGrace`;
  - `players` adds `_away.players`, so a dropped player stays in the list, sorted by number;
  - `_checkPlayers` calls `_updateSlots()` first, skips `p.away` when it re-sends a layout/panel/view, and builds
    `before` from the players that were **not** away, so a phone that comes back is treated as a rejoin (it gets its
    layout, its panel and `view_start`+latest frame again, as any pairing phone does);
  - `_updateSlots()`: holds a slot for each player that was live at the last check and isn't now (never for a local or
    a simulated player), frees the slot of one that is live again, then remembers the live players;
  - `_holdSlot()` starts the one-shot `Timer(awayGrace)`: on fire it ends the slot and re-reports the players;
  - `goOnWithout()` ends the slot at once and re-reports;
  - `endView()` ends every slot (Q3: the slot ends with the round — round over, quit or abandoned — so a rematch never
    waits for someone who left);
  - `dispose()` stops every slot's timer through `AwaySlots.dispose()`.
- `packages/connection/lib/src/memory_game_host.dart` — `goOnWithouts` records each call; `goOnWithout` drops the
  player when the one the test set is `away` (any other call only records). 158 → 168 lines.
- `packages/connection/test/player_away_test.dart` — **new**, 21 tests: the 11 rules below (the first 10 on both
  transports, webSocket and inProcess, plus 1 for the memory host).
- `packages/connection/test/wire_phone.dart` — `WirePhone.open` takes `platform`, default `'test'`, so a test can open a
  simulated phone (`platform: 'sim'`). No other change.
- `packages/party_host/lib/src/testing/host_fakes.dart` — `FakeGameHost.goOnWithouts` and a `goOnWithout` that records
  (the fake has no away players yet; B adds them).
- `packages/party_host/lib/src/ui/pause_menu.dart` — the `_tick` players (`!p.away`), so a phone that is away can't
  press Start or Resume, and `_PauseMenu.build`'s resumer list (same filter, so an away P1 doesn't block a resume).
  204 → 205 lines.
- `packages/party_host/lib/src/ui/controller_menus.dart` — `!p.away` in `_tick`'s players: no menu layout is stored for
  a phone that isn't there (it would be re-sent on rejoin, over the game's own).
- `packages/party_host/lib/src/ui/join_screen.dart` — `!p.away` in `_tick` (so `_prune` drops its team and its button
  memory) and in `build` (so it is neither on a side nor under "Not joined"). 297 → 305 lines.
- `packages/party_host/lib/src/providers.dart` — `TvEventsNotifier.fire` skips away players when it targets everyone.
- `tv_test_app/lib/src/ui/latency_screen.dart`, `tv_test_app/lib/src/ui/haptic_panel_screen.dart` — `!p.away` beside
  `!p.local`: no latency row and no "Sends to" entry for a phone that isn't there.
- `docs/briefs/m12/bug-1107d-a1-report.md` — this report.

## The rules, and the values they were checked with

`player_away_test.dart`, grace 5 s in the "kept" tests so a busy machine never runs it out mid-test (the plan says
200 ms; see "Not sure" 2):

1. **a player whose phone drops keeps their slot, away** — drop phone-1: the list is exactly one player, `id`
   `phone-1`, number **1**, nickname `Phone phone-1`, `away` true, `local` false; `gamepad` is `GamepadState.neutral`,
   `inputSeq` and `inputArrivedAtMs` null.
2. **the away slot keeps its number when another phone joins** — `{phone-1: (1, away), phone-2: (2, here)}`: the new
   phone takes 2, not phone-1's 1.
3. **the slot ends when the grace is over** — grace **1 s**: the change to an empty list arrives on its own.
4. **goOnWithout ends an away player's slot at once** — `players` is empty on the call itself (no wait for the timer)
   and the listeners get the empty list.
5. **goOnWithout for a player who is here does nothing** — `['phone-1']` before and after.
6. **a phone that comes back within the grace is not away** — the list is one player, number 1, `away` false.
7. **a phone that comes back gets its game layout again** — the layout `A: 'Snap'` reaches the phone, the drop resets
   it to standard (the client's own rule), and after the rejoin `one.layout.labels == {A: 'Snap'}`: the host sent it
   again because an away player doesn't count as "already here".
8. **a simulated controller that goes leaves at once** — `platform: 'sim'` phone, `server.dropAllConnections()`, the
   list is empty (no slot).
9. **every away slot ends when the round is over** — a view is running, the phone drops (away), `endView(finished)`,
   the list is empty: the rematch starts without them (Q3).
10. **dispose cancels the away timers** — grace 500 ms, a `Zone` with `createTimer` records the host's one-shots:
    exactly **1** timer of that duration, `isActive` true before `dispose()`, false after.
11. **the memory host drops the away player when the round goes on** — `goOnWithouts == ['p1']`, players `['p2']`,
    and `goOnWithout('p2')` leaves `['p2']`.

Failing first: with the hold disabled in `_updateSlots` (one temporary line, reverted), every test that waits for an
away slot fails with `TimeoutException: Host stuck at []` — the bug's reason (the list loses the player at once): 16
of the 21. The 5 that pass are the ones whose rule the old code already met (rules 5 and 8, on both transports) and
the memory host test (rule 11, which is that host's own code).

## Existing tests that count `players` after a drop

None. `view_test` and `m6_test` read `HostServer.snapshot.connected`, not `GameHost.players`, and `m6_test`'s "a
controller that drops keeps its number" only checks the numbers on the wire; `live_host_service_test` reads
`service.gameHost.players` while both phones are connected; `live_stats_test` reads `host.players.single` with no
drop; `controller_menus_test` and `game_screen_test` run on `FakeGameHost`. So no old → new value changed, and
`connection` 251 → **272** tests with no test edited.

## Every reader of `players`

| reader | what I did | why |
| --- | --- | --- |
| `pause_menu.dart:92` (`_tick`) | filter `!p.away` | not here to press Start or Resume |
| `pause_menu.dart:165` (`_PauseMenu` resumers) | filter `!p.away` | an away P1 must not hold the resume, as when they had left |
| `controller_menus.dart:146` | filter `!p.away` | no menu layout stored for a phone that isn't there |
| `join_screen.dart:118` (`_tick`) and `:246` (`build`) | filter `!p.away` | not listed for 30 s, and its team is not kept |
| `providers.dart:230` (haptic to all) | filter `!p.away` | a haptic to an away phone already returns false; don't count it |
| `latency_screen.dart:22` | filter `!p.away` | no phone, no latency |
| `haptic_panel_screen.dart:108` | filter `!p.away` | not a target |
| `puzzle_screen_widgets.dart:45,100-107` (results) | keep | they show who played |
| `puzzle_report.dart:28` (`s.game.players`) | keep | the rules' own list, not `GameHost.players`: a player away at the last step keeps its `player_result` (the leaver's numbers used to be lost) |
| `live_stats.dart:167` | keep | it takes only the locals from the host; the rest comes from the server snapshot (A1 doesn't change it) |
| `game_session.dart:230` (`_sample`, game_kit) | keep | the point of the slot: the rules keep the player, the pad is neutral, so nothing moves |
| `game_screen.dart:61,92,104,183` | keep | local-player lookup, the event's log line, "nobody connected" and the debug overlay (see "Not sure" 3) |
| `session_recorder.dart:121` | keep | a log line that looks up a player's number by ID |
| `debug_start.dart:50` (tv) | keep | a debug-only start screen (see "Not sure" 4) |
| `host_fakes.dart:160` (`FakeGameHost.players`) | keep | it has no away concept until B |

## Checks

- `tools/check.sh format analyze connection host puzzle tv` — all PASS: format (2 s), analyze (6 s), connection (272
  tests), host (83), puzzle (106), tv (9 s). `tools/check.sh kit` also PASS (33), since `GameSession` reads `players`.
- Test counts before → after: connection **251 → 272** (+21: the new file), kit 33 → 33, puzzle 106 → 106, host 83 →
  83, tv `+28 ~1` → `+28 ~1`.
- `tools/review.sh` — 0 fail, 4 notes (all `size`): `server_game_host.dart` 388 lines (limit 400), `providers.dart`
  321, `host_fakes.dart` 335, `join_screen.dart` 305.

## Not sure

1. **Two constants for the grace.** `hostGraceS = 30` and `defaultAwayGrace = Duration(seconds: hostGraceS)`, so the
   default and the documented seconds can't drift; the plan's "default 30 s = `hostGraceS`" is met, but it is one
   member more than the plan listed. Say if only `hostGraceS` should exist.
2. **Test graces are longer than the plan's 200 ms** — 5 s for the "kept" tests, 1 s for the expiry, 500 ms in the
   dispose test. Asserting "away at 100 ms, gone at 300" puts two real-clock waits in the test; waiting for the
   `playersChanged` events instead proves the same rules without a sleep, and a 200 ms grace can be over before a
   busy machine gets to the first assertion (flaky). The rules and the unit are unchanged.
3. **`game_screen.dart` was not in the plan's table and I left it alone**: `DebugOverlay` (183) lists an away player
   with "–" for ping and its neutral pad, `_onEvent` (92) names it in the log line, and `nobody` (104) hides "No
   controller connected" while an away player is in the round. The last one may deserve B's eye: with only an away P1,
   the Arena shows no hint. Nothing crashes.
4. **`tv_test_app/lib/src/debug_start.dart:50`** builds the debug puzzle with `players.first.id`, which can now be an
   away player (sorted by number). It is a debug start path with no game running; a `!p.away` there would be one line
   if Claude wants it.
5. **No tests for the UI filters.** The plan puts "menus skip an away phone" in B, and B's `host_fakes` needs a way to
   set a player away first; the join screen, latency screen and haptic panel filters have no test in any job yet. They
   are covered by `analyze` and the host/tv suites, not by a rule of their own.
6. **`_updateSlots` runs on every roster change** and builds `players` twice (once for the live map, once for the
   list). That is per connection event, not per frame, so it isn't in the 60 fps path; a session's `_sample` reads the
   list once a step as before.
7. **Three `tv_test_app/windows` generated files show as modified in `git status`** (`generated_plugin_registrant.cc/
   .h`, `generated_plugins.cmake`) after the Flutter tool ran the tv check. I didn't edit them and `git diff` lists no
   content for them (line endings only), the same as `bug-1107b-fix-report.md` noted.
8. **Suggestion, not acted on:** B's card says "Go on without them" once for all away players (Q4), so it can call
   `goOnWithout` per away player; a `goOnWithoutAll` would be a second verb on the interface and isn't needed.

## Commit message

feat(m12): a dropped player keeps their slot for 30 s

ServerGameHost keeps a dropped phone in `players` as GamePlayer.away for
`awayGrace` (30 s, hostGraceS), one timer per player, so the rules keep
its dot and held piece while its pad is neutral. `goOnWithout` ends a
slot at once, an endView ends them all, and a simulated controller never
gets one; a phone back within the grace rejoins as before. The menus, the
join screen, the haptics and the tv screens skip an away phone; the
results and the report keep it. The slots live in a new internal
away_slots.dart, as the host file would have passed 400 lines.

## Status row

| Bug 1107d A1 | G4 done ([bug-1107d-a1-report.md](bug-1107d-a1-report.md)): a dropped player stays in `GameHost.players` as `GamePlayer.away` for `awayGrace` (30 s, `hostGraceS`, one timer per player in `AwaySlots`), `goOnWithout(playerId)` ends a slot at once, `endView` ends every slot (Q3), a simulated controller never holds one, and the pause menu, controller menus, join screen, haptics and tv screens skip an away phone. Tests connection 251→272, others unchanged; checks pass, review 0 fail. Open: B (the pause, `playersAwayProvider`, the away card), then A2 and C |

## Delete

- none
