job: M16 w4g test hardening: host_chip_test, identity_host_test, a palette-order cross-check
pub: no
turns: 35
expected-min: 25
tests-first: exempt test-only changes; each changed test must fail when the thing it pins is broken (say how you checked in the report)
stop: after the three test changes. No lib code.
read: docs/briefs/templates/COMMON.md · controller_app/test/host_chip_test.dart:55-95 · packages/connection/test/identity_host_test.dart:140-190 · packages/protocol/lib/src/character.dart:25-50 (colourIds) · packages/toy_look/lib/src/toy_character.dart:80-100 (colourNames) · packages/toy_look/test/toy_character_name_test.dart:1-30
changes: viewOnly
decisions (REVIEW.md group G, could): the chip test pins the profile, not the host's answer; the `viewOnly` phone does list identity; the two palette word lists have no cross-check.
do:
1 host_chip_test.dart:74: change the saved profile after pairing (to another character) so the chip assertion passes only when the chip shows the host's answer.
2 identity_host_test.dart:158: the `viewOnly` phone is a real ClientConnection that lists identity; rename it or use a WirePhone hello without the capability so it really hears no `players`; keep the assertion meaning.
3 New packages/toy_look/test/palette_order_test.dart: `PlayerCharacter.colourIds[i]` equals the lowercase `ToyCharacter.colourNames[i]` for every slot.
4 Report: how each changed test was shown to fail on a broken value.
allow: controller_app/test/host_chip_test.dart · packages/connection/test/identity_host_test.dart · packages/toy_look/test/palette_order_test.dart · docs/briefs/m16/identity1-w4/w4g-report.md
check: format analyze phone connection look
report: docs/briefs/m16/identity1-w4/w4g-report.md
