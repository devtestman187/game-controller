# Review: b015-build

## Summary

Verdict: **small fixes**. 0 must, 2 should, 3 could. The commit does the brief: the two bugs6 `race` objects
pasted unchanged, both `notes` fixed, a 4-test file added, `four_maps_test` renamed, the two host picker tests
updated, `docs/levels.md:246` true, and both sheets re-rendered (block-castle.png shows the starts and the goal
pad). The test_game suite passes (226) and the two host test files pass (10); on the old maps the new file's only
failing line is `race_maps_test.dart:24` (`race`, isNotNull), which fits the report's message.

Most important: (1) `docs/design/party-night.md:165` and `docs/PRD-v2.md:173` still say the new maps have no
finish and the race is the Playroom's alone, and neither was in `allow:`; (2) `race_maps_test.dart:31` promises the
coin zones in its name and asserts none; (3) `race_maps_test.dart:42-44` prints the rule-book issues and `:49-54`
repeats `four_maps_test.dart:74-85`.

## Findings

- **should** docs/design/party-night.md:165 section 7b still says "The new maps are Bumper Round arenas, with no finish. The race stays on the Playroom (the only map with a `race` section)", which b015 makes false → mark the Nov 9 bullet as history and state the new set (the Playroom, Block Castle, Toy Factory) in a follow-up job that adds this file to its allow.
- **should** packages/test_game/test/race_maps_test.dart:31 the test name says "keep their Bumper Round starts and coin zones" but the body reads only `bumper` and `hasLength(bumperStarts)`, so no coin zone is checked → assert the coin zones (e.g. every zone non-empty) or drop "coin zones" from the name.
- **could** docs/PRD-v2.md:173 the G10 row still records "four new Bumper Round arenas … with no finish; the race stays on the Playroom", which the owner's Nov 14 "Routes look good" reverses → add a PRD edit to the same follow-up job.
- **could** packages/test_game/test/race_maps_test.dart:42-44 the `debugPrint` loop prints the issues and prints nothing on a pass, while `reason` only carries their count → put `issues.join('\n')` in the reason as `four_maps_test.dart:41` does and delete the loop.
- **could** packages/test_game/test/race_maps_test.dart:49-54 repeats `four_maps_test.dart:74-85` (pinball and spinning-tops are the race-null maps, both play the Bumper Round), and `:31-36` repeats `four_maps_test.dart:52` (four starts) → keep one home for each rule and limit this file to the race values and the rule book.

## Decisions to confirm

- Decision 3 (the kit's own test commands instead of `tools/level.sh`, which the sandbox refuses): the brief's KIT
  RULE says to STOP if the kit cannot do something; bugs6 set the same precedent for `check`. Confirm it counts,
  or the rule needs wording for a sandbox refusal.
- Decision 4 (the `phone` check rewrote `site/shots/*.png`, outside `allow:`, and the worker restored them with
  `git show HEAD:`): the tree shows no diff there now and `controller_app/test/support/site_shots.dart:89` proves
  the suite writes them. Confirm the write-and-restore is acceptable, or add `site/shots` to the allow.
- Decision 1 (the approved numbers live as constants in the test, not read from `docs/briefs/m14/bugs6/b015-routes/`):
  safe for the deletion, but the test is now the only machine-read record of the approval — worth a sentence in
  `docs/decisions.md` if that should outlive the bug.
- Which doc owns the follow-up: party-night §7b is the design text and PRD G10 is the spec; both are outside this
  job's allow, so the next brief must name them.

## Could not check

- The host and phone suite counts (447 and 464): I ran only the two changed host test files (10 pass) and the full
  test_game suite (226 pass); I did not run `packages/party_host`'s or `controller_app`'s full suites, nor the
  analyzer.
- `docs/design/maps/toy-factory.png`'s content: I read `block-castle.png` (starts and goal pad present) but not the
  Toy Factory sheet; the render test is a pure function of the map, so the bytes changed as the report says.
- That `tools/level.sh` is refused in the sandbox: I did not run it.
- That the Block Castle race can be won: `checkMap` ignores movers by default (the bugs6 review found this), so
  `race_maps_test.dart:39-47` does not prove the keep gate route; only a device play test does.

## Commit message

Review b015-build: race landed, two stale docs and test tidy-ups

Checked the b015 commit against the guidelines, review rules and its
brief: two maps with the approved race pasted unchanged, notes fixed,
a new race_maps_test, four_maps_test and the two host picker tests
updated, docs/levels.md corrected, both sheets re-rendered. No must.
Two should: party-night section 7b still says the new maps have no
finish (and PRD G10 repeats it), and race_maps_test's bumper test
names coin zones it never checks. Three could: the stale PRD row, a
debugPrint loop, and assertions repeated from four_maps_test.

## Status row

b015-build reviewed — race landed on Block Castle and Toy Factory with data, tests, docs and sheets, all tests I ran pass; open: party-night §7b and PRD G10 still say the new maps have no finish, the test-name and duplication tidy-ups, and the device check of the keep-gate finish.

## Delete

- none
