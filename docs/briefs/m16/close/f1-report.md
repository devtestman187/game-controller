# f1 report: Settings overflow at 320x640 TV, and d1's test cleanups

## Summary

STATUS: stopped. The test cleanups from d1 are in. The overflow fix is not made: the Row that overflows is in `settings_profile_section.dart`, which is not in this job's allow list, and its fix is a look decision.

- d1 test patch applied by hand (see Decisions). `touch_targets_test.dart` +20 -1; `round_label_test.dart` passes (OK 12 tests, puzzle_game).
- The one red test is the intended one: `every touch target on settings at 320x640 in the TV look is at least 48 dp or listed in knownBelow48`, failing with `A RenderFlex overflowed by 43 pixels on the right`.
- The overflowing Row: `controller_app/lib/src/ui/settings_profile_section.dart:243`, the `characterPreview` row (worker and marble figures, then an `Expanded` "shows next time" text). Its constraints are `0<=w<=256`, `mainAxisSize: max`, `crossAxisAlignment: center`, which match the card's inner width at 320 wide (320 - 2x16 page padding - 2x16 card padding = 256).
- Cause, as far as the dump shows: the two figures and their captions are fixed-width children; with the TV look's body type, they total 299 px (256 + 43), and the `Expanded` gets nothing. The caption widths are not measured separately; the 299 is the overflow plus the width.
- Not in `connect_panels.dart`, `your_character.dart` or `settings_screen.dart`: I checked the Rows in those files and in `settings_nickname_row.dart`. `your_character.dart` Rows use `mainAxisSize: min`, and `connect_panels.dart:300` is also `min`, so neither matches the dump.
- The brief's plain fix (`Flexible`/`Wrap`/ellipsis on the captions) would need an edit to `settings_profile_section.dart`. Whether captions wrap, ellipsise or move below the figures is a look choice, so I stopped.

## Decisions

- **d1 patch applied by hand, not with `git apply`.** The permission gate stopped `git apply --include=...`, and the worker rules forbid git commands that change state. I made the same edits with Edit, after reading each file. The `round_label_test.dart` change is the `differs` record without `top`. The `touch_targets_test.dart` change adds the `SettingsScreen` import, the `ensureVisible` before the Settings tap, the `expect(find.byType(SettingsScreen), findsOneWidget)` and the `find.descendant` scroll.
- **Did not apply the d1 patch's `docs/briefs/m16/close/d1-report.md` hunk.** It is not in this job's allow list (only `f1-report.md` is).
- **Stopped at the lib fix, not a plain wrap.** The brief says to stop when the fix needs a look decision. The overflow file is also outside the allow list (rule 5 of the self-check).
- **`tools/mine.sh` reformatted the two test files** (its format step reports "2 file(s) formatted"). Only its failure output is shown; the only failure is the Settings case above.

## Self-check (review-rules part A)

1. Host setups: the touch-target test covers pad, connect and settings at the menu and TV looks (phone sizes). Test: `touch_targets_test.dart`, +20 -1. No host change.
2. Kept state: none added or changed.
3. Pause menu, host away, "Get ready", dropped link, results, leaving: not touched by this test-only change.
4. Stayed inside allow: lib untouched; the two test files changed; `f1-report.md` written. `d1-report.md` not created.
5. Stop rather than overstep: the overflow is in `settings_profile_section.dart:243`, outside allow; named above, not fixed.
6. Every look: the Settings case runs at 320x640 in the TV look (the failing one) and at the menu look and the other sizes (passing). No fixed pixel height was added.

## Test runs

- `tools/mine.sh` (after the edits): format, analyze and touched tests. Result: `FAILED tests controller_app`: the one Settings case above. `OK 12 tests packages/puzzle_game`. `RESULT: FAILED: 1 check(s) failed`. Analyze reported no findings for the changed files.
- `flutter test test/touch_targets_test.dart` (a second run in `controller_app`, for the count): `+20 -1`, with the same Settings failure. The 21 cases are 3 screens x 7 (4 sizes x 2 looks, minus `568x320` TV).
- The overflow was read from one `flutter test ... --plain-name` run: `RenderFlex#17de2`, constraints `0.0<=w<=256.0`, size `256.0 x 651.0`, `direction: horizontal`, 43 px.
- Not run: `tools/check.sh` (the brief forbids it); the full settings test set beyond what the touched files cover.

## Hand-over

- The touch-target test is red on purpose, as d1 said. It stays red until the 320x640 TV Settings layout is fixed or the case is excluded.
- Nothing in `lib/` changed, so the d1 test cleanups are the only change this job makes.

## Questions

1. The overflowing Row is in `controller_app/lib/src/ui/settings_profile_section.dart:243`, not in the brief's three files. Should `settings_profile_section.dart` be added to the allow list for a plain fix?
2. For the fix itself, which look do you want: the captions wrap under the figures, ellipsise, or the preview moves below the row (a look decision)?
3. Should the 320x640 TV Settings case be excluded from the test (listed in `knownBelow48` or skipped), or fixed first? `knownBelow48` is for targets under 48 dp, so an exclusion would need its own list.

## Suggestions

- The brief's step 2 guessed `connect_panels.dart` or `your_character.dart`. The dump points at `settings_profile_section.dart`. Next time, name the file the Row is in (the brief could check it by grep before it is written).
- If the owner picks "wrap", a `Wrap` of the two figures with the `Expanded` text as its own line is a one-widget change; `Flexible` on each caption would ellipsise and keep one row.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test: scope touch-target scroll to Settings; drop unused differs.top

Walk the Settings list, not the first Scrollable on screen, so the scroll
measures Settings rows. Scroll Connect's Settings button into view before
tapping it, since at some sizes the tap missed and the test measured Connect
under the settings name. Assert Settings is open. Drop the unused top field
from the puzzle_game differs record. Settings at 320x640 TV is still red: the
preview row overflows 43 px (settings_profile_section.dart:243).
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- m16 close f1: stopped, no lib change. Done: d1 test cleanups (Settings-scoped scroll, ensureVisible on Settings, differs.top removed). Open: Settings preview row overflows 43 px at 320x640 TV (settings_profile_section.dart:243, not in allow); touch-target test red until the layout is fixed or the case is decided.

## Delete

- none
