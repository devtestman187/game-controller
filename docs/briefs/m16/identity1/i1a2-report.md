# i1a2 report: the identity messages in the codec and the switches

job: M16 identity1 i1a2 · gate: none named, stop after the job (`stop: after it`) · status: done

`tests-first: exempt` as the brief says: this job finishes a compile break i1a left (two new sealed
`Message` subclasses with no case anywhere), so nothing compiled or decoded before it. The new test
pins the codec registration i1a had to leave out (i1a report, question 1), and it fails on i1a's code:
`codec.decode` returned `null` for both types, so every round-trip test saw `null` instead of a
message.

## Files changed

- `packages/protocol/lib/src/codec.dart` — `_decoders` gains
  `PlayersMessage.wireType: PlayersMessage.fromPayload,` and
  `SetCharacterMessage.wireType: SetCharacterMessage.fromPayload,` after `PlayerBackMessage`, the
  order of the other entries (answers i1a's question 1).
- `packages/connection/lib/src/client_messages.dart` — `onData`: `PlayersMessage` (TV → phone) gets
  its own case that only says i1e will remember who wears what (a phone without it draws the
  number's default, as with a host one build older); `SetCharacterMessage` (phone → TV) joins the
  "Ignoring unexpected ... from the TV" case. 231 lines.
- `packages/connection/lib/src/host_connection.dart` — `_handle`: `SetCharacterMessage` (phone → TV)
  gets its own case that only says i1d will give the asked-for character (the hello's character
  stands until then); `PlayersMessage` (TV → phone) joins the "Unexpected" `protocolError` close.
  369 lines, under the 380 limit.
- `packages/protocol/test/identity_codec_test.dart` — NEW, four tests, below.

No behaviour: both messages decode now and are deliberately inert, as the plan says until wave 2.

## Where else a switch sees a Message

`grep -rn "switch ("` over `packages/*/lib`, `controller_app/lib` and `tv_test_app/lib` finds three
other places; none needs a case:

- `packages/connection/lib/src/client_messages.dart` `_onControlMessage` and `_onViewEvent` end in
  `default:`, and the messages they dispatch on cannot reach them from the outer switch.
- `packages/connection/lib/src/host_server.dart:228` `capabilityFor` has `_ => null`. Note for i1d:
  `PlayersMessage` is a host → controller message, so it should get `Capability.identity` there when
  i1d starts sending it; i1a2 leaves it, as the brief gives no behaviour yet and the file is outside
  `allow:`.

No app switches on a `Message`. `dart analyze` over the two packages reports no
`non_exhaustive_switch_statement` (PASS below).

## Computed test values

Fixtures follow `identity_wire_test.dart`:

- `blueEars` = `PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears)` → id `blue.ears`
  (slot 1 is the palette's first word, "blue").
- `tealCrown` = `PlayerCharacter(colourSlot: 4, accessory: PlayerAccessory.crown)` → id
  `teal.crown` (slot 4 is the fourth word, "teal").
- `PlayersMessage` rows: `(id: 'c1', number: 1, name: 'Ada', character: blue.ears)`,
  `(id: 'c2', number: 2, name: '', character: teal.crown)`; wire `pl` has 2 rows, row 1
  `{"id":"c1","n":1,"name":"Ada","character":{"c":1,"a":"ears"}}` and row 2
  `{"id":"c2","n":2,"name":"","character":{"c":4,"a":"crown"}}` (row 1's character from the codec's
  own `toJson`, not a test literal).
- `set_character` payload is the bare `{"c":4,"a":"crown"}`, so the frame is
  `{"v":<protocolVersion>,"t":"set_character","c":4,"a":"crown"}`.
- A `players` frame with only `v` and `t` decodes to `players` = `[]` (missing `pl`).
- The unknown-type frame uses `t = "identity_of_a_newer_build"` with `v = protocolVersion`; decode is
  `null`.
- Suites: `protocol` 140 tests (136 before + 4 new), `connection` 316 tests, both PASS.

## Self-check (R part A)

1. **Every host setup**: no behaviour, so no host setup applies; the codec accepts both messages
   whatever the peer, which is what a TV, a PC host, a phone on either mode and a peer one build
   older need. Shown by `identity_codec_test.dart` (round-trips decouple from any transport).
2. **Kept state**: none added. `PlayersMessage` keeps nothing on the phone and `SetCharacterMessage`
   keeps nothing on the host; both cases are empty apart from their comment.
3. **With pause menu, host away, player away, "Get ready", a dropped link, the results, leaving**:
   unchanged, because both cases do nothing. `PlayersMessage` from a phone still closes its
   connection as a protocol error (`Unexpected players`); `SetCharacterMessage` from the TV is still
   logged and ignored. Shown by `connection` suite (316 tests, PASS).
4. **Stay in the folder and inside `allow:`**: four files, all listed in `allow:`.
5. **Stop rather than overstep**: `host_server.dart`'s `capabilityFor` will need `Capability.identity`
   for `players` in i1d; it is outside `allow:` and has a wildcard, so nothing is broken now.
6. **Every look**: no UI and no widget in this job, so no menu-look or TV-look case and no
   look-sized box.

## Questions

1. The two inert cases use `break;` with a comment and no state change. If wave 2 slips, a reviewer
   may prefer them folded into the "Ignoring"/"Unexpected" cases instead; I followed the brief's
   "its own case" wording.
2. For i1d: should `PlayersMessage` also go through `HostServer.capabilityFor` (returning
   `Capability.identity`), so a host never sends it to a phone that didn't list the capability, as
   PRD v2 P2 asks?

## Suggestions (not acted on)

- `identity_codec_test.dart`'s fixture constants (`blueEars`, `tealCrown`) are copied from
  `identity_wire_test.dart` because `package:test` files don't share code without a helper library;
  a small `test/fixtures.dart` would remove the copy if more identity tests arrive.

## Checks

```
PASS  format      (5s)
PASS  analyze     (6s)
PASS  protocol    (140 tests, 5s)
PASS  connection  (316 tests, 16s)
All checks passed (32s).
```

## Commit message

Register the identity messages in the codec and the message switches

The new PlayersMessage and SetCharacterMessage now decode (i1a left the two
`_decoders` lines out), so the sealed Message switches had to name them:
the phone ignores `players` for now and ignores `set_character` as
unexpected, the host ignores `set_character` for now and closes on
`players`. Neither message changes behaviour; i1d and i1e fill the cases
in. A new identity_codec_test round-trips both messages and still ignores
an unknown type.

## Status row

i1a2 done: `players` and `set_character` decode and every Message switch covers them, inert until
wave 2; open: i1d gives `SetCharacterMessage` real handling and adds `Capability.identity` to
`HostServer.capabilityFor` for `players`, i1e handles `PlayersMessage` on the phone.

## Delete

- none
