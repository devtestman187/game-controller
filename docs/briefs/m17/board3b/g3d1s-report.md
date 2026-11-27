# board3b g3d1s: bot profiles (child, adult) and the sim test runner

## Summary
- New `tools/sim/bots.dart`: `LastPlaceChoice`, `RoadworksPickPolicy`, `standardNormal` (Box-Muller), `BotProfile` with `performance`, `chooseLastPlace` and `chooseRoadworksTarget`, and the `childBot` and `adultBot` constants. The numbers of both bots are provisional guesses and say so in their doc comments.
- New `tools/sim/bots_test.dart`: a plain Dart script with `check(name, bool)`. It prints PASS or FAIL per check and sets `exitCode = 1` on failure.
- New `tools/tests/sim-test.sh`: runs `dart run` on every `tools/sim/*_test.dart`, prints the output and a PASS or FAIL line per file, exits 1 on any failure and when there is no such file.
- `dart format tools/sim` changed both new Dart files; `dart analyze tools/sim`: No issues found.
- Tests-first: exempt, new files only, nothing on the base to fail.

## Test output (`bash tools/tests/sim-test.sh`)
```
PASS same seed gives the same 20 performances
PASS adult mean 0.590 is higher than child mean -0.018
PASS cannot build and no roadworks gives save
PASS roadworks available with roadworksChance 1 gives roadworks
PASS saveChance 1, can build, roadworks unavailable gives save
PASS saveChance 0 and roadworksChance 0 gives build
PASS childBot never picks roadworks when unavailable (0 in 500 draws)
PASS greedy, leader gap 2 (block gap 2) blocks the leader, gives 3
PASS greedy, leader gap 1 with own road available works own road, gives 0
PASS greedy, own road unavailable gives 3 at every gap (0, 1, 2, 5)
PASS greedy, no rivals gives own road 0
PASS random, own available: picks 0, 3 and 1 and nothing else (seen [0, 1, 3])
PASS random, own unavailable: never picks 0 (seen [1, 3])
bots_test: all checks passed
PASS tools/sim/bots_test.dart
```

## Values computed for expectations
- Seed 42, 2000 draws each: adult mean performance 0.590 (skill 0.6); child mean -0.018 (skill 0.0). Adult is higher.
- Same seed (42, adult), 20 performances: two runs give identical lists.
- Greedy adult, self 0, rivals [3, 1, 2]: leader gap 2 gives 3 (gap reaches blockGap 2); gap 1 with own road available gives 0; own road unavailable gives 3 at gaps 0, 1, 2 and 5; no rivals gives 0.
- Random child, self 0, rivals [3, 1], own available, 300 draws: seen {0, 1, 3}. Own unavailable, 300 draws: seen {1, 3}, never 0.
- Child with Roadworks unavailable, 500 draws: 0 Roadworks picks.

## Self-check (docs/review-rules.md part A)
1. Host setups: not applicable. The job adds pure Dart profiles and a test runner; no host UI or setup is touched.
2. Kept state: none. The profiles are `const`, the test functions hold their state in locals and in `_failed` for the final line.
3. Combination with pause, away, Get ready, dropped link, results, leaving: not applicable (no game state).
4. Stayed in the allowed files: `tools/sim/bots.dart`, `tools/sim/bots_test.dart`, `tools/tests/sim-test.sh`, and this report.
5. Nothing stopped; no file outside `allow:` was changed.
6. Looks: not applicable (no UI).

## Decisions
- `chooseLastPlace` and `chooseRoadworksTarget` are members of `BotProfile`, because they read `roadworksChance`, `saveChance`, `pickPolicy` and `blockGap`. The brief lists them without a receiver; sim-model.md calls them as `profile.chooseLastPlace(...)`.
- Greedy with no rivals and own road unavailable returns `self`, as the brief says. The caller must guarantee one pickable road (sim-model.md step 4a). `randomAny` with no option at all would throw from `nextInt(0)`; the doc comment states the guarantee.
- The bot-number doc comments say "provisional guesses (not measured)".
- `sim-test.sh` prints each file's full output, not only the PASS or FAIL line, so a failure can be read in place.

## Hand-over
- Not run: `tools/mine.sh`. The brief's `stop:` line says never run it, while the task text says to check with `tools/mine.sh`. I followed the brief. See the questions.
- Not run: `tools/check.sh` (as instructed).

## Questions
1. The brief says "never tools/mine.sh", but the task text says to check with `tools/mine.sh`. I did not run it; tell me which one holds, and whether the churn revert in mine.sh is a risk for these new files.
2. Are the bot numbers (child skill 0 / noise 1.4 / save 10% / Roadworks 10%; adult skill 0.6 / noise 0.8 / save 40% / Roadworks 50% / block gap 2) right, or do they need the owner's numbers?
3. `chooseRoadworksTarget` returns `self` for greedy when the own road is unavailable and there are no rivals. Should it throw instead, to catch a caller bug?

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.
m17 board3b: bot profiles for the night sim and a sim test runner

Adds tools/sim/bots.dart with BotProfile (performance, chooseLastPlace,
chooseRoadworksTarget), the greedy and random Roadworks pick policies,
and the provisional childBot and adultBot profiles.
Adds tools/sim/bots_test.dart (plain Dart checks, exit 1 on failure)
and tools/tests/sim-test.sh, which runs every tools/sim/*_test.dart.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.
g3d1s done: bot profiles childBot/adultBot and the pick policies, with plain Dart checks and sim-test.sh (all pass); open: bot numbers are provisional, owner to confirm; tools/mine.sh not run (brief conflict).

## Delete
- none
