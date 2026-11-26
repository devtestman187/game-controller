# y0a report: protocol choices messages, codec, host gate, tests

## Summary

What changed:
- `choices.dart` (new part of `messages.dart`): `ChoiceCard`, `ChoicesMessage` (`choices`), `ChoicePickMessage` (`choice_pick`), `ChoicesEndMessage` (`choices_end`), with the wire fields from contract.md (Wire). Decoding rejects an empty card id, a repeated id, 0 or more than 6 cards, and a `maxCount` outside 1..9, each as a `FormatException`.
- `Capability.choices = 'choices'`; the three wire types are registered in `MessageCodec._decoders`.
- Host side: `HostConnection` forwards a `ChoicePickMessage` only from a paired phone that lists `choices`; the two host messages (`ChoicesMessage`, `ChoicesEndMessage`) and a pick from a phone that is not paired close with protocolError. `HostServer.capabilityFor` maps both host messages to `Capability.choices`, so `sendToAll` and `send` skip a phone without it.
- Phone side (`client_messages.dart`): the three messages sit in the "Ignoring unexpected" group with a comment that B6 (y0d) routes them. No cap is added to any phone hello, and no protocolVersion change.

Tests (run in this job, seen passing):
- `protocol/test/choices_codec_test.dart`: 16 tests, all pass (7 round-trip and wire tests, 9 bad-payload tests).
- `connection/test/choices_gate_test.dart`: 8 tests, all pass (4 cases over two transports).
- `tools/mine.sh`: format ok (10 files), analyze ok on packages/protocol and packages/connection, touched tests ok (protocol 17, connection 21 in the runner's count), churn revert ok.

Values computed for the expectations:
- Round `shop`: round 2, endsInMs 5000, cards `save` (cost 2, detail), `build` (maxCount 3), `roadworks` (enabled false); defaultId `save`, currency `Bolts`, picked `build`, pickedCount 2, locked true.
- A bare card (no detail, no cost) writes no `detail` or `cost` key, and reads back `maxCount` 1 and `enabled` true.
- Card-count rule: 6 cards decode; 0 and 7 are rejected. maxCount: 9 decodes; 0 and 10 are rejected.
- Gate: a round sent with `sendToAll` reaches 1 phone (the one listing `choices`); the phone listing only `view` gets no ChoicesMessage and `send` to it returns false.
- The old phone's `InputStateMessage` (seq 1) reaches `server.messages`; its `ChoicePickMessage` does not, and the following drain (ping/pong) shows it stayed paired.

Decisions:
1. Validation is on decode only (`fromPayload` / `fromJson`). The constructors stay plain `const`, so the y0b round can build a round the phone would reject; that is for y0b to keep in range.
2. `locked` is optional on the wire and defaults to false when absent (a wrong type is still a FormatException). `byDefault` on `ChoicesEndMessage` is required, because the contract gives it no default.
3. `ChoiceCard.title` is not checked against 24 characters in the codec; the contract says the host cuts it, so y0b does that.
4. In `messages.dart` the part line sits after `character.dart`, alphabetically. The probe patch had it before `character.dart`.
5. `host_server.dart` was at 380 lines and the new arm made it 381, so I reflowed an existing two-line comment (lines 160-161) to one line, same words. Nothing else in the file changed.

## Self-check (review-rules part A)

1. Host setups: a TV host gets the cap in `capabilityFor` (`choices` test, both transports); a phone hosting "Play on this phone" uses the same `HostServer`, so the same gate applies (not run separately: same class); a joined phone that lists `choices` is sent the round and its pick reaches the host (gate test 4); a phone one build older (`view` only) is never sent it and stays paired (gate test 2); no phone hello lists `choices` in this job.
2. Kept state: none added in y0a. The new messages are stateless; the codec tests show each one round-trips with its nulls left out.
3. Combinations with the pause menu, host away, player away, "Get ready", dropped link, results, leaving: not in y0a (y0b owns the round). Covered here only as far as the gate: a pick from a phone without the cap is ignored and does not close it (gate test 3).
4. Files: all within `allow:`; see the file list below. No other file touched.
5. Stops: none. Nothing needed a file outside `allow:`.
6. Looks: no UI in y0a; not applicable.

## Questions

1. G3 says a constructor with more than 5 parameters should be a value object. `ChoicesMessage` has 9 named fields, because the contract's Wire section lists them flat and the wire is flat. I kept the flat shape; a value object for the "picked" trio (`picked`, `pickedCount`, `locked`) would change the Dart API y0b uses. Please decide whether that is acceptable.
2. Should the codec reject a title over 24 characters rather than leave it to the host? I left it to the host (decision 3).
3. Owner to confirm the assumption in contract.md (a picked but unlocked card counts at the timer end): nothing in y0a depends on it.

## Suggestions

- `ChoicesMessage` and `ChoicePickMessage` could share a `ChoicePick` value type for `(pick, count, locked)`, which would also answer question 1.

## Files changed

- packages/protocol/lib/src/choices.dart (new): `ChoiceCard`, `ChoicesMessage`, `ChoicePickMessage`, `ChoicesEndMessage`, with decode checks.
- packages/protocol/lib/src/messages.dart: `part 'choices.dart';`.
- packages/protocol/lib/src/capabilities.dart: `Capability.choices`.
- packages/protocol/lib/src/codec.dart: three decoders registered.
- packages/protocol/test/coverage_all_test.dart: one comment line for choices.dart.
- packages/protocol/test/choices_codec_test.dart (new): 16 tests.
- packages/connection/lib/src/host_connection.dart: pick gate; the two host messages in the protocolError group.
- packages/connection/lib/src/host_server.dart: `capabilityFor` maps both host messages to `choices`; comment reflowed (line count 380).
- packages/connection/lib/src/client_messages.dart: three messages in the ignoring group, with the B6 note.
- packages/connection/test/choices_gate_test.dart (new): 8 tests.

## Commit message

Add the choice-round messages and the choices capability (M17 phone1a y0a)

Adds ChoiceCard, ChoicesMessage, ChoicePickMessage and ChoicesEndMessage
(wire types choices, choice_pick, choices_end) and Capability.choices.
Decoding rejects an empty or repeated card id, a round with 0 or more
than 6 cards, and a maxCount outside 1..9.

The host sends the two host messages only to a phone that lists the
capability, and accepts a pick only from a paired phone that lists it.
A phone ignores them until y0d routes them. No phone hello lists the
capability yet, and the protocol version is unchanged.

## Status row

- phone1a y0a: done: choices protocol messages, capability, codec, host gate and tests (16 codec + 8 gate, passing). Open: the round logic (y0b), old-phone fallback (y0c), phone routing (y0d), the owner's answer to the flat-fields question.

## Delete

- none
