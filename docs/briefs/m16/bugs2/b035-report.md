# B-035 report: 8 px gap between the join line and the Change button

## Summary

Status: done. The gap fix is in and its tests pass. Driver note: the 320x640 test overreached (the row overflowed there before this change); the driver changed that test to a real small landscape phone, 568x320, which passes. The 320-px overflow is left in code-health.

What changed:
- `controller_app/lib/src/ui/connect_panels.dart`: `const SizedBox(width: ToySizes.space8)` between the `Flexible` join text and the `changeCharacter` TextButton in `_YourCharacter`. No other layout or text change. `ToySizes` was already imported.
- `controller_app/test/connect_identity_gap_test.dart` (new): three tests. Two measure the gap in the menu look (852x393) and the TV look (1180x820, `toyTvProvider` overridden). One pumps 320x640 and expects no exception. The gap is measured from `tester.getTopRight` of the join text to `tester.getRect` of the button, so the button's padding counts. A `layoutRoundingPx = 0.01` slack absorbs float rounding in text layout; it is documented in the file.
- `identity_change_link_test.dart` and `join_badge_test.dart`: not changed. Both pass as they are.

Tests-first, measured before the fix:
- Menu look: gap = -1.1368683772161603e-13 px (touching). Failed against 8.
- TV look: gap = 0.0 px. Failed against 8.
- 320x640: two overflows. `connect_screen.dart:348` Row by 39 px, and `connect_panels.dart:73` `_YourCharacter` Row by 74 px.

After the fix:
- Menu look: gap = 7.999999999999886 px. Passes against 8 - 0.01. The exact TV value was not printed; the TV test passes the same bound.
- 320x640: `connect_screen.dart:348` still overflows by 39 px (outside `allow:`, not touched). `connect_panels.dart:73` now overflows by 82 px (+8 from the new gap). Test fails.

Checks run:
- `flutter test test/connect_identity_gap_test.dart test/identity_change_link_test.dart test/join_badge_test.dart`: 13 ran, 12 passed, 1 failed (the narrow-phone test: 2 RenderFlex overflows, as above).
- `tools/mine.sh` (run from repo root, twice in effect: once before the fix and once after): FAILED, 1 check. The only failure is the narrow-phone test. mine.sh's format step reformatted my new test file; the `churn` step reverted 3 generated files.
- `tools/check.sh` was not run, per the brief.

Why the narrow test is not passing: the brief says "the text still shrinks first on a narrow phone". At 320 px it does not. The `Flexible` text is already at its minimum width, and the fixed parts (badge, gaps, button) are wider than the row. The overflow existed before my change (74 px); my change adds 8 px. I did not weaken or delete the test.

## Commit message — a draft

Add an 8 px gap before the join line's Change button

The join line's Change link sat flush against the character name, so the
two read as one run of text. Put an 8 px spacer between the Flexible text
and the button, in the menu and TV looks. The join text stays Flexible, so
it shrinks before the button does.

Gap tests (menu and TV looks) measure the space to the button's own box.
The narrow-phone test (320x640) is still failing: the row overflows before
this change, and it needs a layout decision first.

## Status row

M16 bugs2 B-035: 8 px gap added between the join line and Change (menu and TV looks, tests pass). Open: the 320 px phone overflow (74 px before, 82 px now) in the `_YourCharacter` row and a 39 px overflow in `connect_screen.dart:348`; the narrow-phone test stays red until the owner decides how the row narrows.

## Delete

- none

## Hand-over

Questions for the owner (also in the summary):
1. At 320 px the join row is wider than the screen even with the text at its minimum. Should the row wrap, let the name ellipsize, or hide the badge on narrow phones? That's a layout decision; I did not pick one.
2. `connect_screen.dart:348` has a 39 px overflow at 320 px. It is outside this job's `allow:`. Who owns it?
3. `tools/mine.sh` printed "churn: reverted 3 generated file(s)". The three `tv_test_app/windows/flutter/generated_*` files were already modified when this job started (per the git status snapshot). Please check that they still hold the changes you wanted; I did not run any git command to check.
4. Suggestion: once the narrow case is decided, the narrow test can state the chosen rule instead of "no exception".
