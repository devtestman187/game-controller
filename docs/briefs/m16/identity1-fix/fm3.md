job: M16 identity1-fix fm3: pin a crown pixel mask in the phone arena identity test
expected-min: 25
turns: 50
tests-first: exempt test-only job: it strengthens an existing test
pub: no
stop: after it. No other change.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/identity1/MILESTONE-VERDICTS.md (fm3) · packages/test_game/test/arena_phone_identity_test.dart:1-165 · packages/test_game/test/arena_identity_test.dart:1-60 and 225-275 (the crown mask: drawnRadius, marbleCentre, mask, share, referenceBytes, argb) · packages/test_game/test/arena_character_test.dart:50-95 (mask, share, argb, referenceBytes definitions)
changes: arena_phone_identity_test
decisions (review of identity1, Nov 23): arena_phone_identity_test.dart:118-127 compares two whole renders (`isNot(equals(variant))`); it must pin the crown by a pixel mask the way arena_identity_test.dart:241-260 does.
do:
1 In arena_phone_identity_test.dart replace the whole-render comparison in the test "the chosen accessory is drawn, not the number default" by: render with characters {'a': chosen} and take the mask of the ink-coloured pixels in the band above the marble's body (as arena_identity_test.dart:235-250); compare with a reference render of a crown marble drawn the same way (the share is above 0.95) and with player 1's default ears (share below 0.5). The phone's marble is at x 0.4, y 0.6 of `screen` (arena() in this file): compute marbleCentre and the drawn radius the way arena_identity_test.dart:47-51 does. Copy small helpers into this file (mask, share, argb) or import the ones the test folder already shares; do not edit other test files. Both looks (menu and TV) as before.
2 The new assertion must be able to fail: it fails if the accessory is swapped for the default ears (say in the report how you know: e.g. drew with {} instead of chosen and saw the share drop).
Every-look rule: menu and TV, both looks, in this one test.
allow: packages/test_game/test/arena_phone_identity_test.dart
check: format analyze arena
report: docs/briefs/m16/identity1-fix/fm3-report.md
