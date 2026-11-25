# n8b1 report: HomeView

tests-first: exempt a new widget with no earlier behaviour.

## Files
- controller_app/lib/src/home/home_view.dart: new pure `HomeView` (role buttons with anchor keys, name row, chip, Search again, Settings).
- controller_app/test/home_view_test.dart: 41 tests (order, callbacks, highlight, chip, hint, fit and 48 dp in both looks).

## Layout
- Width >= 480: name row and Settings on top, three roles in a Row (Join, Play, Display), chip below.
- Width < 480 (375x667, 320x640): name row, then the three roles and Settings stacked, chip below. A first try with Settings beside the name overflowed by 30 px at 320 wide in the TV look.
- A SingleChildScrollView wraps the page as the last resort; content is centred when it fits.
- Neutral fill is `colors.paper`; the highlighted one is `colors.good`. The found chip is green, the none chip paper.

## Computed values
- Breakpoint 480 px (`_stackBelowWidthPx`): three pills need about 150 each. Not measured beyond the tests passing.
- Button heights come from the look (menu 48, TV 64); the name row has minHeight and minWidth 48.

## Self-check
1. Looks: menu and TV looks tested at all four sizes. Hosts, joined phone and old peer do not apply (pure widget).
2-3. Not applicable: no state, no pause menu or link handling.
4. Only the allowed files changed.
6. No fixed pixel height on a look-sized widget; buttons use the look's height.

## Questions
- In the 48 dp test the name row is found as the single `InkWell`; a later InkWell on Home would break that finder.

## Commit message
Add HomeView, the pure Home hub widget

HomeView shows the nickname and character row, the three role buttons
in fixed order, a find chip with Search again, and Settings. The
button highlightedRole names is green. It stacks below 480 px width.
Tests cover order, callbacks, highlight, chip, hint, fit and 48 dp.

## Status row
n8b1: HomeView widget and tests done; wiring into the app (n8b2, n8d1) open.

## Delete
- none
