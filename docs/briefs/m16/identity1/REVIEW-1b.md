# REVIEW-1b: i1a2 (c179a93c) and i1b (05c5d72b), driver review Nov 22

Against i1a2.md, i1b.md, docs/review-rules.md (A1-6). Read the full diffs and the new tests.

Counts: Real 0 · Trivial 0 · Minor 5 (all in docs/code-health.md, "M16 identity1 wave 1b leftovers") · Questions for wave 2 folded into Minor 3-4.

## i1a2
- codec.dart:38-39 both messages registered, as the other messages. OK.
- client_messages.dart:59-62, 69: PlayersMessage own inert case (comment i1e), SetCharacterMessage in "Ignoring unexpected ... from the TV". Matches brief item 2. OK.
- host_connection.dart:207-210, 225: SetCharacterMessage own inert case (i1d), PlayersMessage in the protocolError case. Matches item 3. OK.
- packages/protocol/test/identity_codec_test.dart: round trip of both, a players frame with no list, unknown type ignored. Matches item 4. Brief item 5 (grep for other switches): none found by the worker; analyze showed no non_exhaustive_switch_statement. OK.
- Minor: no test of the two inert cases (code-health).

## i1b
- profile.dart: one `_nicknameClass` shared by the field's allow-list and the cut; `. , ! ? ' - _` kept, emoji and control characters dropped, trimmed, 10 cap. Matches the owner decision. Tests pin each rule. OK.
- settings_nickname_row.dart (new, 75 lines): counter and hint get their own line, text styled in the look's ink and body size; 4 px clip fix tested by rect checks (typed text inside field, counter below field and not a sliver). OK.
- connect_panels.dart `_YourCharacter`: badge in a box sized from `ToyBadge.defaultDiameter` plus `toyAccessoryHeadroom` (a constant badge, not a look-sized widget, so rule A6's fixed-height ban does not apply); text is Flexible, so it wraps. Change link opens Settings (tested). OK.
- Every-look rule (A6): identity_nickname_test and identity_change_link_test each run the menu look and the TV look via `toyTvProvider.overrideWithValue(true)`. Met; the TV runs use a tablet screen (Minor 1). The helper `all_looks.dart` is not used, the tests pump the app directly; acceptable, the app screens are not host screens.
- phone_text.dart: taken notice wording "Red was taken: you're Orange", test updated. OK. Name left as `takenTonight` (Minor 2).
- Empty nickname shows "Player N" (owner decision): not tested in i1b; belongs to the host/phone display in wave 2 (Minor 3).
- Size: connect_panels.dart 372 lines, under 380 (Minor 5).
- No Real findings: no fix job needed before wave 2.
