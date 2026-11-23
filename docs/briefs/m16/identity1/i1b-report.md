# i1b (M16 identity1): nickname rules, clip fix, Change link, taken wording — code done, tests blocked

## Summary

- All four items are written: the nickname rule now keeps `. , ! ? ' - _` and drops emoji and control
  characters (`profile.dart`), the nickname row moved to a new `settings_nickname_row.dart` with the count on
  its own line under the field, the Connect screen shows the saved character with a Change link to Settings
  (`connect_panels.dart`), and the taken notice says "Blue was taken: you're Teal".
- **Blocked for the checks:** the workspace does not compile. `packages/protocol/lib/src/identity.dart:15`
  (`PlayersMessage`, i1a) has no case in `packages/connection/lib/src/client_messages.dart:38` and
  `host_connection.dart:188`, so every `flutter test` of `controller_app` and `packages/party_host` fails to
  load ("The type 'Message' is not exhaustively matched"). That is i1a2's file, outside this job's `allow:`,
  and i1a2 is running in this same wave; nothing in this job touched it. No test was run, so no test result
  is claimed.
- Checks seen: `tools/check.sh format` PASS, `tools/check.sh analyze` PASS (controller_app, party_host: no
  issues). `tools/check.sh phone` and `tools/check.sh host` both ran past the 10-minute command cap and were
  stopped; a single file (`flutter test controller_app/test/identity_nickname_test.dart`) fails to load with
  the compile error above, before any test runs.
- Line counts after the change: `settings_profile_section.dart` 371 → 303, new `settings_nickname_row.dart`
  75, `connect_panels.dart` 325 → 372, `settings_screen.dart` 371 → 369, `profile.dart` 72 → 85. No touched
  lib file is over 380 lines.

## What changed, file by file

- `controller_app/lib/src/profile.dart`: `nicknameOfText` now keeps the basic punctuation; one shared
  character class `_nicknameClass` drives both the saved-name rule and the new public `nicknameCharacters`
  the field filters with, so the field and the saved name can never disagree behind the count.
- `controller_app/lib/src/ui/settings_nickname_row.dart` (new, plain sibling library as
  `docs/project-notes.md:51` asks): `SettingsNicknameRow` — the label, the field (now drawn at the look's
  body size in ink on the field's paper; the theme's body text was already that size, so only the colour changed) and one line under
  it with the hint on the left and the `0 / 10` count on the right. The count can no longer be squeezed
  beside a field that grows with the look's type.
- `controller_app/lib/src/ui/settings_profile_section.dart`: `_NicknameRow`, its state and the old
  `_nicknameCharacters` regex removed; the section now uses `const SettingsNicknameRow()`.
- `controller_app/lib/src/ui/settings_screen.dart`: one import of the new file; the three imports the moved
  row alone used (`maxNicknameLength`, `flutter/services.dart`, `../profile.dart`) removed.
- `packages/party_host/lib/src/text/phone_text.dart`: `nicknameHint` now names basic punctuation; new
  `yourCharacter(name)` ("You: the Blue Crown") and `change` ("Change") beside the other Connect-screen
  words; `takenTonight` now reads "$wanted was taken: you're $given".
- `controller_app/lib/src/ui/taken_notice.dart`: doc comment moved to the new wording.
- `controller_app/lib/src/ui/connect_panels.dart`: `_YourCharacter` added to `ConnectionPanel`, so it shows
  under every connection state: the menu badge (headroom kept for the accessory), the character in words
  from `ToyCharacter.spokenName`, and a TextButton "Change" that pushes `SettingsScreen` (key
  `changeCharacter`). No fixed pixel height: the badge is `ToyBadge.defaultDiameter` and the type is the
  look's.
- Tests: new `controller_app/test/identity_nickname_test.dart` and `identity_change_link_test.dart`; the old
  nickname rules and the old banner text updated in `m14_phone_test.dart`, and the banner text in
  `taken_notice_profile_test.dart` (two lines).
- Every-look rule: each widget test runs twice, once in the menu look and once with
  `party.toyTvProvider.overrideWithValue(true)` (the TV look), at the tablet size for the TV look. No fixed
  pixel height on any look-sized content.

## Test values I computed

- `nicknameOfText('Mia')` → `Mia`; `("Mia's team")` → `Mia's team` (10, kept whole); `('Mia, no?')` →
  `Mia, no?`; `('a-b_c!')` → `a-b_c!`.
- `('Mia🐱')` → `Mia`; `('Mia\u0007')` → `Mia`; `('Mia\tdad')` → `Miadad`; `('🐱')` → null.
- `('  Mia  ')` → `Mia`; `('Mia Maria Mia Mia')` (17) → cut at 10 = `Mia Maria ` → trimRight → `Mia Maria`;
  `('MiaMiaMia0')` (10) → kept; `('MiaMariaMia!')` (12) → `MiaMariaMi`.
- `phoneName(controllerId: 'ab12cd34')` → `'Phone ' + 'AB12'` = `Phone AB12` (first four uppercased).
- Settings: the blank profile's count is `0 / 10`; after typing `Mia! Mia M` (10 characters) it is `10 / 10`.
- Connect screen with `profileCharacter` `{"c":4,"a":"crown"}`: colour slot 4 = Teal, crown → `Crown`, so
  `You: the Teal Crown`. With no saved profile: slot 1 = Blue, ears → `Ears`, so `You: the Blue Ears`.
- `PhoneText.takenTonight('Red', 'Orange')` → `Red was taken: you're Orange`.

## Decisions

1. An empty nickname still leaves the hello's own name ("Phone 1A2B", M14 N13, pinned in
   `m14_phone_test.dart:17-29`); "Player N" is the TV's label for a player whose hello carried no nickname
   (`GamePlayer.label`, `connection/lib/src/game_types.dart:58`), and the brief forbids a host change. The new
   test pins the phone's side only. Question 1 asks for confirmation.
2. The "4 px clip" is fixed as the brief's test words it: the field draws at the look's type size with its
   text inside its box, and the count has a line of its own under the field, so no look can squeeze it. The
   measured finding (`ux-review/findings/vf-tab-01.md:211,224`) was the page's viewport cutting the bottom of
   the card, which no widget can un-clip from inside; putting the count on the hint's line also takes it off
   the card's very bottom edge.
3. `takenTonight` keeps its name (the brief names the function) although "tonight" left the sentence.
4. The Change link lives in `ConnectionPanel` rather than `connect_screen.dart`, which was two lines under the
   cap; the panel is in every Connect-screen state and already imports `SettingsScreen`.
5. `SettingsNicknameRow` is a plain library, so `settings_screen.dart` gained one import line and lost the
   three that only the moved row used.

## Self-check (docs/review-rules.md part A)

1. Host setups: the Change line shows on every Connect-screen state because it sits in `ConnectionPanel`
   under the status child; the test covers the idle state (`identity_change_link_test.dart`, both looks).
   None of the Connect-screen states draws the taken-colour line; its setups are a joined phone and a
   peer one build older.
2. Kept state: nothing new is kept; the row reads the saved profile it always kept (the saved-character case
   in `identity_change_link_test.dart`, the saved nickname path in `identity_nickname_test.dart`).
3. New state against the pause menu, host away, results, leaving: none added — the row is plain profile
   display and the count is local field state. Not applicable.
4. Stayed in the job's folder and inside `allow:`: every changed file is in the list; nothing else touched.
5. Stopped rather than overstepped: `packages/connection/lib/src/client_messages.dart` and
   `host_connection.dart` need a `PlayersMessage` case (i1a2's file) before any test of either package can
   compile; not touched.
6. Every look: `identity_nickname_test.dart` and `identity_change_link_test.dart` each run the menu look and
   the TV look; the field and the count take the look's type, the badge its default diameter — no fixed
   pixel height (all values are `ToySizes`, `look.type` or `ToyBadge.defaultDiameter`).

## Hand-over

Re-run `tools/check.sh phone host` once i1a2's `PlayersMessage` cases are in the tree: the two new test files
are written to fail on the code before this job (no `changeCharacter` key, `M1a!?` → `M1a`, the old banner
sentence, the count beside the field, the theme's title size on the field) and to pass after it.

## Questions

1. Empty nickname: keep the phone's own name in the hello (M14 N13, pinned) rather than sending a blank name
   so the TV says "P2" only? A blank name would also empty the host's log lines (`host_connection.dart:97`).
2. `controller_app/lib/src/providers/profile.dart:57-59` still names the old sentence ("Blue is taken
   tonight, you're Teal") in a doc comment; it is outside `allow:` and was left alone.

## Commit message

```
Phone identity: new nickname rules, a count that fits, a Change link

The nickname keeps basic punctuation and drops emoji and control
characters, in one shared character class the field and the saved name
both use. The nickname row moves out of the settings' part file with its
hint and 0 / 10 count on a line under the field, and the field draws at
the look's own type size, so neither is clipped. The Connect screen names
the saved character with a Change link that opens Settings, and the taken
notice now reads "Blue was taken: you're Teal".
```

## Status row

i1b (nickname rules, count clip, Change link, taken wording): code and tests **written, unverified** — checks
blocked because `packages/connection` does not compile against protocol's new `PlayersMessage` (i1a2's file,
same wave); format and analyze pass.

## Delete

- none
