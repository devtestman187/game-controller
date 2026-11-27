# y0h6 report: choices overlay below the top bar, 480 dp cap, round cleared while the host is away

tests-first: exempt fixing review findings. New tests went into the existing choices_screen_test.dart (the only test file allowed), so they are not in a new file.

## Files changed
- controller_app/lib/src/ui/controller_screen.dart: ChoicesOverlay is `Positioned(top: topBarHeightPx, ...)`, so the bar takes taps in a round.
- controller_app/lib/src/ui/choices_screen.dart: `choicesColumnMaxWidthPx = 480.0` + ConstrainedBox (key `choicesColumn`); `_msPerS`; an unknown result id shows `PhoneText.choicesNoChoice`; title and countdown now scroll with the cards (only Lock in is pinned), because the shorter overlay under the bar overflowed by 37 px in the TV look at 667x375.
- controller_app/lib/src/providers/choices.dart: `HostAway` clears the round (no pick sent); `HostBack` stays a no-op, so a stale round is not restored; dartdoc on ChoicesNotifier and copyWith.
- controller_app/test/choices_screen_test.dart: 6 new tests, each in both looks (bar tap + Settings, 480 cap at 900x420, unknown result id, HostAway/HostBack pair, clear on ViewStarted, second round replaces the first).
- controller_app/test/support/fakes.dart: unchanged.

## Checks
tools/mine.sh: OK, 103 tests controller_app, format, analyze clean.

## Computed values
- overlay top = `topBarHeightPx` (asserted by constant, not a literal).
- column width at 900x420 = 480 (`choicesColumnMaxWidthPx`).
- Before the layout change: overflow of 37 px in the TV look at 667x375.

## Notes / questions
1. "Leave path": the bar's way out is More > Settings; tested. The `leaveGame` button belongs to the host-away card, which is now uncovered; not tested here.
2. The "stale message after the end" test (finding 27) was not in this brief's list; not added.
3. The new tests were not run against the old code; by construction they target the removed behaviour (overlay covered the bar, no cap, HostAway ignored).

## Review-rules part A self-check
1. Host setups: the new tests run on a joined phone (pumpApp paired) in both looks; TV/PC host and "Show on this device" not touched by this change (overlay only on the joined view).
2. Kept state: starts at a ChoicesMessage, ends on ViewStarted, HostAway, a dropped link, or 3 s after the end; nothing going on = null (all tested).
3. Host away: tested (HostAway/HostBack test). Pause menu, player away, Get ready, results, leaving: unchanged by this job, not newly tested.
4. Stayed inside the allow list.
5. No stop needed.
6. Menu and TV look: every new test runs in both; no fixed pixel height for a look-sized widget (only the 480 width cap named by the brief).

## Commit message
phone1b y0h6: choices under the top bar, 480 dp cap, clear on host away

The choices overlay starts below the top bar so Settings stays reachable.
The card column is capped at 480 dp on wide windows.
HostAway clears the round without a pick; HostBack does not restore it.
An unknown result id shows "No choice". Title and countdown scroll with
the cards so the shorter overlay does not overflow in the TV look.

## Status row
y0h6 done: overlay below the top bar, 480 dp cap, round cleared on host away, tests added; open: stale-message-after-end test, host-away card leave path test.

## Delete
- none
