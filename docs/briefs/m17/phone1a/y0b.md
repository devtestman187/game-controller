job: phone1a y0b — host side: ChoiceRound (send only to phones with the cap, resend, defaults, undo until the timer ends)
stop: no GameHost interface change, no old-phone code (y0c), no phone UI. Do not touch host_connection.dart or host_server.dart (y0a did).
read: docs/briefs/templates/COMMON.md · docs/briefs/m17/phone1a/contract.md (sections Wire and Host round) · packages/protocol/lib/src/choices.dart (y0a) · packages/connection/lib/src/host_server.dart:75-130,215-245 · packages/connection/lib/src/host_types.dart:100-135 · packages/connection/lib/src/away_slots.dart:30-90 · packages/connection/test/night_end_send_test.dart · packages/connection/test/wire_phone.dart · packages/connection/test/helpers.dart · packages/party_host/lib/src/host_service.dart:140-146 · owner defaults, Nov 26: undo a lock-in until the timer ends; nothing chosen at the timer end gets the default ("Save +2" for the shop, Vote abstains); a dropped player gets the same default after the grace period
changes: ChoiceRound · ChoiceOutcome · ChoiceRound.pick · ChoiceRound.close · ChoiceRound.lockedIds · Capability.choices in the host welcome list
model: sonnet
turns: 80
expected-min: 40
tests-first: exempt new class with no earlier behaviour; its new flow test is the first test
do:
1 New packages/connection/lib/src/choice_round.dart as the contract's "Host round" section says (under 380 lines; if near, put outcomes and state in `choice_round_state.dart` as a part). Export ChoiceRound and ChoiceOutcome from lib/connection.dart. Listen to `server.messages` for ChoicePickMessage and `server.changes` for reconnects; `dispose()` cancels everything.
2 host_service.dart:144: add `Capability.choices` to the capabilities list (one line, shared file with the main line: change nothing else).
3 Tests, new file connection/test/choice_round_test.dart over TestTransport with WirePhone (a capable phone `[Capability.choices]`, an old phone `[]`): sends only to the capable phone; pick then lock then unlock (undo) then close gives the last pick; nothing chosen gives defaultId, and null defaultId gives cardId null; a pick for a disabled card, an unknown card, a wrong round id or from a phone without the cap is ignored; count clamps to maxCount; a reconnect resends picked+locked with the remaining time; a player gone for `grace` (use 200 ms) gets the default with byDefault true; close is idempotent and sends ChoicesEnd once; the old phone player still gets an outcome (default) at close. Each rule fails if the code is broken.
4 Before finishing run `dart analyze` on the changed files and fix every info, warning and error on them; run `dart test packages/connection/test/choice_round_test.dart packages/connection/test/choices_gate_test.dart`.
allow: packages/connection/lib/src/choice_round.dart · packages/connection/lib/src/choice_round_state.dart · packages/connection/lib/connection.dart · packages/connection/test/choice_round_test.dart · packages/party_host/lib/src/host_service.dart
check: format analyze
report: docs/briefs/m17/phone1a/y0b-report.md
