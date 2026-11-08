# M12 build 4 fix-f1 — G4 report: B on the away card, the host's own player never away

Done at G4, the gate the brief names. The three items are in: while the away card is up nothing pops the round (B on
any phone and the remote's Back); the host phone's own player never gets an away slot, marked on the link it came in
on; and a viewer that pairs while the host is away is now told, with the time the host's grace has left. Nothing
outside `allow:` was edited (see Question 3 about the generated Windows files a `flutter pub get` rewrote).

## Files changed

- `packages/connection/lib/src/game_types.dart` (111 lines) — `GamePlayer.ownPlayer`, documented as "came in on the
  host's own in-process link (D1)", in the constructor, `==` and `Object.hash`.
- `packages/connection/lib/src/server_game_host.dart` (**394 lines**, limit 400) — `players` sets
  `ownPlayer: c.isLocal` (line 180: the link, not the ID); `_hostAwayEndsAtMs` (line 99) is the end of the host's
  grace on the host's clock, set in `hostAway` and cleared by `startView`, `endView` and `hostAway(null)`; `_sendView`
  re-sends `HostAwayMessage` with `_secondsToGo(endsAt)` after the away players; `_secondsToGo` (a four-line helper,
  so the file stays under 400) rounds up like the wait's own count and says 0 after the end.
- `packages/connection/lib/src/away_slots.dart` (159 lines) — `noteRoster`'s live set also skips `p.ownPlayer`, so a
  dropped own link keeps no slot and no viewer is told (the doc comment says why: its link goes with the host's own
  app, and the host-away pause covers that).
- `packages/connection/test/player_away_test.dart` (253 lines) — the 11 slot tests now run in `group('a joined
  phone')` over the socket only (was `for (final t in TestTransport.values)`), plus `group('the host's own player')`
  with one test: the own link drops mid-round → `host.players` is empty, no slot.
- `packages/connection/test/player_away_messages_test.dart` (328 lines) — same move for its 10 message tests, plus
  one own-player test: the drop sends no `player_away` to a viewer and holds no slot.
- `packages/connection/test/host_away_test.dart` (199 lines) — new per-transport test 'a viewer that pairs while the
  host is away is told, with the time left': `view_start`, `frame`, `host_away` with 29–30 s of the 30 given; then
  `hostAway(null)` and a viewer pairing after it gets `view_start`, `frame` and nothing of the host's away.
- `packages/party_host/lib/src/ui/away_card.dart` (172 lines) — `awayLayout`: `{a: 'OK'}`, `b`, `x`, `y`, `lb`, `rb`,
  `select` and `start` hidden; the card is wrapped in `PopScope(canPop: false)` and its `ControlsClaim` uses
  `Controls.menus(only: here, layout: awayLayout)`. The class doc says the round can't be left from here.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` (243 lines) — `_leaveForGames` (the route's
  `onPopInvokedWithResult`) now returns early while `playersAwayProvider` is not empty: the card's refusal reaches
  every pop entry of the route, so the pop callback fires with `didPop: false` and would otherwise leave for the
  picker.
- `packages/party_host/test/away_card_test.dart` (123 lines) — the N1 test 'B on a phone and the remote's Back leave
  the round where it waits'.
- `packages/party_host/test/live_host_service_test.dart` (201 lines) — `phone()` takes `capabilities`; the N5 test
  'the own player's link dropping mid-round keeps no slot and raises no card'.
- `docs/briefs/m12/fix-f1-report.md` — this report.

## N1: nothing pops a round that waits

Two halves, each needed (I removed each in turn and the new test failed both times: `Found 0 widgets with type
"PuzzleScreen"`):

1. The card's own `PopScope(canPop: false)`: the remote's Back, the system back and B on a phone (a menu's B is
   `Navigator.maybePop`) meet a route that refuses to pop.
2. The guard in `PuzzleScreen._leaveForGames`. `Route.popDisposition` is `doNotPop`, so
   `Navigator.maybePop` calls `route.onPopInvokedWithResult(false, …)`, which notifies **every** pop entry on the
   route, the screen's own included. Without the guard the screen then calls `leaveForGamePicker` itself — the round
   leaves even though the route "didn't pop".

The phones' half is the layout: no `b` in `awayLayout`, so `ControllerMenus` never maps B to `maybePop`; A ("OK") and
the arrows work the card's two buttons. `Controls.game()` still ignores B, untouched.

The arena's screen (`ShapeRaceScreen`, in `games_screen.dart`) needed no change: it has no `PopScope` of its own, so
on its route the card's refusal is the only answer to a pop, and the card is the same widget there
(`pause_menu_test`'s 'the Arena waits for an away phone too' still passes).

## N5: the own player is marked on its link

`GamePlayer.ownPlayer = ControllerInfo.isLocal`, i.e. the in-process link (`InProcessListener`), not a player ID and
not `local` (that flag is a `LocalPlayer`: the TV's keyboard). `away_slots.dart` skips `away`, `local`, `simulated`
and now `ownPlayer`; simulated controllers and local players are untouched, as the brief asks.

## Code health: `_sendView` and the host's away

A viewer **can** pair while the host is away: `HostPresence.hidden()` only calls `host.gameHost.hostAway(graceS)`; the
server keeps listening and the pairing code still works. So the item was not skipped: `_sendView` now re-sends the
host's away with the seconds still to go. The clock is the host's own (`nowMs`), so a viewer's message is right even
though it paired late; `hostAway(null)` and `endView` clear it, and a viewer pairing after either hears nothing of it.

## Computed test values

| Where | Value |
| --- | --- |
| away card, grace | 30 s (`ServerGameHost.hostGraceS`): 'The game goes on if they're back in 30 s' |
| away card, 6 s of the clock | 24 s left: '… back in 24 s' |
| away card, 30 s of the clock | 'The game goes on without them…' |
| `player_away`/`player_back` messages | `s: 10` with the messages test's 10 s grace; 5 s in the slot tests' `_grace` |
| the own player's roster | the host's own player is P2 behind the viewer's P1 (`['watcher', 'own']`) |
| host away re-sent to a late viewer | 30 s given, pairing a moment later → 29–30 s (`inInclusiveRange(29, 30)`) |

## Tests: counts and old → new

| Package | Before | After |
| --- | --- | --- |
| connection | 295 | 278 |
| host (party_host) | 117 | 119 |
| phone | 348 | 348 |
| tv | no count printed (smoke run) | same |

`connection −17` = `player_away_test` 23 → 13, `player_away_messages_test` 21 → 12, `host_away_test` 10 → 12. The
drop is the in-process half of the two away suites: that link is the host's own player now, so an in-process "joined
phone" is exactly the case N5 excludes. `host +2` is the two new tests. Old → new:

| Old | New |
| --- | --- |
| `player_away_test`: 11 slot tests × `for (final t in TestTransport.values)` (22) | `group('a joined phone')` over `TestTransport.webSocket` (11), bodies unchanged |
| — (the in-process slot cases) | `group('the host's own player')`: 'a drop of its link keeps no slot: the host itself is what dropped' |
| `player_away_messages_test`: 10 message tests × 2 transports (20) | `group('a joined phone')` over the socket (10), bodies unchanged |
| — (the in-process message cases) | `group('the host's own player')`: 'the drop of its link tells a viewer nothing: no player_away for the host' |
| `host_away_test`: 4 tests × 2 transports (8) | 5 × 2 (10): 'a viewer that pairs while the host is away is told, with the time left' added to both; in-process stays, this is the view, not a slot |
| — (the party_host side) | `away_card_test`: 'B on a phone and the remote's Back leave the round where it waits'; `live_host_service_test`: 'the own player's link dropping mid-round keeps no slot and raises no card' |

Each new test was run with its fix removed and failed for the bug's reason:

- N1, `canPop: true` on the card → the round's `PuzzleScreen` is gone; guard removed → the same.
- N5 (connection), the `!p.ownPlayer` term removed → `player_away{player: own, n: 2, s: 10}` and the own player's slot
  held.
- N5 (party_host), the same edit → `players` is `['watcher', 'own']` (the own player away, its slot held).
- `_sendView`, the re-send removed → `['view_start', 'frame']` where `['view_start', 'frame', 'host_away']` is due,
  both transports.

## Self-check (docs/review-rules.md part A, 1–5)

1. **Every host setup.** TV/PC host with the away card: `away_card_test` (fake host, the remote's OK and Back); phone
   on "Play on this phone" (the own player over the in-process link): `live_host_service_test`'s own-player test;
   phone on "Show on this device" (no view shared, so no viewers to tell): `host_away_test`'s 'with shareView false a
   viewer gets nothing, and true reaches it from the next view_start'; a joined phone: `player_away_test`'s 'a joined
   phone' group. One build older: no wire change — no new
   message or field, `host_away` already exists and `ownPlayer` is host-side only — so nothing differs.
2. **When kept state starts and ends.** The away slot: tests 'the slot ends when the grace is over', 'every away slot
   ends when the round is over', 'a phone that drops with no round running leaves at once', 'dispose cancels the away
   timers' (`player_away_test`). The host's away clock: set in `hostAway`, cleared by `startView`, `endView` and
   `hostAway(null)`, shown in `host_away_test`'s new test (a viewer after the host is back hears nothing); no view
   running → `hostAway` returns early, and `_sendView` returns early when `_viewStart` is null.
3. **How a new state combines with the others.** Away card + the remote's Back/system back + B on a phone:
   `away_card_test`'s N1 test; away card + the pause menu: 'Start opens no menu while the round waits for an away
   phone' and 'the host going away and a phone away pause the round once' (`pause_menu_test`) — `Pausable` still owns
   the pause, and a drop of the own link no longer reaches it (`live_host_service_test`: `playersAwayProvider` empty,
   which is the card's and the pause's only source); away card + results: `_leaveForGames` returns early only while
   the away list is not empty, so the results' own back is unchanged (`puzzle_results_test`).
4. **Stay in the job's folder.** All edits are inside `packages/connection`, `packages/party_host` and this report.
5. **Stop rather than overstep.** Not needed: everything the brief asks fits in `allow:`. The one thing I did not do
   is delete or restore the three generated Windows files (Question 3) — they are outside `allow:` and content-identical.

## Questions

1. The `ownPlayer` mark excludes the in-process link from away slots, which also means the **in-process transport is no
   longer a plain "joined phone" in connection's tests**: the two away suites now run on the socket only. If a test
   ever needs a second non-host in-process controller, `isLocal` will be wrong (it is per link, and there is one
   in-process listener). Should `InProcessListener` carry a "mine" flag instead, so a test can open an in-process link
   that is not the host's own player?
2. `awayLayout` hides `start` as well as `lb`/`rb`/`select`: the card has two buttons, and Start was the pause menu's
   key. Is hiding Start right, or should Start still open the pause menu over the card (the pause menu and the card
   both being up is the one combination I did not try)?
3. Three generated Windows files under `tv_test_app/windows/flutter/` show as modified after the test runs
   (`generated_plugin_registrant.cc`, `.h`, `generated_plugins.cmake`). `git diff` on them is empty — line endings
   only, rewritten by `flutter pub get` — and they are outside `allow:`, so I left them.

## Suggestions

- `server_game_host.dart` is at 394 lines (limit 400). The next change to it should move the view's re-send block
  (`_sendView`, `_secondsToGo`) into a small class of its own, or the file hits the limit.
- `review.sh` flags `away_card.dart:18` with a `func` note ("49 lines (>40): hidden:"); the set literal is nine lines,
  so the heuristic seems to count from `hidden:` to the end of the class. Worth a look if notes are to stay meaningful.

## Commit message

Stop B and the Back ending a round that waits

While the away card is up the phones get A and the arrows and no B, and
the card refuses the route's Back itself, so neither B on a phone nor
the remote's Back can end a round that is only waiting; the screen's pop
callback learns not to leave for the games while players are away. The
host phone's own player is now marked on the link it came in on
(`ControllerInfo.isLocal`) and keeps no away slot: its link drops with
the host's own app, which the host-away pause covers. A viewer that
pairs while the host is away is told with the seconds still to go.

## Status row

M12 build 4 fix-f1 done at G4: the away card no longer lets B or the Back end the round, and the host phone's own
player never holds an away slot or raises the card; a viewer pairing during the host's away is told with the time
left; open: nothing from this brief.

## Delete

- none
