# night1b n1d report: scoring v2 pinned, one champion rule

## Summary

Done. Added `NightState.championsAmong(players)`, the night's champion under the Quick night rule, and a new test file that pins the scoring rules and the champion against the scoreboard's place 1.

Files changed:
- `packages/party_host/lib/src/night/night_state.dart`: new getter `championsAmong` (after `rows`), and `import 'champion.dart'`. It maps `rows(players)` to `ChampionEntry(id, points: total)` and returns `ChampionChain.quickNight.champions(...)`. File is 356 lines (limit 380).
- `packages/party_host/test/night_scoring_test.dart` (new, 90 lines): 8 tests, listed below.
- `docs/briefs/m17/night1b/n1d-report.md` (this file).

Decisions:
- "place" was left as the scoreboard's shared place: ties share, and a player who left keeps theirs. No new points-by-place mapping; no change to rows, ties, left players or awards.
- The champion is computed from `row.total`, so the +3 award points count, as they do in the rows.
- Test (d) compares `championsAmong` with the ids of `NightRow.place == 1` in every case, as the brief asks.

Tests-first: the new file was written first and run on the base. It failed to compile there (`championsAmong` undefined), so all 8 tests failed together. That means tests (a) to (c) were not separately shown to fail on the base; they are the brief's "exempt" pins and they pass now. (d) is the test that fails on the base by construction.

Computed values (from the tests, all passing):
- (a) `nightPointsScale` = 1, `lastRoundPointsScale` = 2.
- (b) `settingsForRound(withChaos(party), lastRound: true)`: pointsScale 2, chaos off. `lastRound: false`: pointsScale 1, chaos party.
- (c) three players (p1, p2, p3), round 1 `{p1: 3, p2: 1}`, round 2 `{p2: 4, p3: 2}`: totals `{p1: 3, p2: 5, p3: 2}` = the sum of the points given per player.
- (d1) one leader (p1 5, p2 3, p3 0): champions `{p1}`, place 1 `{p1}`.
- (d2) tie for first (p1 5, p2 5, p3 1): `{p1, p2}`, place 1 `{p1, p2}`.
- (d3) everyone at 0: `{p1, p2, p3}`, place 1 the same.
- (d4) leaver holds the lead: p3 scores 6, p1 2, p3 leaves the roster: `{p3}`, place 1 `{p3}` (the row keeps its place).

Checks:
- `tools/mine.sh` (base, before the change): FAILED, the new test file did not compile (`championsAmong` undefined). Expected.
- `tools/mine.sh` (after the change): `OK 28 tests packages/party_host`, `ok: 2 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`.
- `dart analyze` on the two changed files: No issues found.
- Note: the format step reformatted the new test file (the `NightState.start(...)` calls are split across lines).

Self-check (docs/review-rules.md part A):
1. Host setups: no host-setup code is touched; the function is pure over `rows`. Covered by the tests in `champion_test.dart` (pin against rows) and by (d).
2. Kept state: `championsAmong` keeps no state; the night's `seen` map keeps the leaver's row. Shown by (d4).
3. Combination with the pause menu, host away, player away, "Get ready", dropped link, results, leaving: no UI or flow change. Shown by (d4) for a player who left.
4. Stayed in the job's folder and in `allow:`. Yes.
5. Stop rather than overstep: nothing needed stopping.
6. Every look: no UI change; N/A.

## Hand-over

- The getter is not called by any lib code yet; the scoreboard still reads place 1 from `rows`. Wiring the champion to `championsAmong` is not part of this job.
- The brief's pins for (a) to (c) were not run separately on the base (see Tests-first above).

## Commit message

party_host: championsAmong gives the Quick night champion

Adds NightState.championsAmong: the night's champion under the Quick
night rule (most points, ties share), built from the scoreboard's rows
so it agrees with place 1, with the leaver's row kept. A new test file
pins the x2 last round, the cat sitting out in it, a round adding only
its points, and the champion against place 1 in four cases.

## Status row

n1d done: x2 last round, no random bonuses, and championsAmong (Quick night champion = place 1, ties share) pinned by 8 tests; open: no lib caller uses championsAmong yet.

## Delete

- none
