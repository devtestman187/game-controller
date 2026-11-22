job: M16 identity1 i1d: host side: gate a character change to lobby/between rounds, broadcast players to phones, fill frame chars
pub: no
stop: after it. Needs i1a (wire) and i1c (reservation file) committed. No phone UI, no painters.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/identity1/i1a-report.md · i1c-report.md · packages/protocol/lib/src/identity.dart · packages/connection/lib/src/host_connection.dart · host_server.dart · host_character_reservation.dart · server_game_host.dart (395 lines: move code to a NEW file) · host_types.dart · docs/protocol.md (identity section) · tests that could break: packages/connection/test, party_host tests using host_fakes
decisions (owner, Nov 21): "Changes allowed in lobby and between rounds, take effect next round, never mid-round." "First-joined keeps a contested pick; later player gets nearest free." "Host sends each player's character to every phone via an additive, capability-gated field; older peer still works."
do:
1 Tests first, NEW packages/connection/test/identity_host_test.dart: set_character in the lobby applies and the answer (player message) carries the possibly nearest-free character; mid-round it is held and applied when the round ends (a running game's players never change); a change onto a taken pick gets nearest free; the `players` message goes only to phones listing Capability.identity, to all of them, on join, leave and change; frames carry `chars` only for identity phones; a phone without the capability receives today's messages unchanged.
2 Implement in a NEW file host_players_broadcast.dart with small hooks in host_connection.dart and host_server.dart; move code out of server_game_host.dart so it ends at or under 380.
3 Adjust the identity section of docs/protocol.md where the behaviour needs more words.
Every-look rule: no UI; say so in the self-check (item 6).
allow: packages/connection/lib/src/host_connection.dart · packages/connection/lib/src/host_server.dart · packages/connection/lib/src/host_players_broadcast.dart · packages/connection/lib/src/server_game_host.dart · packages/connection/lib/src/server_game_frames.dart · packages/connection/lib/src/host_types.dart · packages/connection/test/identity_host_test.dart · docs/protocol.md · docs/briefs/m16/identity1/i1d-report.md
check: format analyze connection host
report: docs/briefs/m16/identity1/i1d-report.md
rules: aim 90-120 turns, never over 120 (stop and report what is left rather than rush) · no lib file you touch ends over 380 lines · tests first in NEW test files · sound.dart must not grow · tools/review.sh: no FAIL on your lines.
