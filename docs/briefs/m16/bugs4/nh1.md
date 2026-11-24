job: M16 bugs4 nh1 — GameHost.showNightEnd sends the night's end to the phones that list `night`
stop: after it. No party_host screen change, no client side (job nk1), no card.
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/game_host.dart:85-123 · packages/connection/lib/src/server_game_host.dart:235-262 · packages/connection/lib/src/memory_game_host.dart:30-40,105-115 · packages/party_host/lib/src/testing/host_fakes.dart:145-160,245-260 · packages/connection/test/m14_test.dart (a showResults test over a real server) · packages/protocol/lib/src/night.dart (NightEndMessage, from job nc1)
changes: GameHost.showNightEnd (new abstract method; siblings showResults in ServerGameHost, MemoryGameHost, FakeGameHost) · MemoryGameHost.shownNightEnds (new) · FakeGameHost.shownNightEnds (new)
turns: 50
expected-min: 25
do:
1 Tests first: new packages/connection/test/night_end_send_test.dart over a real ServerGameHost with two paired phones, one listing Capability.night (and view) and one not: showNightEnd(message) reaches the first with the same awards and standings, the second gets nothing, and it is sent with no view running (after endView, as the reveal comes after the round). Run it, see it fail, then write lib.
2 game_host.dart: `void showNightEnd(NightEndMessage message);` documented: sent once when the night's awards reveal ends or is skipped, to every paired phone that lists Capability.night, whether or not a view runs. server_game_host.dart: `server.sendToAll(message)` (the server's capability gate keeps it from older phones). memory_game_host.dart and host_fakes.dart: record each call in `shownNightEnds`, as showResults does.
3 Run the new test and packages/connection/test/m14_test.dart.
allow: packages/connection/lib/src/game_host.dart · packages/connection/lib/src/server_game_host.dart · packages/connection/lib/src/memory_game_host.dart · packages/party_host/lib/src/testing/host_fakes.dart · packages/connection/test/night_end_send_test.dart · docs/briefs/m16/bugs4/nh1-report.md
check: format analyze
report: docs/briefs/m16/bugs4/nh1-report.md
