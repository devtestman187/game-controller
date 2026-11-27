# night2a f1: director tests, DirectorInput, one-player steady

## Summary

- `NightDirector.pick` now takes `DirectorInput` (new file `director_input.dart`) and `{required Random random}`: two parameters, down from six.
- A table of fewer than two totals is steady (`_mood`: `if (totals.length < 2) return _Mood.steady;`). A solo night no longer counts as close, so it no longer raises a tier.
- Five new director tests, one per rule the review found untested: rule (b), rule (d), the one-tier ease, the one-tier raise, and the one-player steady case. Director tests: 13 → 18.
- Each new test fails when its rule is removed. Proven one at a time by removing the rule in the lib file, running `flutter test` on the director test file, and restoring it. Results below.
- `pick` is split: `_options` (tier range and not-last filter), `_aim` (target tier and kind filter, a record `(target, options)`), `_reasonFor` (reason switch). `pick` is about 20 lines.
- `DirectorReason` values each have a one-line dartdoc saying when they are chosen. "carry this code" is now "will carry this code (B8, M17 plan 1.2)". `DirectorPick.toString` is removed.
- `_choose` signature is wrapped by `dart format`; no line is over 120 columns in the three files.
- `tools/mine.sh` passes: format, analyze of `packages/party_host`, and 18 tests.
- No caller of `pick` exists outside the director test (grep of `packages/party_host`), so nothing else changed.

## Details

### Computed values for the test expectations

Lead = leader − last place. Lopsided when lead ≥ 0.5 × leader; close when lead ≤ 0.2 × leader.

| Test | Totals | Lead / leader | Mood | Last played (tier index) | Target | Options after filters | Expected |
|---|---|---|---|---|---|---|---|
| (a) rule b | [10, 6] | 4 / 10 | steady | shapeMedium (1) | 1 | shapeEasy only (shapeMedium left out) | shapeEasy, steady |
| (b) rule d | [10, 2] | 8 / 10 | lopsided | shapeHard (2) | max(0, 2−1) = 1 | shapeEasy only (kind filter) | shapeEasy, kindForLastPlace |
| (c) the ease | [10, 2] | 8 / 10 | lopsided | arenaHard (2) | max(0, 2−1) = 1 | shapeHard, shapeMedium (no kind); nearest to 1 is medium | shapeMedium, easedAfterLopsided |
| (d) the raise | [10, 9] | 1 / 10 | close | arenaEasy (0) | min(2, 0+1) = 1 | shapeEasy, shapeMedium; nearest to 1 is medium | shapeMedium, raisedAtCloseTable |
| one player | [10] | 0 / 10 | steady (new) | shapeMedium (1) | 1 | shapeEasy (0) and shapeHard (2) tie at distance 1; tie goes to easier | shapeEasy, steady |

Without the one-player guard the old code gave close → target min(2, 1+1) = 2 → shapeHard, raisedAtCloseTable.

### Rule-removal proof (run 1 at a time, all restored)

`flutter test packages/party_host/test/night_director_test.dart` with one rule removed each time:

- rule (b) removed (`return inRange;` in `_options`): fails only "a steady table picks the easier variant when the last played one is left out" (+17 −1).
- rule (d) removed (`options: options` in the lopsided case of `_aim`): fails only "a lopsided table with a kind variant in the pool picks it with reason kindForLastPlace" (+17 −1).
- ease removed (`target: lastIndex` for lopsided): fails only "a lopsided table eases one tier below the last played tier" (+17 −1).
- raise removed (`target: lastIndex` for close): fails only "a close table raises one tier above the last played tier" (+17 −1).
- one-player guard removed: fails "a table of one player is steady, not close" (+16 −2). The second failure is "all-zero and empty totals count as steady": with the guard gone, an empty list reaches `totals.reduce` and throws. The guard `length < 2` covers the old `isEmpty` case as well.

After the proof every rule is restored; `grep` finds no `PROOF` marker in the lib file.

## Self-check (review-rules part A)

1. Host setups: `pick` has no caller yet (no host code calls it), so no host setup is affected. The director tests cover the pick for every table size used in the rules: 0, 1 and 2+ totals (`one player`, `all-zero and empty totals`, and the lopsided/close/steady tests).
2. Kept state: `NightDirector` is const and holds only its two shares; no state starts or ends. The `pick` tests with the same seed (`the same seed gives the same pick`) show no hidden state.
3. Combinations: no UI and no pause, away, "Get ready", drop, results or leave path reads the director yet; the pure tests are the check.
4. Folder: changed only the three allowed files and this report.
5. Stop: none needed; no design decision was taken outside the brief except the solo-table choice, listed below.
6. Look: no UI in this job; not applicable.

## Decisions

- The one-player test expects `shapeEasy` with reason steady, not "same tier". With an easy and a hard variant in the pool and the last round at medium, the tier cannot stay at medium: both are one tier away and the tie goes to the easier. The test asserts what the rule gives. See question 1.
- The one-player guard is `totals.length < 2`, placed before the leader check, and replaces the old `isEmpty` guard (the empty case is still steady).
- `_aim` returns a record `(target, options)`: a local record type is used, not a new public type, so the file keeps one public type set as before (`DirectorReason`, `DirectorPick`, `NightDirector`).
- The new `DirectorInput` has no `==`/`hashCode`: it is only read by `pick`.

## Hand-over

- Files changed: `packages/party_host/lib/src/night/director_input.dart` (new), `packages/party_host/lib/src/night/night_director.dart`, `packages/party_host/test/night_director_test.dart`, `docs/briefs/m17/night2a/f1-report.md` (new). Nothing staged; no git command was run.
- `tools/mine.sh`: format ok (3 files), analyze `packages/party_host` clean, 18 tests pass. `tools/check.sh` was not run (the script runs it after this job).
- Test-file churn: the existing tests are unchanged except the `pick` call sites and the `_pickFor` body; the test count goes from 13 to 18.
- Open for the caption (B8): the reason code is not yet stored or shown.

## Questions

1. The brief's one-player case says "reason steady, same tier". With an easy and a hard variant and a medium last round, the pick cannot stay at medium, so the test expects shapeEasy. Confirm, or give a pool that contains medium.
2. A solo table is now steady, so a one-player night no longer raises a tier. This is the brief's decision; confirm it stands.

## Suggestions

- The lopsided branch of `_aim` still lists the kind variants with a loop; a `where` would read the same, but the file's style uses loops, so it was left as is.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

night director: DirectorInput, one-player steady, four rule tests

Pick takes a DirectorInput (pool, played, totals, min, max) and a random: two
parameters, not six. A table of fewer than two totals is steady, so a solo
night no longer raises a tier. Five director tests cover the rules the review
found untested (rule b, rule d, the one-tier ease and raise, one player); each
fails when its rule is removed. pick is split into options, aim and reason
helpers, and each DirectorReason value has a dartdoc.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2a f1 (director): done: DirectorInput, one-player steady, 5 new director tests each failing without its rule, pick split, reason docs; mine.sh OK (18 tests). Open: confirm solo-table steady and the one-player "same tier" wording (questions 1-2); B8 caption not wired.

## Delete

- none
