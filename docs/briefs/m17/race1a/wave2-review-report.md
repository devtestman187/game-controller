# race1a wave2 review: f1b (commit e57b3402)

## Summary

- Verdict: small fixes
- Counts: 1 must, 2 should, 2 could
- Top 3:
  1. The setting reaches the join screen (`_cap`, `build`) but no test fails if that wiring is dropped (join_screen.dart:286).
  2. `join_screen.dart:103` doc still says the most a side seats is `maxPerSide` (the const 2); now a setting can make it 4.
  3. `join_cap_test.dart:40` and `:46` repeat the `maxPerSideFor` asserts already in `per_side_rule_test.dart:6` and `:18`.

## Findings

- **must** packages/party_host/lib/src/ui/join_screen.dart:286 `_cap` (and `build` at :341) read the saved `maxPerSide`, but every new test calls the pure `sideForNewPlayer` or `maxPerSideFor`; replacing `_cap` with the const 2 passes all of them, so the brief's "setting 4 on Easy still seats only 2 a side" is not tested on the screen → add a widget test in a new file (e.g. packages/party_host/test/join_cap_screen_test.dart) that sets the provider to 4 on Medium, joins five players to one side, and expects the fifth turned away; and on Easy expects two a side.
- **should** packages/party_host/lib/src/ui/join_screen.dart:103 the class doc says a seat is "the most Shape Race seats ([maxPerSide] a side)"; with the setting, the most is up to 4 on Medium → reword to "2 a side by default, up to 4 with the maxPerSide setting, limited by the level".
- **should** packages/party_host/test/join_cap_test.dart:40 and :46 the Easy and Medium tests only assert `maxPerSideFor(Level.easy, 4)` = 2 and `(Level.medium, 4)` = 4, which `packages/puzzle_game/test/per_side_rule_test.dart:6` and `:18` already assert; they test f1d's function, not the join → delete both tests here and keep the seat counts in the new screen test.
- **could** packages/party_host/lib/src/ui/join_screen.dart:286 and :341 the expression `maxPerSideFor(widget.choice.level, ...maxPerSide)` appears twice (once as `ref.read` in `_cap`, once as `ref.watch` in `build`) → keep both, or pull the level-and-setting pair into one named helper that takes the value; no change needed for correctness.

## Decisions to confirm

- No settings-screen row for `maxPerSide` (f1b-report Decisions, line 40): the host has no way to change the setting in the app, so the feature is inert until a later job adds the row and its `HostText` label. Confirm which job owns that row.
- The side panel still draws the const 2 seats (packages/party_host/lib/src/ui/join_side_panel.dart:126); with a saved 3 or 4 on Medium the fifth player joins a side that has no drawn seat. This is the state between f1b and f1c; confirm f1c closes it before any playtest uses the setting.
## Could not check

- Report self-checks I confirmed by reading: `join_screen.dart` is 374 lines; `build` is 38 lines; `fromJson` gives 2 for `'four'`, 4 for `9`, 2 for `1` (`d` clamps, settings.dart:121-124); an old JSON without the key gives 2; the cap is read each time, so no new state is kept.
- Brief item 4 (`dart analyze`) is reported clean by the worker via mine.sh; I did not re-run it (read-only job).

- `mine.sh` touched-test count "OK 6 tests packages/party_host" in f1b-report: the new file has 5 tests and no other party_host test was named; the sixth is unexplained, and I did not run the suite.
- `dart analyze` result (item 4 of the brief) and whether the whole-suite run passes on the base: not run by me (read-only job).
- Whether `settings_screen` renders each entry of `ranges` generically (not grep-checked in packages/party_host/lib).
- `docs/briefs/m17/race1a/run-findings.md` has no entry about f1b (its only line is about f1d), so no runner evidence about f1b tests was available.

## Commit message — a draft

race1a wave2 review: f1b findings, report only

- Review of e57b3402 (f1b, maxPerSide setting) against the guidelines,
  the review rules and the brief.
- No code or document changed; the report lists one must (screen
  wiring has no test) and two shoulds (stale doc at join_screen.dart:103,
  duplicate Easy/Medium asserts in join_cap_test.dart).

## Status row

wave2 review of f1b done: verdict small fixes (1 must, 2 should, 2 could). Open: screen-level test for the setting; join_screen.dart:103 doc; drop duplicate asserts in join_cap_test.dart; settings row and side-panel seats left to later jobs.

## Delete

- none
