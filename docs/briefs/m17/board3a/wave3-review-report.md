# board3a wave3 review: g3b (CityRules and pure rule functions)

## Summary

- Verdict: **needs Claude**
- Counts: must 3, should 5, could 1
- Three that matter most:
  1. `rules_test.dart:55`: the saveBonus test calls no lib code, so it checks arithmetic on a literal.
  2. `rules_test.dart:65-72`: the roadLength test checks a list it builds itself; no lib code runs.
  3. `rules_test.dart:59-63` and `:139-144`: no lib code enforces buildCap; the cap and the buy rule exist only inside the test.
- Brief items 4 (drive cost) and 5 (late join, absent token) have no tests; the worker stopped and said so, which is correct, but Claude must decide the owner.
- Guidelines checked and clean: layers (rules.dart has no Flutter or board import), file sizes (114 and 169 lines), function length, naming, dartdoc on every public member, no prints, TODOs or commented-out code, no magic numbers beyond the config.
- Worked example re-computed by hand: bought 1, 2, 2, 1, 3; left 2, 1, 0, 2, 3; tiles 9; tile 8 reached in round 5. The test's expected values match.

## Findings

- **must** packages/party_host/test/city/rules_test.dart:55 the saveBonus test asserts `2 + rules.saveBonus == 4` and calls no lib code, so it passes whatever the rules do; the Save line at :159 repeats it → call a lib function for the Save payout, or drop the check and say in the report that saveBonus is untested.
- **must** packages/party_host/test/city/rules_test.dart:65-72 the roadLength test builds its own list of roadLength tiles and asserts that list's length and last element, so no lib code runs and no rule can fail it → test a lib function that reads roadLength, or remove the test.
- **must** packages/party_host/test/city/rules_test.dart:59-63 the buildCap test only asserts the value is above 0, and no lib code enforces the cap, so no test fails if the cap is ignored → add a lib function that caps the purchase (for example `tilesBuyable`) with tests at buildCap and buildCap + 1.
- **should** packages/party_host/test/city/rules_test.dart:139-144 the worked example's buy rule (affordable count, then min with buildCap) is written in the test, so the test checks its own arithmetic rather than lib → move that rule into lib together with the fix for the buildCap finding, and call it from the test.
- **should** packages/party_host/lib/src/city/rules.dart:107 a negative tilesToFront silently returns 0, while the other two functions throw ArgumentError for bad input (line 92, line 104), and no Decisions entry in the report says so → throw ArgumentError for tilesToFront below 0 and list it in the report.
- **should** packages/party_host/lib/src/city/rules.dart:37-46 the kids preset repeats all eight standard values, so a later change to standard leaves kids stale, though line 36 says kids is "the standard game with no roadworks" → define kids as standard with roadworks false, written once.
- **should** docs/briefs/m17/board3a/g3b.md:12-13 brief items 4 (the driving-cost test) and 5 (late join, absent token) have no tests; the worker stopped and reported them, but the brief still asks for them → Claude names the owning function, then a later job builds and tests them.
- **should** docs/briefs/m17/board3a/g3b-report.md:67 the report says it ran tools/mine.sh "as the task instructs", but g3b.md:17 says never run it, so the 20-test count rests on a check the brief forbade → note the deviation; if Claude needs the count, rerun by explicit path.
- **could** packages/party_host/lib/src/city/rules.dart:22 the unlimited draft is `-1` in an int field, a magic sentinel that a nullable int or an explicit flag would avoid (guidelines §2, special cases modelled as a number) → Claude decides whether to replace it; keep it if the brief's wording needs a number.

## Decisions to confirm

- `rules.dart:10-19` `CityRules` has eight named parameters, over the five-parameter limit in guidelines §3; it is the value object that rule asks for, so accepted unless Claude wants a split.
- `rules.dart:103` `draftStepsFor` takes `draftStepsPerStop` as a plain int, not the rules object; the draft rule stays in one place, but each caller must pass the right value.
- `rules.dart:1-4` no import from `board.dart`, though brief item 2 named its types; nothing in `rules.dart` needs them (g3b-report decision 5). Confirm the brief's intent.
- `rules.dart:78-84` `placementBolts` returns 0 past place 4 instead of throwing (g3b-report decision 3); confirm a place past the table is a normal case.
- `rules_test.dart:150-153` the worked-example expectations are literals, against the brief's "tests read the config, never literals"; the owner's numbers are the spec. Confirm this exception.

## Could not check

- Test results: no `run-findings.md` exists, so there is no runner evidence; this is a read-only job and I ran no tests.
- Whether the 20 tests compile: the `Tile`, `Plaza` and `District` constructors in `board.dart` (used at `rules_test.dart:67-68`) were not read.
- Whether `rules_test.dart` fails on the code as it was (with `rules.dart` absent): not measured.
- Whether `tools/check.sh host` and `dart analyze` are clean: not run.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
m17 board3a: wave3 review of g3b (findings only)

Adds docs/briefs/m17/board3a/wave3-review-report.md with the review of
the g3b job (CityRules, placementBolts, tileBuildCost, draftStepsFor).
Verdict: needs Claude. Three must findings: the saveBonus, roadLength
and buildCap tests assert nothing about lib code. No code is changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

wave3 review of g3b done: needs Claude (3 must, 5 should, 1 could); open: saveBonus, roadLength and buildCap tests assert nothing and the buy rule lives in the test; late join, absent token and drive cost not built.

## Delete

- none
