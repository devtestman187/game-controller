# B021 fix the solo card test — review

## Summary

small fixes

must 1 · should 2 · could 1

1. The new `isNot('pinball')` check is flaky: the night's Surprise me draws a random map, and 1 of my 7 runs of the
   file failed with `Expected: not 'pinball'` (`Round started: arena, bumper, Pinball`).
2. Cause: `setMap` saves the card's choice (`mapId`), while `game_screen.dart:203` excludes only `lastMapId` and
   the night's used maps from the draw.
3. The report's "computed value" `'playroom'` is one draw of that random (others seen: Block Castle, Toy Factory,
   Pinball), so the report hid the flake.
4. No review-rules part A self-check in the report, so its A1/A3 claims cannot be checked.

## Findings

- **must** packages/party_host/test/solo_arena_card_test.dart:65 the new `isNot('pinball')` check fails whenever the night's Surprise me draws the pinball map, because `setMap('pinball')` at line 42 saves the card's choice (`mapId`) and not `lastMapId`, the only saved id `game_screen.dart:203` excludes (1 run in 6 here failed: `Expected: not 'pinball'`) → also mark it used with `playedMap('pinball')`, as `arena_waiting_test.dart:125` does, so the round provably cannot play it.
- **should** docs/briefs/m14/bugs11/b021-fix-card-test-report.md:26 `mapId 'playroom'` is reported as the computed value but it is one draw of an unseeded `Random` (`game_screen.dart:88`), so the figure is not a property of the test → state the rule instead (a map other than the saved one) and name the random.
- **should** docs/briefs/m14/bugs11/b021-fix-card-test-report.md:12 the report has no review-rules part A self-check, so the claims about host setups (A1) and the shared helper's state (A2/A3) cannot be checked at all → add the five one-line answers, "not affected" where that is the answer.
- **could** packages/party_host/test/solo_arena_card_test.dart:51 the card checks on lines 51-52 would also pass with no saved map at all, so only the round's map can prove the saved map was ignored → make the round check deterministic (finding above) rather than hardening the card checks further.

## Decisions to confirm

- The brief's own item 1 (b021-fix-card-test.md:8) asks for exactly this assertion, so the flake is in the ask; Claude decides whether the fix may add `playedMap('pinball')` to the test's setup, which changes what the test's saved state means, or whether the night should exclude the card's saved map too.
- The worker's decision to apply `setMap` before the roster and after `pumpHost` is safe: the card reads the settings later, and the saved map never reaches the round through this path.

## Could not check

- The full host suite (466 tests) claimed in the report — only the one file was run here, six times.
- Whether the assertion fails for the bug it guards (the night starting on the saved map) — that needs a lib change no test-only diff can show.

## Commit message

Fix the flaky solo card map check

The solo card test's new mapId check read as pinball whenever the
night's Surprise me drew that map, because setMap saves the card's
choice and not the last played map, which is what the round excludes.
Mark the saved map as used so the check can only fail for its reason.
Report the random draw instead of one 'playroom' value.

## Status row

`b021-fix-card-test` review done: one must (flaky map check in solo_arena_card_test:65) and two should (report's
computed map value, missing part A self-check); open: the fix job.

## Delete

- none
