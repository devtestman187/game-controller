# Wave 1 review (i1b): nickname rules, count, Change link, taken wording

## Summary

- Verdict: **needs Claude** — two of the job's numbered items need an owner answer before the wave closes.
- must 0 · should 3 · could 5.
- A blank nickname still sends the phone's own name ("Phone AB12"), not the brief's and the owner's "Player N"
  (finding 1).
- The count moved from the field's end to a line under the field, one line lower on the screen
  `vf-tab-01.md:224` measured, and the not-clipped test scrolls past it, so the brief's 4 px clip is untouched
  (finding 2).
- The field's new ink style (the night-time white-on-paper fix) has no test; both looks run at midday
  (finding 3).
- I ran `flutter test` on `identity_nickname_test`, `identity_change_link_test`, `m14_phone_test`,
  `taken_notice_profile_test`, `settings_test` and `connect_screen_test`: 10 + 35 tests, all pass; the runner's
  own log confirms both new files fail on the old code.

## Findings

- **should** controller_app/test/identity_nickname_test.dart:34 the brief's item 1 and the owner decision
  (i1b.md:5,7) say an empty nickname shows "Player N", but this test pins the opposite ("Phone AB12",
  profile.dart:57) and no test covers the brief's case → get the owner's answer on which name a blank nickname
  sends, then test that name.
- **should** controller_app/test/identity_nickname_test.dart:68 the count moved from the field's end
  (ux-review/mockups/proposal-04-night.png, "3 / 10") to the hint's line under it, i.e. lower on the opening
  Settings screen than the 4 px sliver at vf-tab-01.md:224, and the test scrolls the field into view before
  measuring, so the clip is neither fixed nor caught → confirm the viewport cut is out of scope, or measure the
  unscrolled screen at the finding's size.
- **should** controller_app/lib/src/ui/settings_nickname_row.dart:51 the ink style is the only fix for the
  theme's onBackground field text (toy_theme.dart:187) and nothing tests it: identity_nickname_test.dart:81
  checks only fontSize, and pumpApp's clock is midday (pump_app.dart:130) → add a night-clock case asserting the
  field's style colour is the look's ink, and list the fix as a decision.
- **could** docs/briefs/m16/identity1/i1b-report.md:30 says the field was at "the M3 title size"; the theme gives
  bodyLarge the look's body (toy_theme.dart:198), so the drawn size did not change, only the colour did →
  correct the line.
- **could** controller_app/lib/src/ui/connect_panels.dart:82 the badge is numbered with the colour slot, so a
  teal phone draws "4" and announces "Player 4" (toy_badge.dart:89) though it is not player 4 (the settings
  preview does the same, settings_profile_section.dart:246,253) → give the badge the player number the join will
  get, or drop the number and its label before a join.
- **could** controller_app/test/identity_nickname_test.dart:78 `find.text` matches the field's EditableText,
  whose rect is inside the TextField by construction, so the "typed text inside the field" check cannot fail for
  a clipped field → check the painted text's height or the decoration instead.
- **could** controller_app/lib/src/providers/profile.dart:57 still quotes the old sentence, as do
  packages/toy_look/lib/src/toy_character.dart:90 and docs/design/party-night.md:203, all outside this job's
  allow → one docs pass updates the three quotes to "was taken: you're".
- **could** docs/briefs/m16/identity1/i1b-report.md:85 the A1 answer covers the Connect screen's states but never
  names the TV/PC host, the phone host, "Show on this device", a joined phone or an older peer → add the one line
  that none of those screens draws these words.

## Decisions to confirm

- The blank nickname: the phone's own name (Decision 1) against the owner's "Player N"; wave 2's Player N test
  depends on which one is right, and the new test currently pins the phone's name.
- The 4 px clip: whether the Settings viewport cut is out of scope (Decision 2), and whether the count should
  stay on the hint's line rather than at the field's end as frame 4 draws it.
- The field's ink style: an extra fix not asked for by the brief, correct against toy_theme.dart:187, but
  untested and not listed as a decision.
- The join line's badge number (colour slot) and the invented wording "You: the Blue Crown" / "Change":
  proposal-04 is the Settings phone frame and proposal-05 the TV lobby, so neither shows a phone join-screen line
  to copy.

## Could not check

- `docs/briefs/m16/identity1/run-findings.md` does not exist, so there were no runner entries to consult.
- The full combined check and `tools/review.sh` notes: not rerun; only the six phone test files above were run.
- A device, or the TV look at a real phone size: the TV-look tests pump at 1180x820 (a tablet).
- The brief names wave 1 "(i1b)", so i1a, i1a2 and i1c were not reviewed here.

## Commit message

Review of wave 1 (i1b): identity code sound, two items need an answer

Findings only, no code changed. A blank nickname still sends the phone's
own name rather than the owner's "Player N"; the count moved below the
field, so the Settings viewport clip vf-tab-01.md measured is unchanged;
and the field's new ink style has no night test. Five lesser points: a
false "M3 title size" claim in the report, a badge numbered by colour
slot, one assertion that cannot fail, three stale quotes of the old
banner wording, and an A1 line that names no host setup.

## Status row

i1b (nickname rules, count clip, Change link, taken wording): committed, and its tests pass on the merged tree
(45 read here); open: the owner's blank-nickname "Player N" answer, the Settings viewport clip, a night-palette
test for the field's ink, and three stale quotes of the old banner wording.

## Delete

- none
