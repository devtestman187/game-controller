job: M16 identity1 i1c: split host_server.dart and pin the hello's character reservation with tests
pub: no
stop: after it. No behaviour change: a move of code plus characterisation tests.
tests-first: exempt (move of code; the new tests describe behaviour the old code already has). Say so in the report.
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/host_server.dart (399 lines: _reserveCharacter, _reservePlayerNumber at ~265-280) · host_connection.dart (~324, 333) · host_pairings.dart · packages/protocol/lib/src/character.dart (nearestFreeIn) · tests that could break: packages/connection/test (host server, pairing and character tests)
decisions (owner, Nov 21): "First-joined keeps a contested pick; later player gets nearest free (existing nearestFreeIn)." "A host one build older shows defaults (test it)."
do:
1 Move the character reservation (and what goes with it) from host_server.dart into a NEW file host_character_reservation.dart; host_server.dart ends at or under 370 lines.
2 NEW packages/connection/test/identity_reservation_test.dart: first-joined keeps a contested colour and accessory; a later player gets the nearest free (tie to the later slot); a seventh player still gets a character; a phone that sends none gets its number's default; a dropped player's pick is free again after the reserve minute and a returning player keeps their number's pick.
Every-look rule: no UI; say so in the self-check (item 6).
allow: packages/connection/lib/src/host_server.dart · packages/connection/lib/src/host_character_reservation.dart · packages/connection/test/identity_reservation_test.dart · docs/briefs/m16/identity1/i1c-report.md
check: format analyze connection
report: docs/briefs/m16/identity1/i1c-report.md
rules: aim 60-90 turns · no lib file you touch ends over 380 lines · write only inside allow: · sound.dart must not grow · tools/review.sh: no FAIL on your lines.
