# i1b (M16 identity1): stopped — two files the job must edit are outside `allow:`

## Summary

- Stopped before writing any code (and before writing the tests first): the job cannot pass `tools/check.sh phone`
  without editing a file it may not touch, and do item 2 cannot compile without another one.
- Blocker 1 — `controller_app/test/m14_phone_test.dart` pins both behaviours this job changes:
  - `:31-37` the nickname rules: `expect(nicknameOfText('M1a!?'), 'M1a')`. The new rule keeps `!` and `?`, so that
    line becomes `'M1a!?'` and the test fails.
  - `:73` the banner text: `expect(find.text('Blue is taken tonight, you\'re Teal'), findsOneWidget)`. The new
    wording ("Red was taken: you're Orange") makes it fail.
  - It is not in `allow:` and it runs in the `phone` suite (it is not named in the brief's "tests that could break"
    list, and `controller_app` has no `dart_test.yaml` excluding it).
- Blocker 2 — moving the nickname row out needs one line in a file outside `allow:`.
  `controller_app/lib/src/ui/settings_profile_section.dart:1` is `part of 'settings_screen.dart'`, and a part file
  cannot have imports, so a plain sibling `settings_nickname_row.dart` (what `docs/project-notes.md:51` asks for)
  is only visible inside the part if `settings_screen.dart:44-45` gains `part 'settings_nickname_row.dart';` or an
  import. `settings_screen.dart` is not in `allow:`.
- Nothing was edited and no test was run, so no half-done change is left behind. The report is the only file
  written.
- Everything else in the brief was checked against the code and is ready to run as written once the two files are
  added: sizes (`settings_profile_section.dart` 371, `connect_screen.dart` 378, `connect_panels.dart` 325,
  `phone_text.dart` 226), the taken-notice tests in allow (their `:49` / `:60` expectations only), the every-look
  helper, and the existing strings (`PhoneText.nicknameHint` `phone_text.dart:156`, `takenTonight` `:167`).

## Where the new "Change" line would go (checked, not written)

- `connect_screen.dart` is 378 lines, two under the 380 cap, so the new widget cannot live there; `ConnectionPanel`
  (`connect_panels.dart:26`) is the right home and is in allow, with its `PhoneText.change` string beside the other
  connect-screen words. The panel already imports `settings_screen.dart` (`:12`), so the Change link can push
  `SettingsScreen` without a new import.
- The row would show the saved character as the app's usual badge (`ToyBadge`, as the Settings preview draws it) and
  the colour and accessory in words beside it, so it reads the same way the TV's roster line does, with no fixed
  pixel height (it takes the look's type size).

## Questions

1. Add `controller_app/test/m14_phone_test.dart` to `allow:` so its `:31-37` nickname test can be removed (its
   rules move to the new `identity_nickname_test.dart`) and its `:73` banner text updated? Or delete the file and
   move its two kept groups (hello name, results card) — but the results-card group would then need a new home that
   is also outside `allow:` today.
2. Add `controller_app/lib/src/ui/settings_screen.dart` to `allow:` for the one `part` line (no other change), or
   name a different home for the nickname row that does not need it? `profile.dart` is the only allow-listed library
   `settings_screen.dart` already imports, and re-exporting a widget from it would be wrong.
3. "Empty gives 'Player N' as the hello name": the hello name for an empty nickname is pinned to the phone's own
   name (`Phone 1A2B`, `m14_phone_test.dart:17-29`, `profile.dart:56`), and "Player N" is the host's label
   (`connection/lib/src/game_types.dart:58`, `P2 Mia` or `P2`). Should the phone's hello name change (which breaks
   the pinned test above), or is "Player N" the TV-side label and the test item means "an empty nickname leaves the
   hello's own name, which the TV shows as Player N"?
4. The "4 px clip" was measured on screen as the settings page scrolled so that only a 4 px sliver of the `0 / 10`
   counter showed (`docs/briefs/m16/ux-review/findings/vf-tab-01.md:211,224`), not as a field that clips its own
   text. Which should the fix pin: the counter and field text inside their boxes in both looks (what the brief's
   test case says), or the counter never leaving the viewport?

## Self-check (docs/review-rules.md part A)

1. Host setups: not applicable — no code changed (the Change line planned for `connect_panels.dart` shows on every
   connect-screen state, which the brief's test would cover for all of them).
2. Kept state: not applicable, nothing kept.
3. New state against the pause menu, host away and results: not applicable, nothing added.
4. Stayed in the job's folder and inside `allow:`: only this report was written.
5. Stopped rather than overstepped: `controller_app/test/m14_phone_test.dart` (pins the old nickname rules and
   banner text) and `controller_app/lib/src/ui/settings_screen.dart` (needs the `part` line for the moved row).
6. Every look: not applicable; the plan was a plain sibling file with look-sized type and no fixed pixel height,
   tested under `toyTvProvider.overrideWithValue(true)`.

## Hand-over

Fix the brief (allow list: `m14_phone_test.dart`, `settings_screen.dart`; answer Q3 and Q4) and re-run i1b. The rest
of the brief needs no change: the punctuation set `. , ! ? ' - _`, the trim and 10 cap, the hint text
(`PhoneText.nicknameHint`), the banner wording in `PhoneText.takenTonight`, and the Change link in
`connect_panels.dart` all fit the files already allowed.

## Commit message

docs: report only, M16 identity1 i1b stopped on its allow list

The job changes two behaviours that controller_app/test/m14_phone_test.dart
pins (the nickname punctuation rule and the taken-notice wording) and moves
the nickname row out of a part file, which needs a `part` line in
settings_screen.dart. Neither file is in the brief's allow list, so the
`phone` check cannot pass. No code changed; the report names both files
and the four questions the next brief has to answer.

## Status row

i1b (nickname rules, 4 px clip, Change link, banner text): **not done, stopped** — needs
`controller_app/test/m14_phone_test.dart` and `controller_app/lib/src/ui/settings_screen.dart` added to its
`allow:`; everything else in the brief was checked and is ready.

## Delete

- none
