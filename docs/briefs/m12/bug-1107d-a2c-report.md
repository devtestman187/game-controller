# M12 bug 1107d A2 + C — G4 report: the other phones learn a player is away, and say so

Done at G4, the gate the brief names: the plan's A2 (the wire) and C (the phone's card), with the brief's extras
(the 0.12.0 test, two players away at once, the phone that pairs mid-away). No file outside the allow list was edited.

## Files changed

- `packages/protocol/lib/src/view.dart` — 237 → 294 lines: `PlayerAwayMessage` (`player`, `n`, `s`; `n` 1 or more and
  `s` 0 or more, else a `FormatException` naming the field) and `PlayerBackMessage` (`player`), both with the
  `wireType`/`toPayload`/`fromPayload` shape the other view messages use.
- `packages/protocol/lib/src/codec.dart` — the two decoders in `_decoders`, so a phone of another version drops them
  as unknown instead of closing with 4003.
- `packages/protocol/test/view_test.dart` — 364 → 420 lines: 3 tests (below).
- `packages/connection/lib/src/away_slots.dart` — 63 → 156 lines: `AwaySlots` now owns the telling as well as the
  slots. It takes `server`, `grace`, `nowMs()`, `hasView()` and `onEnded()`, and sends `player_away` when a slot is
  held (only while a view runs), `player_back` from `end` (skipping the phone that is coming back), `endAll` (the view
  has ended by then, so nobody hears), `sendTo(controllerId)` for a phone that pairs mid-away, and `dispose`.
- `packages/connection/lib/src/server_game_host.dart` — 396 → 375 lines: `_away` is built in the constructor with the
  host's clock and `hasView: () => _viewStart != null`; `_checkPlayers` starts with `_away.noteRoster(players,
  roundRunning: _roundRunning)`; `_sendView` ends with `_away.sendTo(controllerId)`; `goOnWithout` is
  `if (_away.end(playerId)) _checkPlayers()`. The `_live` map and `_updateSlots`/`_holdSlot` moved into `AwaySlots`:
  the file was at 396 lines and had to shrink, not grow.
- `packages/connection/lib/src/client_controls.dart` — 161 → 202 lines: the `PlayerAway(playerId, number, secondsLeft,
  arrivedAtMs)` and `PlayerBack(playerId)` view events, and the adders the client's handler calls.
- `packages/connection/lib/src/client_messages.dart` — the two arms; both return while no view shows, like the host's.
- `packages/connection/lib/src/host_server.dart` — `capabilityFor`: both are `Capability.view`.
- `packages/connection/lib/src/host_connection.dart` — a controller that sends either closes with 4003, as for the
  other view messages.
- `packages/connection/lib/connection.dart` — `PlayerAway` and `PlayerBack` in the `client_controls.dart` export list.
- `packages/connection/bin/sim_view.dart` — `player_away $playerId P$number s=$secondsLeft` and `player_back $playerId`.
- `packages/connection/test/helpers.dart` — `playersUntil` moved here (A1's copy was private to its file), 14 lines.
- `packages/connection/test/player_away_test.dart` — −13 lines: its private `playersUntil` (now shared).
- `packages/connection/test/player_away_messages_test.dart` — **new**, 298 lines, 21 tests (below).
- `packages/game_kit/lib/src/frame_view.dart` — the `HostAway() || HostBack()` arm gains `PlayerAway() || PlayerBack()`
  with the comment that frames stop while the game waits for a player: the view keeps drawing its newest frame.
- `controller_app/lib/src/providers/view.dart` — 190 → 243 lines: `HostWaitKind.playerAway`, `AwayWait`
  (`playerId`, `number`, `secondsLeft`, `sinceMs`), `HostWait` gains `away` (one entry per player, in player order),
  and `HostWaitNotifier` keeps `playerId → AwayWait`: added on `PlayerAway` (never for this phone's own player id,
  `client.identity.controllerId`), removed on `PlayerBack`, expired entries dropped on the next `ViewFrame`, and all
  cleared on `ViewStarted`, `ViewEnded`, a drop and an idle client. `_publish` is `_away ?? _players ?? _dropped`: the
  host's own wait wins.
- `controller_app/lib/src/ui/waiting_card.dart` — 98 → 149 lines: `_AwayLines` (a private widget: one player's title
  and line, its own countdown on the phone's clock) and `_hostLines` (the old two lines, unchanged); Leave game is the
  same `Key('leaveGame')` button, `FilledButton` only when the host has left.
- `controller_app/test/support/fakes.dart` — `playerAway(playerId, number, secondsLeft)` and `playerBack(playerId)`.
- `controller_app/test/waiting_card_test.dart` — 175 → 280 lines: 6 tests (below), a second group.
- `docs/protocol.md` — §4's `view` row lists the two types; §10a's table has both rows; a "Waiting for a player"
  paragraph after "Waiting for the host"; the pairing paragraph says a mid-away viewer gets a `player_away` after the
  start and the frame; §11's `view` row; §12 "A player away before the round goes on | 30 s (the same grace, per
  player)".
- `docs/briefs/m12/bug-1107d-a2c-report.md` — this report.

## The messages, on the wire

```json
{"v":1,"t":"player_away","player":"p2","n":2,"s":24}
{"v":1,"t":"player_back","player":"p2"}
```

`player` is the controller/player id as in a frame's `pl` and `acks`; `n` is the number `PlayerMessage` gives, from 1;
`s` is whole seconds, rounded up, 0 at the end of the grace. `player_back` means back, the grace over with the round
going on without them, or `goOnWithout`.

## The rules, and the values they were checked with

`player_away_messages_test.dart`, on both transports (webSocket and inProcess), grace 10 s in the "kept" tests so the
seconds left are a whole 10 whenever the message is built:

1. **a drop and a return send the pair, in order, with the seconds left** — `['player_away', 'player_back']`, id
   `phone-1`, number **2** (the viewer paired first and is player 1), `s` **10**: the whole grace, since the message is
   built when the slot is held.
2. **a viewer that pairs mid-away gets `view_start`, the latest frame and then `player_away`** — exactly
   `['view_start', 'frame', 'player_away']`, id `phone-1`, number **1**, `s` in 1..30: the default grace is 30 s
   (`ServerGameHost.hostGraceS`), one second may have gone by.
3. **the phone that comes back hears no `player_back` for itself** — a viewer phone that drops and pairs back gets no
   `PlayerBack` and no `PlayerAway`, while the other viewer gets `['player_away', 'player_back']`.
4. **the grace running out sends `player_back`** — grace 1 s, the message arrives on its own.
5. **`goOnWithout` sends `player_back` at once** — the pair is complete before the grace is anywhere near over.
6. **the round ending takes the slot without a `player_back`** — `['view_start', 'player_away', 'view_end']` (see
   "Not sure" 1).
7. **a controller without `view` gets neither** — the viewer gets exactly one `player_away`, the other phone none.
8. **a host that shows the game on its own screen (`shareView` false) sends neither** — the watcher has `view` and gets
   nothing.
9. **the phone hears the pair as events** — `PlayerAway` with id `phone-1`, number 2, `secondsLeft` 10, `arrivedAtMs`
   non-negative (this phone's clock when it handled it), then `PlayerBack` with `phone-1`.
10. **an unknown type is dropped, not a 4003** — a `player_hidden` frame written straight at a `FakeHost` is read as
    unknown, so the phone stays connected: the 0.12.0 behaviour the brief asks to pin.
11. **`player_away` and `player_back` need `Capability.view`** — `HostServer.capabilityFor` on both.

`view_test.dart`:

1. **round trip and wire keys** — `away.toPayload()` is `{player: 'p2', n: 2, s: 24}`, the decoded message equals the
   sent one, and `player_back`'s body has exactly one field.
2. **0 s is allowed** — the grace is over, the round goes on without them.
3. **malformed tables** — the field is named in every failure: `player` missing, `n` missing/0/`"2"`, `s` missing/−1,
   and `player_back` without a player.

`waiting_card_test.dart`, in a new group:

1. **it says which player is away and counts down** — `Player 2 is away`, `The game goes on if they're back in 12 s`,
   the Arena still drawn under the card, a `TextButton` Leave game; 5 s on the phone's clock and one tick later
   `... in 7 s`; `playerBack('p2')` takes the card away and leaves the game.
2. **a countdown that runs out says the game goes on without them** — a player away with 2 s left, 3 s later
   `The game goes on without them…`, still a TextButton (the host has not left); the next frame takes the card away.
3. **two away at once get a line each** — players 2 and 3 (12 s and 20 s) give two titles and two lines; `playerBack`
   for 2 leaves player 3's line and keeps the card.
4. **the host's own wait wins over a player's** — `Player 2 is away`, then `hostAway(30)` shows the host's card only,
   then `hostBack()` brings the player's line back.
5. **the phone that was away itself shows no card** — `playerAway` with this phone's own id (`test`) draws nothing.
6. **a drop hides the line, and the view coming back with `player_away` puts it up again** — the reconnect card, then
   `view_start` and `player_away` after the link is back.

What the phone says, exactly: `Player 2 is away` · `The game goes on if they're back in 12 s` ·
`The game goes on without them…` · Leave game (unchanged).

## Test counts

| suite | before | after |
| --- | --- | --- |
| protocol | 104 | **107** (+3) |
| connection | 274 | **295** (+21: the new file) |
| phone (controller_app) | 339 | **345** (+6) |
| kit, host, tv | no test added or changed | 34, 103, unchanged |

The phone's "before" is 345 minus the 6 added tests (the suite was not measured before the change in this job's log);
protocol and connection were.

Failing first: the connection tests were written before the client's view events existed, and the first run with the
code in had **8 passed, 8 failed**; all 8 were the tests' own fixtures, not the host's behaviour: (a) a `WirePhone`
that stays quiet is dropped by the host's heartbeat after 1.5 s of silence (the tests' `hbTimeout`), so the
"controller without view" test's extra phone had to pair after the view was up rather than before it, (b) the watcher
in the client-events test was never connected, (c) the grace-expiry test waited for "nobody away" before the host had
noticed the drop. One existing
test did break and its fix is real: `view_test`'s "a viewer that drops and reconnects mid-view gets the start and the
latest frame again" received a `PlayerBack` for itself before its `view_start`, which is the case the brief says must
not happen — `AwaySlots._tellBack` now skips the phone that is coming back. The widget tests were written after the
card and the provider (unlike the rule): their red state is missing types, not a wrong card.

## Checks

- `tools/check.sh format analyze protocol connection kit host phone tv` — all PASS: format (1 s), analyze (9 s),
  protocol 107, connection 295, kit 34, host 103, phone 345, tv (10 s).
- `tools/review.sh` — 0 fail, 7 notes: 3 `number` (the `SizedBox` heights 8 and 4 in `waiting_card.dart`, as the old
  card had), 1 `func` (`client_messages.dart`'s `onData`, pre-existing), 3 `size` (connection lib files at 398, 385
  and 375 lines, under the 400 limit).

## Not sure

1. **"The round over" sends no `player_back`.** The brief lists the round's end among the ways a slot ends, but
   `endView` clears the view before `endAll()`, so `hasView()` is false and nothing goes out: the phone gets
   `view_end`, which tears its view and card down anyway. The test pins it (`view_start`, `player_away`, `view_end`).
   Say if a `player_back` before `view_end` is wanted instead; the phone's client would drop it (`!_showsView`).
2. **The phone's own id.** The quiet-phone case is covered twice: the host never sends the returning phone a
   `player_back` for itself, and the notifier compares `playerId` with `client.identity.controllerId` and skips it.
   The second is belt and braces, but it is what the brief's "never shows a card for its own id" says literally.
3. **`AwaySlots` grew the sending side.** The plan put the messages in `server_game_host.dart`, which was at 396 of
   its 400 lines: `_live`, `_updateSlots` and `_holdSlot` moved into `away_slots.dart` (now 156 lines) so the host
   file could take `sendTo`/`noteRoster`. Behaviour is A1's, unchanged; `player_away_test.dart` passes untouched
   apart from the moved helper and `party_host` was not touched.
4. **Expiry on the next frame uses this phone's clock**, `nowMs - sinceMs >= secondsLeft * 1000`; a phone whose clock
   jumps between two frames could drop a line early or late by the jump. The countdown itself has the same exposure
   as the host's card already had (m12-joined-view §0.3).
5. **Two away players with the same number** can't happen (the host gives numbers from 1), so sorting by number is a
   stable order for the card; the entries themselves are keyed by player id.
6. **Two players away take most of the card** (two titles and two lines before the button), and on a small landscape
   phone it is close to full height. Not measured on a device; the widget tests at 852×393 find every text.
7. **Three `tv_test_app/windows` generated files show in `git status`** after the Flutter tool ran the tv check. I
   did not edit them and `git diff` lists no content (line endings only), as A1's report notes.
8. **Suggestion, not acted on:** the host could send `player_away` again when a phone pairs and the round waits,
   which is what `sendTo` does, but it does not repeat it to a phone that was already watching; a viewer that missed
   it (a lost frame, a reconnect mid-view) has no way back except `view_start`. A repeat on `goOnWithout` is not
   needed: that is `player_back`.

## Commit message

feat(m12): tell the other phones a player is away

ServerGameHost sends player_away {player, n, s} and player_back to the
viewers of a running view, from AwaySlots: when a slot is held, when it
ends, and again after view_start to a phone that pairs mid-away. The
type is unknown to older phones, whose codec drops it. The phone's wait
gets HostWaitKind.playerAway, one card line per away player with its
own countdown, the host's own wait first, and none for the phone that
was away.

## Status row

| Bug 1107d A2 + C | G4 done ([bug-1107d-a2c-report.md](bug-1107d-a2c-report.md)): `player_away {player, n, s}` and `player_back` under `view` from `AwaySlots` (on hold, on end, and after `view_start` to a mid-away pairing), dropped by older phones' codecs; the phone's card gets `HostWaitKind.playerAway`, one "Player N is away" line each with a countdown, "The game goes on without them…" at 0 until `player_back` or the next frame, the host's wait first and no line for the phone that was away. Tests protocol 104→107, connection 274→295, phone 339→345; checks pass, review 0 fail. Open: the milestone's STATUS row and the merge of A2/C with A1/B |

## Delete

- none
