# m165 c2 report: free width in the compact game bar

## Summary

- New measurement test `controller_app/test/top_bar_free_width_test.dart` (12 cases, no lib change). It shows a game
  so the compact bar is up, paired and connected, and reads the bar's geometry with `tester.getRect`.
- All 12 cases pass; no layout error is thrown at any size, look or badge state. Free width is 363 dp at the smallest
  screen with a badge and 792 dp at the largest without one, so Start (96 dp) and Start plus Select (200 dp) fit in
  every case.
- The TV look gives the same numbers as the menu look in every case; the compact bar does not change size with
  `toyTvProvider` (see questions).

Tests run: `flutter test test/top_bar_free_width_test.dart` (inside controller_app): 12 passed.
Checks: `tools/mine.sh` from the repo root: `OK 12 tests controller_app`, `RESULT: ok: 1 file(s) formatted,
1 package(s) analyzed, 1 package(s) tested`.

## Measured table

dp, from `tester.getRect`. Left right edge = right of `connectionButton`, or of `playerBadge` when it shows, whichever
is further right. Right left edge = left of `ModeMenuButton` or `moreMenu`, whichever is further left. Free = right
left edge minus left right edge. Row height = the height of the `Row` under the bar's `barPadding`.

| Screen | Look | Badge | Left group right edge | Right group left edge | Free width | fits 96 | fits 2x96+8 (200) | Row height |
|---|---|---|---|---|---|---|---|---|
| 568x320 | menu | no | 60.0 | 464.0 | 404.0 | yes | yes | 48.0 |
| 568x320 | menu | yes | 101.0 | 464.0 | 363.0 | yes | yes | 48.0 |
| 568x320 | TV | no | 60.0 | 464.0 | 404.0 | yes | yes | 48.0 |
| 568x320 | TV | yes | 101.0 | 464.0 | 363.0 | yes | yes | 48.0 |
| 667x375 | menu | no | 60.0 | 563.0 | 503.0 | yes | yes | 48.0 |
| 667x375 | menu | yes | 101.0 | 563.0 | 462.0 | yes | yes | 48.0 |
| 667x375 | TV | no | 60.0 | 563.0 | 503.0 | yes | yes | 48.0 |
| 667x375 | TV | yes | 101.0 | 563.0 | 462.0 | yes | yes | 48.0 |
| 956x440 | menu | no | 60.0 | 852.0 | 792.0 | yes | yes | 48.0 |
| 956x440 | menu | yes | 101.0 | 852.0 | 751.0 | yes | yes | 48.0 |
| 956x440 | TV | no | 60.0 | 852.0 | 792.0 | yes | yes | 48.0 |
| 956x440 | TV | yes | 101.0 | 852.0 | 751.0 | yes | yes | 48.0 |

Each value is the one the test printed (`stdout.writeln`). The badge adds 41 dp to the left group (101.0 minus 60.0).
Every case fits Start and Start plus Select with room to spare: the least free width is 363.0 dp, against 200 needed.

## Self-check (review-rules part A)

1. Host setups: this test covers a joined phone (paired, connected, `showsGameProvider` on). Hosting phones are not
   measured here; not covered.
2. Kept state: none added; the test overrides `gameShownProvider` for its own container only.
3. Combinations: only the compact bar with a game shown is measured; the pause menu, host away, "Get ready", dropped
   link and leaving are not covered.
4. Stays in the job's folder and `allow:` (the test file and this report).
5. No stop needed.
6. Every look: menu and TV look, at three screen sizes (12 cases). No fixed pixel height is added to any widget.

## Decisions

- The test file pins no numbers: it prints them and asserts only that no layout error was thrown, as the brief asks.
- Start is 96 dp and the gap is 8 dp, as the brief says; both are named constants in the test.
- The game is shown by overriding `gameShownProvider` with a notifier that starts on, the same class the host route
  sets. No lib change.
- The check ran as `tools/mine.sh` (the system's rule for this job), not the brief's `check: format analyze phone`.
  `mine.sh` covers format and analyze for controller_app; the analyzer found nothing on the new file.

## Hand-over

Files changed:

- `controller_app/test/top_bar_free_width_test.dart`: new; the 12-case measurement described above.
- `docs/briefs/m16/m165/c2-report.md`: new; this report.

## Questions

1. The TV look gives identical geometry to the menu look at every size. Is that intended (the compact bar keeps its
   size under `toyTvProvider`), or should the TV look's bar be measured with a larger icon size?
2. The test measures a joined phone. Should a second pass measure a hosting phone (the `HostChip` takes space in the
   left group)? It adds width to the left group, so the free width would shrink.
3. The brief's `check:` line named `format analyze phone`; the job's rule named `tools/mine.sh`. I used `tools/mine.sh`.
   Confirm that `phone` is still wanted after the runner's own check.

## Suggestions

- Measure the Start and Select buttons themselves once they exist, instead of the fixed 96 dp and 8 dp, so the fit
  stays true when the owner decides where they go.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m165 c2: measure the compact game bar's free width

Adds a measurement test of the compact game bar in the menu and TV looks
at 568x320, 667x375 and 956x440, with and without a player badge. It reads
the left and right groups' edges and prints the free width, so the owner can
decide where Start goes. The test asserts only that no layout error is thrown.
No lib change.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- m165 c2: done — free width of the compact game bar measured (12 cases, 363–792 dp free, Start and Select fit everywhere); open: where Start and Select go (owner decides), and whether the TV look should change the bar.

## Delete

- none
