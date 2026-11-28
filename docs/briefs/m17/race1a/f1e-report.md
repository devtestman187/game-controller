## Summary

The settings screen has a "Players per side" row after the time limit, shown as a plain number (2, 3, 4). Its + and − use the existing `maxPerSide` range (2 to 4, step 1) from `PuzzleSettings.ranges`. No join, panel or rule changed.

Files changed:
- `packages/party_host/lib/src/ui/puzzle_settings_screen.dart`: adds `('maxPerSide', playersPerSideLabel)` to `_rows` after `timeLimitS`; the value uses `playersPerSideValue` for `maxPerSide` and `HostText.settingValue` for the rest.
- `packages/party_host/lib/src/text/race_text.dart` (new): top-level `playersPerSideLabel` = 'Players per side' and `playersPerSideValue(num)` = plain rounded number.
- `packages/party_host/test/puzzle_settings_screen_test.dart`: one new test, "the players-per-side row shows 2 and its + stops at 4".

Tests-first: the new test was written before the row. On the base there is no `setting-maxPerSide` key, so it fails there (the `scrollUntilVisible` on the missing key throws). I did not run the base to show this.

Computed values in the test:
- Default: row shows `2`.
- After one + tap: `3`, `maxPerSide` = 3.
- After two + taps: `4`, `maxPerSide` = 4.
- After a third + tap: `maxPerSide` stays 4, row still shows `4`.
- Saved prefs contain `"maxPerSide":4`.

Checks:
- `tools/mine.sh`: PASS. Format, analyze of party_host, and 4 touched tests passed (`OK 4 tests packages/party_host`). Output was `RESULT: ok: 3 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.
- The test file changed on disk during the run (the format step, I believe); I did not revert it.

Self-check (review-rules part A):
1. Hosts: the row is in the shared settings screen, so it is on every host setup that opens Puzzle settings; the test opens it from the Play screen of the stub home.
2. Kept state: no new state; the value lives in the existing `puzzleSettingsProvider` and is saved with the rest. Reset restores the default (2) through the existing reset.
3. Combinations: the row only changes the value; the screen's other behaviour (Reset, Escape, the remote's focus on the first row) is unchanged.
4. Stayed in the allow list.
5. Nothing overstepped.
6. Look: the row is the same `_Row` stepper as the others; the test runs under the harness's default look; no new fixed height.

## Decisions
- The value is special-cased for `maxPerSide` in the screen because `HostText.settingValue` adds " s" to any key it does not name, and `host_text.dart` is outside my allow list and at the 380-line gate. The new `playersPerSideValue` in `race_text.dart` holds the plain number.
- The new test is in the existing `puzzle_settings_screen_test.dart`, because the brief named it and the allow list does not include a new test file.

## Hand-over
Not run: `dart analyze` by itself (tools/mine.sh already ran analyze on party_host, with no findings). `tools/check.sh` was not run, as instructed.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

race1a f1e: settings row for players per side

Adds a "Players per side" row after the time limit on the puzzle
settings screen, using the existing maxPerSide setting (2 to 4). The
value shows as a plain number; the label and formatter are in
race_text.dart because host_text.dart is at its 380-line gate.
Test: the row shows 2, + moves 2 to 3 to 4 and stops at 4, saved.

## Status row

f1e done: players-per-side row on the puzzle settings screen (2 to 4, plain number), tested. Open: nothing in this job; the HostText value formatter still adds " s" to any unnamed key.

## Delete

- none
