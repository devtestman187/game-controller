job: M16 identity1-fix fq6: a re-pairing phone's hello character is held until the round ends
expected-min: 25
turns: 35
pub: no
stop: after it. No other change.
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/host_connection_pairing.dart:60-100 · packages/connection/lib/src/host_players_broadcast.dart:30-75 · packages/connection/lib/src/host_connection.dart:20-60 and :95-110 · packages/connection/lib/src/host_server.dart:100-115 and :335-380 · packages/connection/lib/src/host_pairings.dart:28-40 and :170-180 · packages/connection/test/identity_fix_test.dart:1-60 (how a test pairs a WirePhone and starts a round) · docs/protocol.md:235
changes: roundRunning · the "one exception" sentence in protocol.md
decision (owner, Nov 23): a phone that drops and re-pairs mid-round: its hello's character "should be held until the round ends" (like set_character).
do:
1 HostSessionHost (host_connection.dart): add `bool get roundRunning;`; HostServer's adapter (host_server.dart ~line 340) returns `_server._roundRunning`.
2 host_connection_pairing.dart `_accept`: when `_host.roundRunning` and `book.known(hello.controllerId)?.character` is non-null, ask `reserveCharacter` for THAT character (the one it wore), not the hello's, and set `heldCharacter = hello.character` (when it is non-null and differs). roundEnded() then applies it with the existing `_wear`. Outside a round, or a controller with no known character: unchanged.
3 docs/protocol.md:235: delete the "The one exception ..." sentence; say a re-pairing phone's hello character is held like `set_character` until the round ends.
4 New test packages/connection/test/identity_hello_hold_test.dart: a phone wears A, a round runs, it drops and re-pairs with hello character B: it wears A and the players list shows A; after the round ends it wears B (or the nearest free). Also: outside a round the hello's character applies at once. Must fail on the old code.
allow: packages/connection/lib/src/host_connection.dart · packages/connection/lib/src/host_connection_pairing.dart · packages/connection/lib/src/host_server.dart · docs/protocol.md · packages/connection/test/identity_hello_hold_test.dart · packages/connection/test/identity_fix_test.dart · packages/connection/test/identity_host_test.dart · packages/connection/test/identity_reservation_test.dart · packages/connection/test/identity_reserve_minute_test.dart · packages/connection/test/reconnect_test.dart · packages/connection/test/player_away_test.dart
check: format analyze connection
report: docs/briefs/m16/identity1-fix/fq6-report.md
