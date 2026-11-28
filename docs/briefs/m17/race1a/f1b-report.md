# race1a f1b report: maxPerSide setting (2 to 4), join follows it

## Summary

- `PuzzleSettings` gets `int maxPerSide` (default 2): ctor, field, `ranges` entry `(min: 2.0, max: 4.0, step: 1.0)`, `toJson`, `fromJson` (clamped to 2..4, a broken value gives 2). Same shape as `timeLimitS` / `pointsScale`.
- `sideForNewPlayer(teams, {int cap = maxPerSide})` uses `cap`. The top-level `const maxPerSide = 2` is unchanged.
- In `_JoinScreenState`, the cap is `maxPerSideFor(widget.choice.level, <saved setting>.maxPerSide)`:
  - `_cap` getter (`ref.read`) for the handlers: `_simulatedJoin`, `_ownJoin`, `_tap` (A, left/right), `_pickSide`.
  - `build` reads it with `ref.watch` for `full`.
- Default stays 2, so a 2-a-side game seats exactly as before.
- Tests: new `join_cap_test.dart` (5 tests) and one new case in `puzzle_game/test/settings_test.dart`.
- `tools/mine.sh`: format OK, analyze OK for `packages/party_host` and `packages/puzzle_game`, touched tests OK (`OK 6 tests packages/party_host`, `OK 5 tests packages/puzzle_game`). It failed once on an analyzer info in my settings test (`const` missing); fixed and re-run clean.

Test counts seen: `packages/party_host` 6 tests OK, `packages/puzzle_game` 5 tests OK (from mine.sh's touched-test run). The full suite was not run here (the runner does that).

## Tests-first

Tests written before the code. On the base they fail by missing parameter/field (`cap:` argument, `maxPerSide`), which the brief exempts. Expectations and computed values:

- Default cap 2: `_fill(cap: 2, players: 9)` joins 4 (two a side); `sideForNewPlayer(teams)` is null.
- Cap 3: `_fill(cap: 3, players: 9)` gives 3 left + 3 right; `sideForNewPlayer(teams, cap: 3)` is null.
- Cap 4: `_fill(cap: 4, players: 10)` gives 4 left + 4 right; `sideForNewPlayer(teams, cap: 4)` is null.
- Setting 4 on Easy: `maxPerSideFor(Level.easy, 4)` = 2; `_fill` joins 4 (two a side).
- Setting 4 on Medium: `maxPerSideFor(Level.medium, 4)` = 4; `_fill` joins 8.
- Settings: `defaults.maxPerSide` = 2; `fromJson({'maxPerSide': 3})` = 3; `9` → 4; `1` → 2; `'four'` → 2; round trip of `PuzzleSettings(maxPerSide: 4)` = 4; `ranges['maxPerSide']` = `(min: 2.0, max: 4.0, step: 1.0)`.

## Self-check (review-rules part A)

1. Host setups: the join path is shared by TV, phone "Play on this phone", "Show on this device" and joined phone. Only the pure rule is tested (`join_cap_test.dart`); no widget test of each host setup was added. Peer one build older: the new key is read with a default, so an old saved settings JSON gives 2.
2. Kept state: no new state. The cap comes from the saved settings, read each time.
3. Combinations with pause, host away, player away, "Get ready", dropped link, results, leaving: not changed; the cap only applies when a player joins or picks a side. Not widget-tested.
4. Files: all within `allow:`.
5. Stop: none needed.
6. Looks: no look changed; no pixel heights added.

## Decisions

- Added the cap as a `cap` argument on `sideForNewPlayer` with the default `maxPerSide`, as the brief says.
- Read the cap through `maxPerSideFor(level, setting)` in the state class, not in a new top-level helper, to stay under the 380-line limit for `join_screen.dart` (it is now 374).
- Added no settings-screen row for `maxPerSide`. The brief's change list does not include it, and a row needs a `HostText` string, and `lib/text` is not in `allow:`.

## Blocked

None.

## Questions

1. The host cannot change `maxPerSide` yet: there is no row on the playtest settings screen. Adding it needs a `HostText` label (`lib/text` is outside `allow:`) and maybe a job of its own. Should the row come in f1c or a later job?
2. `join_screen.dart` is at 374 lines (limit 380). The next job that touches it should split it.
3. `settings_test.dart` already has no test that lists every range, so the screen tests were not changed. The runner's full suite will show whether anything else lists the ranges.

## Suggestions

- Add a widget test in a new file that opens the join screen with the setting at 4 on Medium and checks that a fifth player on a side is turned away. The rule is tested here, but not the wiring.

## Hand-over

Files changed:
- `packages/puzzle_game/lib/src/settings.dart`: `maxPerSide` field, ctor default 2, `ranges` entry, `toJson`, `fromJson` clamp.
- `packages/party_host/lib/src/ui/join_screen.dart`: `sideForNewPlayer` takes `cap`; `_cap` getter; `build` watches the cap; handlers use `_cap`.
- `packages/puzzle_game/test/settings_test.dart`: one new test case for `maxPerSide`.
- `packages/party_host/test/join_cap_test.dart` (new): cap 2, 3, 4 and the Easy/Medium limit.

Checks: `tools/mine.sh` ok (format, analyze both packages, touched tests). Not run: `tools/check.sh` (the script runs it), full test suite (runner).

## Commit message — a draft

race1a f1b: maxPerSide setting 2 to 4; the join cap follows it

- PuzzleSettings.maxPerSide (default 2, clamped 2..4) with its range,
  toJson and fromJson, as timeLimitS is done.
- sideForNewPlayer takes a cap; the join screen passes the cap from the
  saved setting, limited by the level through maxPerSideFor.
- Default stays 2, so a 2-a-side game seats as before.
- New join_cap_test.dart and a settings test case; they fail on the base
  by the missing parameter and field.

## Status row

f1b done: maxPerSide setting (2 to 4, default 2) and the join cap follow it via maxPerSideFor. Open: no settings-screen row for it yet; side panel still reads the const (f1c).

## Delete

- none
