# Review of wave2 d2b (first Arena map tiers), read-only

## Summary

Verdict: needs Claude
Counts: must 0 · should 2 · could 2 · decisions to confirm 3
Obstacle counts recomputed from the five map files: playroom 13, pinball 10, toy-factory 12, spinning-tops 20, block-castle 30. They match the brief and the docs.
1. The table breaks its own rule: playroom (13) is easy while toy-factory (12) is medium, so no single obstacle-count cut-off gives these ratings.
2. The worker's test run does not show the arena suite passed: playroom_test.dart (the repair target) and map_tier_test.dart were not in the tests mine.sh selects.
3. The worker's "OK 4 tests" cannot be matched to the three tests in map_ratings_test.dart; the fourth is not named.

## Findings

- **should** docs/levels.md:336 The Tier paragraph says the first rating is "by obstacle count", but playroom (13) is easy and toy-factory (12) is medium, so the table contradicts the stated rule → state the cut-off the owner confirms, or re-rate, then fix the paragraph and the Tier row at docs/levels.md:341 to match.
- **should** docs/briefs/m17/night2a/d2b-report.md:12 "OK 4 tests" and :19 self-check 3 cite playroom_test.dart as proof; tools/mine.sh:224-243 runs only touched tests and tests whose text names the touched lib file's basename (`arena_map.dart`), and playroom_test.dart is neither touched nor contains that name, so its tests (playroom_test.dart:20-21, the repair target) and map_tier_test.dart were not shown to pass → run `tools/check.sh arena` as brief step 5 asks and record its result in the report.
- **could** packages/test_game/test/map_ratings_test.dart:32-33 the count test ('the ratings count easy 2, medium 2, hard 1') derives from the same five ratings as the table test at :25-26 and fails for the same reason → keep it, since brief item 3 asks for it, or fold its counts into the table test.
- **could** docs/briefs/m17/night2a/d2b-report.md:33 Question 3 says `run.log` was already modified before the job; the start-of-session status lists only `DRIVER-NOTES.md` → drop the `run.log` mention, or name the status it came from.

## Decisions to confirm

- The ratings and the cut-off: playroom 13 easy, toy-factory 12 medium and pinball 10 easy do not fit one count cut-off. The owner confirms the five ratings and where easy ends; until then the Tier paragraph's rule is wrong for the table.
- The worker ran `tools/mine.sh` in place of the brief's `tools/check.sh arena` (and `puzzle` from the check list), citing the worker rules. Nobody has run the arena suite as the brief asked (see Findings).
- `tools/level.sh new map` starting at easy (docs/levels.md:343) is true because `maps/_template.json:9` has `"tier": "easy"` and `tools/level_new.dart:127-149` copies the template; this is a choice that the template stays easy.

## Could not check

- The arena suite result: not run. Running the tests can redraw `docs/design/maps/`, which is outside `allow:`, so the reviewer ran nothing.
- The fourth test in "OK 4 tests": the report does not name it; it may be in `arena_hud_map_test.dart` or `coverage_all_test.dart`, which name `arena_map.dart` (git grep), but I did not read them.
- The tests-first claim (first ratings `contains <null>`, table `{'none': 5}`): not re-run on the base.
- Whether `tools/level.sh check` refuses a bad tier: I read the parser (`packages/test_game/lib/src/arena_map.dart:211-212`) and the schema (`packages/test_game/maps/map.schema.json:43-45`) only.
- `docs/briefs/m17/night2a/run-findings.md`: a search for d2b, tier, map_ratings and "passes on the old" found no entry about this job.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

Review of wave2 d2b (Arena map tiers): findings only

Read-only review of the first tier rating of the five Arena maps. No code or
document changed. Findings for Claude: the tier table breaks its own
obstacle-count rule (playroom 13 easy, toy-factory 12 medium), and the arena
suite (playroom_test, map_tier_test) was not run by the worker. The owner
confirms the cut-off and the ratings.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M17 d2b review: done, needs Claude. Open: tier cut-off (playroom 13 easy vs toy-factory 12 medium), tools/check.sh arena not run by the worker, owner confirms the ratings (P7 hardens them).

## Delete

- none
