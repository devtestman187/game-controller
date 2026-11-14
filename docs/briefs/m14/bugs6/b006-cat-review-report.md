# b006-cat — review

## Summary

Verdict: **needs Claude** (the PRD text and the skipped-visit rule are the designer's call; the code itself is green).
Counts: 0 must, 5 should, 5 could.
1. `cat_chaos.dart:210`: a planned visit is thrown away when the side ahead is the side just visited, so the owner's 8 minute round sees about 8 of its 16 visits, not 16.
2. `cat_chaos.dart:261`: the live `settings.chaos == Chaos.party` check was deleted from `_mayKnock`; after a mid-round switch Party → A little the cat still knocks, and no test covers it.
3. `docs/PRD-v2.md:169,762` still say at most once/twice a round, and `party-night.md:68` still says "the PRD's rules stand as written" while line 72 contradicts it.
4. Also: the plan leaves only `visitS` between visits, not `visitS + minQuietS` as `cat_tuning.dart` and `cat_tuning_test.dart:66` claim, and `party-night.md:72`'s "one visit at least in a round" is false for a 30–39 s round (the settings allow 30 s).
Checked: format clean, `flutter analyze` clean in puzzle_game and party_host, `cat_tuning_test` + `settings_test` 12 tests PASS, `cat_test` 18 PASS, `puzzle_settings_test` 2 PASS.

## Findings

- **should** `packages/puzzle_game/lib/src/cat_chaos.dart:210` `_start` consumes `_next` and returns when `_leader()` finds only the side last visited, so with one side ahead alone every second visit is lost (a 2–1 lead sees about 8 of the 16 planned at 480 s) → visit the other side when the leader is the side just visited, or requeue the visit, so "never the same side twice" costs no visit.
- **should** `packages/puzzle_game/lib/src/cat_chaos.dart:261` `_mayKnock` no longer checks `settings.chaos == Chaos.party` (the old code did), and `_knockBudget` is fixed at build, so a Chaos change from Party to A little during a round still lets a placed piece be knocked → keep the live chaos check in `_mayKnock` and add a test that switches chaos mid-round.
- **should** `docs/PRD-v2.md:169` G3 still says "at most once a round / at most twice a round" and line 762 the same, so the source of truth contradicts the shipped counts (brief item 3) → paste the Blocked text from the report into G3 and line 762.
- **should** `packages/puzzle_game/lib/src/cat_chaos.dart:186` `room = share - CatRules.visitS` leaves no quiet, so two visits may start 4.8 s apart, while `cat_tuning.dart:13` and `cat_tuning_test.dart:66` say each visit gets 4.8 s plus `minQuietS` → use `share - CatRules.visitS - CatTuning.minQuietS` (the cap already guarantees share ≥ 9.8 s).
- **should** `docs/design/party-night.md:72` says "one visit at least in a round", but `_fit` returns 0 when the window is under 9.8 s, so a 30 s round (the time limit's minimum) and a 39 s one have no cat at all → say "one visit where the window fits one" here and in the Blocked PRD text, which repeats the same claim.
- **could** `packages/party_host/test/puzzle_settings_test.dart:42` tests `withCatPresetDefine` on its own; nothing fails if the three `withCatPresetDefine` calls are dropped from the notifier, so the define's wiring is untested → read the host's state once with the wrapper in place (or inject the define into the notifier) and assert `catPreset`.
- **could** `packages/puzzle_game/test/cat_tuning_test.dart:50` `lessThanOrEqualTo(floor(window / every) + 1)` holds by construction (`visits = max(1, that)`), so it never constrains the count → assert equality with `floor(window / every)` except where the cap bites, as the other tests do.
- **could** `packages/puzzle_game/lib/src/cat_tuning.dart:52` `table[preset] ?? lively` cannot be reached: the table holds every `CatPreset` and a test asserts it → drop the `??` so a missing preset is a null error, or say in the doc why the fallback stays.
- **could** `packages/party_host/lib/src/puzzle_settings_provider.dart:58` `reset()` sets `hostPuzzleDefaults` without `withCatPresetDefine`, so Reset drops a device test's `CAT_PRESET` → wrap the reset value too, or say in the doc that Reset clears the define.
- **could** `packages/puzzle_game/lib/src/cat_chaos.dart:181` the Cat setting is read only when the match is built, so changing it during a round has no effect, while `puzzle_settings_screen.dart:14-15` says a change counts in the next frame also in a running puzzle → re-plan when `settings.catPreset` or `timeLimitS` changes, or limit the screen's claim.

## Decisions to confirm

- `CatPreset` in `settings.dart` rather than `cat_tuning.dart` (import cycle): safe, but the enum and its table now live in different files — confirm before more presets arrive.
- A round under ~40 s now has no cat at all (30–39 s), where today's 40 s round had two overlapping ones; the time limit's minimum is 30 s, so a host can pick it.
- Knocks capped to visits, and the new "A longer round and a wilder cat bring it more often" line under the Cat row: neither was asked for; both are small and in the settings screen only.
- `withCatPresetDefine` puts a `kDebugMode` branch in party_host's `lib/`, where `SHARE_VIEW` is an app-level provider override; a debug build on a phone or TV always honours `CAT_PRESET` and the settings screen cannot win against it (Reset included).
- The skipped-visit rule (report Question 1) decides whether "16 visits at 8 minutes" is the promise or the plan.

## Could not check

- `git diff 342a76b..fac52d8`: git needs approval here; I read the current files and `docs/briefs/m14/bugs6/run-b006-cat.patch`, whose range also carries other jobs' hunks (`arena_night_test.dart`, `arena_touch_ready_test.dart`, `b002`), so I attributed only the files the report lists to b006.
- The full `tools/check.sh` counts (416 puzzle, 427 host): I ran the three affected test files only, not the whole suites.
- The CAT_PRESET define on a real device, and whether a host can reach Puzzle settings while a match runs (the only route is the Games screen, so the mid-round Chaos and Cat cases are latent today).

## Commit message

b006-cat review: scales with the round; three fixes named

Reviewed b006 against the guidelines, review rules and its brief: counts,
Cat setting, screen row, define and tests are in and green, and the PRD
was not amended. Found: a planned visit is lost when the side ahead was
just visited (about 8 of 16 at 8 minutes), `_mayKnock` lost its live
chaos check, the 5 s quiet between visits is claimed but not planned,
and party-night's "one visit at least" is false for a 30 s round.

## Status row

b006-cat reviewed: code green (format, analyze, 32 tests in the four affected files); open: PRD-v2 G3 and line 762 still say at most once/twice a round, the skipped-visit rule and the mid-round chaos check need Claude, and party-night §5 needs two wording fixes.

## Delete

- none
