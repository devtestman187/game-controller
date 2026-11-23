# B-039 report: phone lobby list, one left-aligned column

## Summary

- Owner decision kept: the lobby block stays centred on the screen; the rows now form one left-aligned column of equal width, so avatars share one line.
- Tests first: `controller_app/test/lobby_alignment_test.dart` (new). Six tests: 2 looks × 3 cases.
  - Left-edge test (menu look, TV look): players `Al`, `Mia`, `A very long nickname`; the PlayerBadge left x of rows 1, 2, 3 must match within 0.5 px. **Failed on the old code** (rows were centred on each other, so each badge had its own left x). Passes after the fix.
  - Centring test (menu look, TV look): same three players; block centre x must equal screen width / 2 within 1 px. Passes on the old code and after the fix (the owner's rule is kept).
  - Single-player centring test (menu look, TV look): one player; block centre x within 1 px of screen half-width. Passes before and after.
- Fix in `controller_app/lib/src/ui/lobby_players.dart`: the `Column` (key `lobbyPlayers`, unchanged) now has `crossAxisAlignment: CrossAxisAlignment.start` and is wrapped in `IntrinsicWidth`, which sizes it to the widest row; the outer `Center` is unchanged. Badges, text, order, ellipsis and the empty-list `SizedBox.shrink()` are unchanged.
- Screen width in the test is `tester.view.physicalSize.width / devicePixelRatio`, so it does not depend on pixel ratio.

### Checks

- `tools/mine.sh`, first run (before the lib fix): format and analyze ok; `lobby_alignment_test.dart` FAILED, 2 tests (the left-edge test, menu look and TV look). Churn revert touched 3 generated Windows plugin files (the script reverts them; not my change).
- `tools/mine.sh`, after the lib fix: RESULT ok — 2 files formatted, controller_app analyzed, controller_app tests OK 6 tests.

### Not run

- `controller_app/test/phone_name_display_test.dart` and `controller_app/test/identity_phone_test.dart` were **not run as separate files**. The brief's step 3 asked for `flutter test` on them, but the job rules allow only `tools/mine.sh`, which runs only touched tests (the 6 from the new file). These two files were not touched, so `mine.sh` did not run them. The full controller_app suite runs in the wave check. No claim is made here that they pass.

## Decisions

- Kept `Center` and put `IntrinsicWidth` inside it, so the block stays centred as the owner decided. The Key stays on the `Column` (the brief allowed either).
- Added no new named constants: the 0.5 px and 1 px tolerances are test-side expectations, not tunables.

## Self-check (review-rules part A)

1. Host setups: the lobby is a phone-side widget; it shows the same for every host setup (the host sends `players`). Covered by the existing identity tests; not separately tested here.
2. Kept state: none; the widget is stateless and reads `clientStateProvider`. Empty list still draws `SizedBox.shrink()` (unchanged code path).
3. Combinations with pause, away, "Get ready", dropped link, results, leaving: not changed; the widget only lays out the rows it is given.
4. Only files in `allow:` were changed.
5. Nothing was skipped or stopped.
6. Looks: both the menu look (852×393) and the TV look (1180×820) are covered by the new test file; no fixed pixel height was added.

## Hand-over

- Files changed: see the Commit message section below.
- Open: run the full controller_app suite (the wave check) to cover `phone_name_display_test.dart` and `identity_phone_test.dart`.
- Question for the owner: none about this job.
- Suggestion: none.

## Commit message — a draft

Lay out the phone lobby list as one left-aligned column

Keep the lobby block centred on the screen (owner decision for B-039), but
lay its rows out as one column of equal width, so each avatar shares one
left edge. The column is sized to its widest row with IntrinsicWidth;
the Key, badges, text, order and empty-list behaviour are unchanged.
Adds lobby_alignment_test.dart: left-edge test fails on the old code,
centring tests guard the block position in the menu and TV looks.

## Status row

B-039 done: phone lobby rows share one left edge, block still centred; new lobby_alignment_test (6 tests) passes under mine.sh. Open: the wave's full controller_app run must cover phone_name_display_test and identity_phone_test, which were not run separately.

## Delete

- none
