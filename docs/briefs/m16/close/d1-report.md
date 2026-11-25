# d1 report: test cleanups (touch target scrollable, unused differs field)

## Summary

STATUS: stopped. The Settings scoping exposed a layout overflow in Settings at 320x640 in the TV look, which is outside this job's allow list.

Files changed:
- `controller_app/test/touch_targets_test.dart`: `measureScrolling` now walks the Settings list (`find.descendant` of `SettingsScreen` over `Scrollable`) instead of the first `Scrollable` on screen, and asserts Settings is open. The Settings tap now calls `ensureVisible` first, because Connect's Settings button is below the fold at some sizes. Added the `SettingsScreen` import.
- `packages/puzzle_game/test/round_label_test.dart`: `differs` no longer returns `top` (the field and the code that filled it are gone). `count` and `right` are unchanged.

Test results (`tools/mine.sh`, final run):
- puzzle_game: OK 12 tests (round_label_test passes with the new record shape).
- controller_app touch_targets_test: +20 -1. The one failure is `every touch target on settings at 320x640 in the TV look`.
- Format: passed (dart format ran on both files). Analyze: no findings on the two files.

What the failure is:
- Before the `ensureVisible` fix, the Settings tap failed silently at 5 size/look combinations (`Warning: A call to tap() ... could not be hit`). The Settings route never opened, so the test measured Connect's list under the name "settings". That is the hole the brief's item 1 was about.
- With the tap fixed, Settings opens at 320x640 TV and the framework reports `A RenderFlex overflowed by 43 pixels on the right` during layout. The "Looking up a deactivated widget's ancestor" error is a side effect of reporting that overflow, not a separate cause.
- The overflow is in app layout (lib), which I may not change. I did not loosen the check or add the case to `knownBelow48`, because knownBelow48 is for touch targets under 48 dp, not overflows.

## Decisions

- Scoped the scroll to `SettingsScreen` with `find.descendant(of:, matching:)` and `.first`, as the brief suggested.
- Added `ensureVisible` before the Settings tap. The brief did not name it; it was needed to open Settings at the five combinations where the tap could not hit.
- Added `expect(find.byType(SettingsScreen), findsOneWidget)` in `measureScrolling`, so a missed route fails loudly instead of measuring the wrong screen.
- Used `tools/mine.sh` for checks, as the header says. The brief's item 3 also asked for `flutter test` on both files; I ran `flutter test` on touch_targets_test.dart once for diagnosis, with output filtered.

## Self-check (review-rules part A)

1. Host setups: the test covers pad, connect and settings screens (phone sizes only; no TV host change in this job). Not changed.
2. Kept state: none added.
3. Pause menu, host away, etc.: not touched by this test-only change.
4. Stayed inside allow: yes, only the two test files and this report.
5. Stop rather than overstep: the overflow in Settings is named above; it is a lib change and was not made.
6. Every look: the test runs the menu and TV looks at all four sizes, except the known `568x320` TV case. The 320x640 TV Settings failure is the open item.

## Hand-over

- The controller_app touch-target test is red on purpose: it now reaches the real Settings screen at 320x640 TV and finds a 43 px overflow there. A lib owner must fix that layout, or the owner must decide the case is excluded. This job did not decide that.

## Questions

1. Who fixes the 43 px RenderFlex overflow in Settings at 320x640 in the TV look (controller_app lib, not in d1's allow list)? Should the case be excluded in the test, or fixed first?
2. Should `ensureVisible` be the standard way to open Settings from Connect in tests, or should the Settings button be found through a key?

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test: scope touch-target scroll to Settings; drop unused differs.top

Walk the Settings list, not the first Scrollable on screen, so the
scroll measures Settings rows. Scroll Connect's Settings button into
view before tapping it, since at some sizes the tap missed and the
test measured Connect under the settings name. Assert Settings is open.
Drop the unused top field from the puzzle_game differs record.
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- m16 close d1: test cleanups done (Settings-scoped scroll, unused differs.top removed). Open: Settings overflows 43 px at 320x640 TV, so the touch-target test is red until the layout is fixed or the case is decided.

## Delete

- none
