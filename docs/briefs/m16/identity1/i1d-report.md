# i1d report: host side, gated character change, players broadcast, frame chars

## Summary

- **Tests first.** NEW `packages/connection/test/identity_host_test.dart`, 6 tests × both transports =
  **12 tests, all green**. Written and run before the code: 10 of the 12 failed on the old code; the
  two that passed ("a phone without the identity capability is told nothing new") state the old
  behaviour a peer one build older must keep, so they are guards rather than new behaviour.
- **The gate.** `SetCharacterMessage` now reaches the host. In the lobby and between rounds it applies
  at once and the answer (a `player` message) carries the character the host gave (nearest free when
  another player wears it). During a round it is kept on the session and applied when the round ends,
  so a running round's players never change. A round is `ServerGameHost.startView` … `endView`.
- **`players`.** Sent to every paired controller that listed `Capability.identity`, and to no other,
  after pairing, after a leave, and after a character change. Rows are every paired player, by number,
  whether or not that player's phone listed identity.
- **`chars`.** Each published frame gets the character of every player in its roster (away players
  included); the server sends it with `chars` to identity phones only and takes `chars` out of its own
  copy for the rest, so a phone one build older gets the frame it has always had, byte for byte.
- **The split.** `server_game_host.dart` 395 → **342**: its view side (start, frames, results, end,
  host away, late joiner) moved to NEW `server_game_frames.dart` as `RoundView`; the class keeps the
  `GameHost` members as one-line delegates. NEW `host_players_broadcast.dart` (part of
  `host_server.dart`, 133) holds the players message, the round gate and the per-capability send.
- **Checks.** `tools/check.sh format analyze` PASS, `tools/check.sh host` PASS (220 s),
  `tools/mine.sh` OK. `tools/check.sh connection`: 336 passed, **2 failed**, both in `m9_test.dart:33`
  and both **pre-existing**: the phone's hello now lists `identity` (i1e's
  `ControllerIdentity.libraryCapabilities`), and that test expects exactly `[metrics, rating]`. See
  Question 2.
- Line counts: `host_connection.dart` 367 → **380**, `host_server.dart` 370 → **371**,
  `server_game_host.dart` 395 → **342**, `server_game_frames.dart` **172**,
  `host_players_broadcast.dart` **133**, `identity_host_test.dart` **260**. No lib file over 380.

## Files changed

- `packages/connection/lib/src/host_players_broadcast.dart` — NEW, part of `host_server.dart`:
  `HostPlayersBroadcast` (the rows, `broadcastPlayers`, `roundStarted`/`roundEnded`,
  `characterChosen`, `_wear`) and the send helpers `_sendToAll`, `_encodeTo`, `_forSession`,
  `_withoutCharacters`.
- `packages/connection/lib/src/server_game_frames.dart` — NEW, part of `server_game_host.dart`:
  `RoundView`, the view code moved out of `server_game_host.dart` unchanged except the round hooks,
  plus `_withCharacters` (fills a frame's `chars` from the roster).
- `packages/connection/lib/src/server_game_host.dart` — the five `GameHost` view members are one-line
  delegates; `_view` (`RoundView`) and `_characters` (roster characters, refreshed in
  `_checkPlayers`); `shareView` is a getter/setter over the view; `_sendView`/`_secondsToGo`/`_isViewer`
  moved. 395 → 342.
- `packages/connection/lib/src/host_server.dart` — `part 'host_players_broadcast.dart';`,
  `_roundRunning`, `PlayersMessage() => Capability.identity` in `capabilityFor`, `sendToAll`/`send`
  go through the new part's helpers, and `_SessionHost` gains `characterChosen`/`playersChanged`.
- `packages/connection/lib/src/host_connection.dart` — `heldCharacter`, the `SetCharacterMessage` case,
  and `playersChanged()` after a pairing and after a session that was paired ends. 367 → 380.
- `packages/connection/test/identity_host_test.dart` — NEW, 12 tests.
- `docs/protocol.md` — §8d's `players`, `set_character` and `chars` paragraphs.
- `docs/briefs/m16/identity1/i1d-report.md` — this report.

`packages/party_host/lib/testing.dart` and `host_types.dart` needed no change (the fakes never touch
the server's sessions).

## What each test shows, and the values it computed

All six run under both transports (WebSocket = a phone on the LAN; inProcess = the host phone's own
player and "Show on this device").

| Test | Setup | Expected |
|---|---|---|
| a character chosen in the lobby applies, and its answer carries what the host gave | phone-1 pairs wearing (4, crown), then asks for (2, bow) | answer is (2, bow): slot 2 and the bow are both free; `game.players` shows (2, bow) |
| a change onto a taken pick gets the nearest free character | phone-1 wears (4, crown); phone-2 (player 2) pairs with no choice and asks for the crown | phone-2 paired as (2, antenna) (`forPlayer(2)`); its answer is (5, tuft): slot 4 taken, 5 free up; crown taken, nothing above it, so tuft down |
| a change during a round waits for the round to end, so a running round's players never change | phone-1 wears (4, crown); `startView` + `publishFrame(0)`; then it asks for (2, bow) | during the round: one `player` message only (the crown) and `game.players` still the crown; after `endView`: messages `[crown, bow]` and the roster (2, bow) |
| the players message goes to every identity phone on join, leave and change, and to no other | phone-9 (view only, player 1) and phone-1 (identity, player 2) pair; a `ControllerClient` phone-2 (player 3) joins and leaves; phone-1 changes to (2, bow) | phone-1's rows by number: `[phone-9, phone-1]`, then `[phone-9, phone-1, phone-2]`, then `[phone-9, phone-1]`, then the same with phone-1's row at (2, bow); phone-9 never gets one |
| frames carry chars only to a phone that listed identity, live and mid-round | phone-1 (4, crown) and phone-2 (2, bow); frame n=0 with roster `{phone-1: (1, "Mia"), phone-2: (2, "Dad")}` | phone-1's frame `chars` = `{phone-1: (4, crown), phone-2: (2, bow)}`; phone-2's frame has none and its payload equals `frameOf(0).toPayload()`; phone-3, which pairs mid-round, gets that frame (n=0) with the same two entries and none for itself (it is not in the roster) |
| a phone without the identity capability is told nothing new | phone-2 (view only) wears (2, bow) and a frame goes out | its `player` message is (2, bow), it gets no `players` message, its frame has no `chars`, and `server.send` of a haptic still returns true |

## Decisions

1. **A round is the host's view.** `startView` marks the round on the server (`roundStarted`) and
   `endView` marks its end and applies the held changes (`roundEnded`). That is the only round the
   server can see; it also covers a host that doesn't share the view, because the round still runs on
   its own screen. Between rounds = after `endView`, the lobby = before the first `startView`.
2. **The characters a frame carries are the roster's.** `ServerGameHost` keeps one map (player ID →
   character) refreshed at every roster check from `players`, which includes away players, and
   `RoundView` filters it to the frame's roster. The server itself knows only live sessions, so filling
   from its sessions would have dropped a dropped player's character mid-round.
3. **The gate lives on the server, next to the sessions.** `HostConnection._handle` hands the message
   to the server (`characterChosen`), which decides hold-or-apply, reserves through the existing
   `_reserveCharacter` and sends the `player` answer. That kept `host_connection.dart` at 380; the
   first cut (the whole flow in `host_connection.dart`) reached 419.
4. **`players` rows are paired players only, by number.** A local player (the TV's keyboard player, the
   host phone's own) has no character and the wire requires one per row, so it has no row. Question 3.
5. **The server strips `chars`, the game side fills them.** One rule on the server ("a message goes
   only to a controller that listed what it needs"), so `send` and `sendToAll` both hand a phone
   without identity the frame without `chars`; that also covers the frame a late joiner is replayed.
6. **A repeated choice still gets an answer.** `_wear` always sends the `player` message (the phone
   asked, and needs to hear what it wears), and broadcasts `players` only when the look really changed.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** The TV, the PC and a phone hosting all run one `HostServer` + `ServerGameHost`,
   so every setup runs this code; the tests run it on both transports — `webSocket` (a phone on the
   LAN) and `inProcess` (a phone on "Play on this phone" / "Show on this device"). A joined phone is
   every test's subject. A peer one build older is a `WirePhone` listing only `view`: it gets no
   `players` and no `chars`, and its frame payload equals the published one — "frames carry chars only
   to a phone that listed identity…" and "a phone without the identity capability is told nothing new".
2. **When kept state starts and ends.** `_roundRunning`: false at start, true from `roundStarted`
   (`startView`) to `roundEnded` (`endView`). `heldCharacter`: null at pairing, set by a mid-round
   `set_character`, cleared when it is applied or the session ends. `_characters`: replaced whole at
   every roster check, empty at start. With nothing going on no round runs (a change applies at once),
   nothing is held (the round end broadcasts nothing), and with no paired player the `players` message
   has no rows and goes nowhere — "a character chosen in the lobby applies…" and "a change during a
   round waits…".
3. **Combining with other states.** A pause and the host's away both leave the view on, so a change
   waits, like any mid-round one; "Get ready" is after `startView`, so it waits too; `showResults`
   keeps the view on, so a change waits until the round's `endView`. A dropped link ends the session:
   its held change goes with it and its row leaves the list at once — "the players message goes…on
   join, leave and change". A phone that leaves for good is the same `disconnect` (`_ended`).
4. **Job folder and `allow:`.** Only the nine allowed files plus this report were written. The
   uncommitted `packages/test_game/*` changes and `arena_identity_test.dart` are i1f's, and
   `DRIVER-NOTES.md` / `run.log` are the driver's.
5. **Stop rather than overstep.** Nothing was edited outside `allow:`. Three things need files outside
   it: the host apps don't list `Capability.identity` (Question 1), `m9_test.dart` fails on i1e's
   identity in the hello (Question 2), and a local player has no `players` row (Question 3).
6. **Every look.** No UI and no widget in this job: no menu-look or TV-look case, and no look-sized
   box.

## Questions

1. **Who lists `identity` on the host?** `controller_app/lib/src/storage.dart:55` and
   `packages/party_host/lib/src/host_service.dart:142` do not, so in the apps the TV's welcome says no
   identity: phones never send `set_character` and never get `players`/`chars`. Both files are outside
   this job's `allow:`; the tests start their host with `capabilities: [view, identity]`. Should the two
   lists gain `Capability.identity`?
2. **`m9_test.dart:33` fails, and it is not mine.** "each side learns what the other supports" expects
   the phone's hello capabilities to be exactly `[metrics, rating]`; i1e's
   `ControllerIdentity.libraryCapabilities` adds `identity` to every hello, so the host sees
   `[metrics, rating, identity]` (2 failures, one per transport). Fixing it means editing `m9_test.dart`
   (outside `allow:`), or dropping identity from `libraryCapabilities`. Was that test meant to be
   widened with i1e?
3. **Local players have no row in `players`.** The TV's keyboard player and the host phone's own player
   (`ServerGameHost.addLocalPlayer`) have no character, so they are missing from a phone's lobby list
   while the TV shows them. Give them `PlayerCharacter.forPlayer(number)` on the wire, as the host's
   own screens draw them?
4. **A reconnect during a round is not gated.** Pairing always gives the hello's `character` (i1c's
   tests, M14), so a phone that drops mid-round and comes back with a new pick in its hello changes the
   running round's look at once. Only `set_character` is gated, as the brief says. Should `_accept`
   hold the hello's pick too while a round runs?
5. **Should `players` keep an away player?** A phone that drops leaves the list at once, while the round
   may still hold its slot, and the frames keep showing that player (with their character). Keeping the
   row would need the away slots on the server side.

## Suggestions (not acted on)

- Put `Capability.identity` in the two host capability lists (Question 1) — until then the feature is
  dormant in the apps although every part of it is in place.
- A `FrameMessage.copyWith` in protocol would replace the two copies of the field list in
  `server_game_frames.dart` and `host_players_broadcast.dart`.

## Hand-over

- i1e2/i1g: the phone gets `players` and `chars` from a host that lists `identity`; nothing on the phone
  side needs to change for this job.
- Still open: the host app capability lists (Question 1) and the `m9_test` expectations (Question 2).

## Commit message

host: gate character changes, send players and frame chars

The host now takes a phone's set_character: in the lobby and between
rounds it applies at once and the player message says which character
the host gave (nearest free when taken); during a round it waits for
the round's end, so a running round's players never change.
players goes to every phone that listed identity on join, leave and
change, and each frame carries chars only to those phones, so a phone
one build older gets today's messages unchanged.
The server's view code moved to server_game_frames.dart (RoundView),
leaving server_game_host.dart at 342 lines; the new code is in
host_players_broadcast.dart. 12 new tests on both transports.

## Status row

| identity1 i1d | done: host takes `set_character` (lobby/between rounds at once, mid-round at the round's end), `players` to identity phones on join/leave/change, frames' `chars` for identity phones only, `server_game_host.dart` 342 with `RoundView` moved to `server_game_frames.dart`; 12 new tests green, host suite 220 s PASS, connection 336 passed / 2 pre-existing m9 failures | open: the host apps don't list `Capability.identity` yet (storage.dart, party_host host_service.dart, outside this job), `m9_test.dart:33` expects the old hello capabilities (i1e's), local players have no `players` row, a reconnect's hello character is not gated |

## Delete

- none
