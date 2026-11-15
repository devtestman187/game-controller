# Review: b017-stick-text (B-017 floating-sticks text)

## Summary

Verdict: **small fixes**. Counts: 0 must, 1 should, 2 could.

The fix is sound: the old colour really was `listTileTheme: textColor: onBackground` (`packages/toy_look/lib/src/toy_theme.dart:41`,
white at night, `toy_colors.dart:76`) on cream paper `#FFF6E3` (`:50`, `:77`), and the dialog is the only tile in the phone
app not under a `ToyCard` (`toy_card.dart:184` puts tiles back to ink), so wrapping its content is the one change the app
needs and the report's "Settings had it" is true.
Most important: (1) two of the four new tests pass on the old code, so only the two dialog tests prove the fix;
(2) the report's "its slider lines ink on paper" is backed for one of the three slider lines only;
(3) the dialog's title and buttons sit outside the new `ListTileTheme` and no test asserts them.

Checks I ran: `dart format` on the three changed Dart files → 0 changed; `flutter analyze` in `controller_app` → no issues;
`flutter test` in `controller_app` → **468 passed**, which matches the report's count exactly; the new file alone → 4 passed.
The suite rewrites `site/shots/*.png` as a side effect; I restored those five to HEAD, so the tree shows no other change.
I could not revert the fix to watch the new tests fail (see Could not check), but the report's arithmetic checks out: white on
`#FFF6E3` is 1.0744:1, `#120D2E` on it 17.41:1, `#1E1646` 15.53:1, and night `inkSoft` over paper `#595364` 6.87:1.

## Findings

- **should** controller_app/test/stick_text_contrast_test.dart:50 The two Settings tests assert what `ToyCard` already did
  before this job (ink tiles, `toy_card.dart:184`), so they pass on the old code; only the two dialog tests fail without the
  fix. → keep them, but say in the group's comment that the Settings pair guards `ToyCard` and the dialog pair is the B-017
  evidence, so nobody later counts four tests as four proofs.
- **could** controller_app/test/stick_text_contrast_test.dart:47 `'Button size:'` is a hand-typed slice of
  `SettingsText.stickButtonSizeLine` (`packages/party_host/lib/src/text/settings_text.dart:104`), and the dead-zone and
  sensitivity lines are not measured, while report line 13 says "its slider lines".
  → find by `SettingsText.buttonSize`, and assert the other two `_slider` lines or narrow the report's wording.
- **could** controller_app/lib/src/ui/stick_dialog.dart:32 Only `content` gets the theme: the title `PhoneText.sticks` and
  the two action buttons are ink today purely through `dialogTheme` (`toy_theme.dart:78-79`) and no test reads them.
  → add the title (found under `find.byType(AlertDialog)`, since 'Sticks' also names the mode tab) to `expectReads`.

## Decisions to confirm

- The fix sits in the app (`paper_tiles.dart`) because `packages/toy_look` and `main.dart` are outside `allow:`; the TV app
  and any later paper surface still get white tiles at night until `toy_theme.dart:41` is fixed. Confirm that hand-over is
  wanted, and that `paperTileTheme` is deleted in the same job that fixes `toy_look` (as the report's Hand-over says).
- `paper_tiles.dart:10` is named for every tile on paper but has one caller; a tile added to a dialog later gets the old
  colour unless someone remembers the wrap. Confirm the root fix should come before more dialog tiles exist.
- Night is reached at 20:00 through the injected look clock; the app takes its brightness from the palette, not the system
  (`toy_theme.dart:104`), so midday/night is the right pair for the brief's "light and dark". Confirmed true, no action.

## Could not check

- That the new test fails on the old code: a review may not revert the fix, and no run-findings.md exists for this job. The
  old white-at-night text colour and the 1.07:1 figure are both correct by reading the theme and by arithmetic.
- Whether `ListTileTheme(data:)` replaces or merges with the app's own `listTileTheme` in this Flutter version (the SDK
  source is outside my sandbox); nothing is lost today because `toy_theme.dart:41` sets only text and icon colours.
- Anything on a device: the owner's eye on the next build is still the only proof of the screenshot.
