# M16 identity1 i1a report: stable ID, spoken name, identity wire fields

## Summary

- Tests first: two NEW files (`packages/protocol/test/identity_wire_test.dart`, 12 tests;
  `packages/toy_look/test/toy_character_name_test.dart`, 3 tests) written before the code.
- `PlayerCharacter.id` / `PlayerCharacter.fromId` (protocol): one stable ID per character,
  `<colour>.<accessory>`, colour from the palette's own names in lower case, Blue first
  (`colourIds`): `blue.ears` … `yellow.crown`, 36 in all, unique and round-tripping.
- `ToyCharacter.spokenName` and `ToyAccessory.spokenNoun` (toy_look): "the Blue Bow" for all 36.
- NEW `packages/protocol/lib/src/identity.dart` (a `part` of `messages.dart`):
  `Capability.identity`, `PlayersMessage` (`players`, host → controller),
  `SetCharacterMessage` (`set_character`, controller → host), `PlayerRow` (the row record), and
  the decoders; `FrameMessage` gained `characters` (`chars`, player ID → `{c, a}`, left out when
  empty, absent decodes to empty).
- `messages.dart` stayed at 368 lines: the `playerColors`/`playerColor` block moved, unchanged, to
  `character.dart` (100 → 144 lines) to make room for the new `part` line.
- `docs/protocol.md`: capability table, connection flow, hello `character` note, NEW §8d
  ("Player characters"), the frame row's `chars`, direction table.
- Tests seen: `tools/check.sh format analyze protocol look` → PASS (protocol 136 tests, look 140
  tests; my new files are 12 and 3 of those).
- Not registered in `MessageCodec._decoders`: `codec.dart` is outside `allow:` (question 1).

## Decisions

- The ID's colour half is the palette's name in lower case (owner decision Nov 21), so player 1 is
  `blue.ears`, not the brief's illustrative `red.bow`; `PlayerCharacter.colourIds` holds them and
  the toy_look test cross-checks that the ID and the spoken name use one word per colour.
- A `players` row's `id` is the host's **player** ID (the key of a frame's `pl`/`acks`), never the
  character ID; the character travels as `{c, a}`. §8d says so, and the test uses `c1`/`c2`.
- The list key is `pl`, like the frame's roster, because it is the same "players of this game" list;
  the message type is `players`.
- A row is a record typedef (`PlayerRow`) rather than a class, copying `FrameMessage.roster`'s
  record style; `number` maps to wire `n`. Rows from a newer host with extra fields decode fine.
- Missing `pl` decodes as no players and a missing `name` as `""`; a row with no `character` is a
  format error, because a host that sends a row always knows the character it gave.
- `set_character`'s payload is the bare `{c, a}` object (the hello's `character` shape). The shared
  reader takes an error prefix, so a hello still reports `character.c` and `set_character` reports
  `c`, while `chars` reports `chars.<id>.c`.
- `chars` rides a frame only to a viewer that listed `identity` and is left out when empty, so an
  older phone sees no new field and a newer phone reads an older frame as "no characters".
- Moved, not edited: the player colours now live in `character.dart` (they are the character
  colours); `protocol.dart` still exports them and every import is unchanged.

## Computed test values

- 36 IDs, e.g. `blue.ears` (slot 1 + ears), `purple.bow` (slot 3 + bow), `yellow.crown`; the set
  is 36 long, and each `fromId(id)` equals the character it came from.
- Rejected IDs: `red.bow`, `blue.scarf`, `blue`, `blue.ears.`, `Blue.Ears`, `.ears`, `""`.
- Spoken names: 36 distinct, e.g. `the Blue Ears`, `the Orange Bow` (slot 2 + bow),
  `the Purple Bow` (slot 3 + bow), `the Teal Crown` (slot 4 + crown).
- Player 7's ID is player 1's (`blue.ears`); player 9's spoken name is player 3's
  (`the Purple Bow`), so neither names a player.
- `players` payload: `{"pl":[{"id":"c1","n":1,"name":"Mia","character":{"c":1,"a":"ears"}},
  {"id":"c2","n":4,"name":"","character":{"c":4,"a":"crown"}}]}` and an empty `pl` decodes as
  no players.
- `set_character` payload: `{"c":4,"a":"crown"}`; `c` 0 or 7 and an unknown `a` are refused.
- `FrameMessage` with no characters encodes without `chars`; a frame decoded without it has an
  empty map; `chars` with `c: 0` is refused.

## Self-check (docs/review-rules.md part A)

1. **Every host setup** (TV, PC, "Play on this phone", "Show on this device", joined phone, older
   peer): no host or phone behaviour changed, so every setup encodes as before; when no character
   is known the frame is byte-for-byte the old one — `identity_wire_test` "a frame leaves chars out
   when there is none, and reads an older frame as none", "a peer one build older ignores an
   unknown message and an unknown field".
2. **Kept state**: none added; `chars` is per frame and absent means empty, `players` holds no
   state (the host re-sends it) — the same two tests; nothing happens when nothing is going on.
3. **With pause menu, host away, player away, "Get ready", a dropped link, results, leaving**: no
   change. `chars` rides each frame as `pl` does, including the `n: -1` Get ready frame, no frame
   goes out during a hold or a wait, and a re-paired phone gets `players` again (docs §8d) —
   `identity_wire_test` "a frame's chars field carries every player's character and round-trips".
4. **Job folder and `allow:`**: only the 9 allowed files plus this report changed. The brief's
   check names `toy_look`, which `tools/check.sh` does not know; the toy_look suite is `look`, and
   I ran `format analyze protocol look`.
5. **Stop rather than overstep**: `packages/protocol/lib/src/codec.dart` is outside `allow:`, so
   `MessageCodec` still returns null for `players` and `set_character`; named in question 1 rather
   than edited.
6. **Every look**: no UI and no widget in this job, so there is no menu-look or TV-look case and
   no look-sized box.

## Questions

1. **Codec registration is unowned.** `codec.dart` (`_decoders`) is in no job's `allow:` (i1a,
   i1d, i1e), but without two lines there —
   `PlayersMessage.wireType: PlayersMessage.fromPayload,` and
   `SetCharacterMessage.wireType: SetCharacterMessage.fromPayload,` — the codec returns null for
   both messages and i1d/i1e cannot receive them. Should i1a's `allow:` gain `codec.dart`?
2. The brief's `check:` names `toy_look`; `tools/check.sh` knows the suite as `look`. Confirm the
   runner passes `look` (I ran both `protocol` and `look`).
3. Two copies of the palette words now exist: `PlayerCharacter.colourIds` (lower case) and
   `ToyCharacter.colourNames`. The toy_look test fails if they drift; is one source wanted?
4. Confirm for i1d/i1e: message name `players` with key `pl`, and a `PlayerRow` record with fields
   `id, number, name, character`.

## Suggestions (not acted on)

- Build `ToyCharacter.colourNames` from `PlayerCharacter.colourIds` (capitalising the first
  letter) so the words live in one place.
- A `PlayerRow`/`PlayersMessage` accessor for "the row of player N" would save i1e a loop, if the
  briefs want one.

## Hand-over

- i1d: `PlayersMessage(players: [ … ])`, `FrameMessage(..., characters: {'<playerId>': PlayerCharacter})`;
  gate both on `Capability.identity`.
- i1e: `Capability.identity` in the hello, `SetCharacterMessage(character: …)`,
  `PlayerCharacter.fromId(savedId)` for a stored choice, `ToyCharacter.spokenName` for a lobby
  list word.
- Still to do: the codec's two `_decoders` lines (question 1).

## Commit message

protocol: character IDs, spoken names and the identity wire fields

Add PlayerCharacter.id/fromId, one stable ID per character (blue.ears),
and ToyCharacter.spokenName ("the Blue Bow") for all 36.
Add the identity capability, the players and set_character messages, and a
frame's chars field, all additive and capability-gated; absent fields decode
to empty and an older peer ignores them.
Move the player colours into character.dart so messages.dart stays under its
size limit.
Document all of it in docs/protocol.md (new §8d).

## Status row

| identity1 i1a | done: stable character ID (blue.ears) and spoken name (the Blue Bow) for all 36, `identity` capability with `players`, `set_character` and frame `chars`, docs/protocol.md §8d; tests 12 + 3, protocol 136 / look 140 green | open: codec `_decoders` registration (codec.dart outside this job's allow), then host/phone wiring in i1d/i1e |

## Delete

- none
