job: M16 identity1 i1a: stable ID, spoken name, and the additive wire fields for player identity (protocol + toy_look)
pub: no
stop: after it. No host or phone behaviour change, no painter change.
read: docs/briefs/templates/COMMON.md · packages/protocol/lib/src/character.dart · messages.dart (380 lines: adding the one `part` line means moving a line out) · capabilities.dart · view.dart (FrameMessage, roster `pl`) · packages/toy_look/lib/src/toy_character.dart · docs/protocol.md (character, capabilities, frame sections) · tests that could break: packages/protocol/test, packages/toy_look/test
decisions (owner, Nov 21): "Stable ID is a name-based string like red.bow (not slot numbers); spoken name the {Colour} {Accessory} for all 36." "Host sends each player's character to every phone via an additive, capability-gated protocol field; older peer still works." The palette's own colour names are used (ToyCharacter.colourNames, Blue first), so the ID is e.g. blue.ears; say so under Decisions.
do:
1 Tests first, NEW packages/protocol/test/identity_wire_test.dart and packages/toy_look/test/toy_character_name_test.dart: all 36 IDs unique and round-trip (id to PlayerCharacter and back); spoken name "the Blue Bow" style for all 36; the nickname is in neither; the new messages round-trip; an older peer ignores unknown fields and messages.
2 PlayerCharacter.id / PlayerCharacter.fromId in protocol; ToyCharacter.spokenName in toy_look (accessory nouns Ears, Antenna, Bow, Cap, Tuft, Crown).
3 New protocol file identity.dart (a `part` of messages.dart): Capability.identity; host to phone message `players` (list of {id: player ID, n: number, name, character {c, a}}); phone to host message `set_character` ({c, a}); frame field `chars`: player ID to {c, a}, left out when empty. Absent fields decode to empty.
4 docs/protocol.md: document all of it, the capability gating and the older-peer rule, in this job.
Every-look rule: no UI here; say so in the self-check (item 6).
allow: packages/protocol/lib/src/character.dart · packages/protocol/lib/src/identity.dart · packages/protocol/lib/src/messages.dart · packages/protocol/lib/src/capabilities.dart · packages/protocol/lib/src/view.dart · packages/protocol/test/identity_wire_test.dart · packages/toy_look/lib/src/toy_character.dart · packages/toy_look/test/toy_character_name_test.dart · docs/protocol.md · docs/briefs/m16/identity1/i1a-report.md
check: format analyze protocol toy_look
report: docs/briefs/m16/identity1/i1a-report.md
rules: aim 80-120 turns · no lib file you touch ends over 380 lines · tests first in NEW test files · sound.dart must not grow · tools/review.sh: no FAIL on your lines.
