job: M16 identity1-fix fm1: away player keeps its character, a phone never gets a local player's look, typed json map
expected-min: 25
turns: 50
pub: no
stop: after it. No other change.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/identity1/MILESTONE-VERDICTS.md (fm1) · packages/connection/lib/src/away_slots.dart:129-147 · packages/connection/lib/src/host_character_reservation.dart:36-54 · packages/connection/lib/src/host_server.dart:84-90 (playerSource) · packages/connection/lib/src/server_game_host.dart:322-334 (_playerRows) · packages/protocol/lib/src/character.dart:104-125 · packages/connection/test/identity_rows_test.dart:1-100 (helpers, away test: copy its shape) · packages/connection/test/wire_phone.dart:30-60 (open takes `character`) · docs/coding-guidelines.md
changes: _Slot · HostCharacterReservation · _fromFields
decisions (owner, Nov 23 review): "Run the fix batch fm1-fm3": yes. Owner Q4 (identity1): the phone lobby matches the TV, so a phone never gets a local player's look.
do:
1 Tests first, NEW packages/connection/test/identity_fix_test.dart (copy the helpers it needs; do not edit identity_rows_test.dart): (a) a phone that paired with a non-default character (e.g. colour slot 5, crown) drops (webSocket only, as identity_rows_test.dart:57), and the next `players` a phone hears has its away row with that character, not forPlayer(2); (b) a game host with a local player (addLocalPlayer, number 1, default look forPlayer(1)): a phone that asks for forPlayer(1) in its hello is given another character (nearest free), in the `player` message and in `players`. Both fail on the old code.
2 away_slots.dart:139: the away GamePlayer keeps `character: player.character`.
3 host_character_reservation.dart `_reserveCharacter`: also add to `taken` the character of every row of `playerSource?.call()` whose id is not this session's controllerId (the game's local and away players). Keep the existing taken sources.
4 character.dart:107 `_fromFields`: type the map parameter `Map<String, Object?>` (cast at the two callers: `json.cast<String, Object?>()`); behaviour and error messages unchanged.
Every-look rule: no UI; say so in the self-check.
allow: packages/protocol/lib/src/identity.dart · packages/connection/lib/src/away_slots.dart · packages/connection/lib/src/host_character_reservation.dart · packages/protocol/lib/src/character.dart · packages/connection/test/identity_fix_test.dart · packages/connection/test/identity_rows_test.dart · packages/connection/test/identity_reserve_minute_test.dart
check: format analyze protocol connection
report: docs/briefs/m16/identity1-fix/fm1-report.md
