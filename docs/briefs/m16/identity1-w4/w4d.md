job: M16 w4d the `players` list also holds local players and away players (owner Q4, Q5)
pub: no
turns: 45
expected-min: 35
stop: after the rows follow the game host's players. No change to a frame's roster or `chars`, no reservation work (that is w4f).
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/host_players_broadcast.dart:1-30 (playerRows, broadcastPlayers) · packages/connection/lib/src/host_server.dart:75-105 and :355-371 · packages/connection/lib/src/server_game_host.dart:15-35,168-195,298-320,325-342 (players, _checkPlayers, dispose) · packages/connection/lib/src/game_types.dart:6-60 (GamePlayer) · packages/protocol/lib/src/identity.dart:1-10 (PlayerRow) · docs/protocol.md:220 · tests that may pin the old rows or count `players` messages: packages/connection/test/identity_host_test.dart, identity_reservation_test.dart; read them first
changes: playerSource · playerRows
decisions (owner, Nov 23): Q4 yes: local players (TV keyboard, host phone's own player) get a `players` row with `PlayerCharacter.forPlayer(number)`. Q5 yes: `players` keeps an away player while the round holds their slot (same rows as the frame's `pl`).
do:
1 host_server.dart: one public field `List<PlayerRow> Function()? playerSource;` with a doc comment (where `players` rows come from when a game host runs; null: the paired sessions). Keep the file under 380 lines (it has 371): no other code there.
2 host_players_broadcast.dart: `playerRows` returns `playerSource?.call()` when set, else today's session rows (move those into a private getter `_sessionRows`).
3 server_game_host.dart: set `server.playerSource` in the constructor to a method that maps `players` (sessions, locals and away) to rows: id, number, name `p.nickname ?? ''`, character `p.character ?? PlayerCharacter.forPlayer(p.number)`; clear it in dispose. In `_checkPlayers`, when the roster changed (after `_lastPlayers = now`), call `server.broadcastPlayers()`. An identical duplicate `players` list at a pairing is harmless; adapt old tests that counted lists to the last list.
4 docs/protocol.md:220: the list holds every player the round knows: paired, away while the slot is held, and local players, in number order.
5 New test packages/connection/test/identity_rows_test.dart (fails on old code): a local player and an away player are in the next `players` a phone hears; a local player's character is its number's default; the away player leaves the list when the slot ends.
6 Report: how old tests changed.
allow: packages/connection/lib/src/host_server.dart · packages/connection/lib/src/host_players_broadcast.dart · packages/connection/lib/src/server_game_host.dart · docs/protocol.md · packages/connection/test/identity_rows_test.dart · packages/connection/test/identity_host_test.dart · packages/connection/test/identity_reservation_test.dart · docs/briefs/m16/identity1-w4/w4d-report.md
check: format analyze connection host
report: docs/briefs/m16/identity1-w4/w4d-report.md
