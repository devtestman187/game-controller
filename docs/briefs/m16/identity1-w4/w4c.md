job: M16 w4c join-screen badge draws no number and no "Player N" before pairing; phone_metrics_test group rename
pub: no
turns: 40
expected-min: 25
stop: after the unnumbered badge on the two screens and the rename. Do not change numbered badges anywhere else.
read: docs/briefs/templates/COMMON.md · packages/toy_look/lib/src/toy_badge.dart:14-96 (paintToyBadge, ToyBadge) · packages/toy_look/test/toy_badge_test.dart:50-75 · controller_app/lib/src/ui/connect_panels.dart:58-92 · controller_app/lib/src/ui/settings_profile_section.dart:224-300 · controller_app/test/phone_metrics_test.dart:21,73,123 and :298 · controller_app tests that may pin the old text: identity_phone_test.dart, waiting_card_test.dart, phone_name_display_test.dart (grep `Player [0-9]`, `'Player`) · docs/review-rules.md part A item 6
changes: _YourCharacter · _PreviewFigure
decisions (owner, Nov 23): join-screen badge: "no number and no 'Player N' label until paired". Q10: "rename phone_metrics_test's group name in the phone job".
do:
1 toy_look: `paintToyBadge(..., {character, bool numbered = true})` skips the number text when false; `ToyBadge({..., this.numbered = true})` passes it and, when false, carries no "Player N" label (Semantics label null; its owner names the character in words). Defaults keep every other caller unchanged.
2 connect_panels.dart `_YourCharacter` badge and settings_profile_section.dart `_PreviewFigure` badge: `numbered: false`. The join line already says "You: the Teal Crown".
3 New test files (fail on old code): packages/toy_look/test/toy_badge_unnumbered_test.dart (unnumbered paints no digit ink vs numbered; no "Player" semantics label) and controller_app/test/join_badge_test.dart (the join screen's badge and the Settings preview show no "Player" label and no digit; menu look and TV look per rule 6). Fix any old test that pinned the number.
4 phone_metrics_test.dart:298: the test named 'the hello lists metrics and rating, the device kind and the screen size' pins six capabilities: rename it to say so (keep the rest of the name; the group it sits in is named 'in the app' or similar: rename that too only if it is wrong).
5 Report: which old tests changed.
allow: packages/toy_look/lib/src/toy_badge.dart · packages/toy_look/test/toy_badge_unnumbered_test.dart · controller_app/lib/src/ui/connect_panels.dart · controller_app/lib/src/ui/settings_profile_section.dart · controller_app/test/join_badge_test.dart · controller_app/test/phone_metrics_test.dart · controller_app/test/identity_phone_test.dart · controller_app/test/waiting_card_test.dart · controller_app/test/phone_name_display_test.dart · docs/briefs/m16/identity1-w4/w4c-report.md
check: format analyze look phone
report: docs/briefs/m16/identity1-w4/w4c-report.md
