job: board3b g3d1 — bot profiles (child, adult) and the test runner for tools/sim
stop: no simulator, no night loop, no CSV; no file outside allow:; never tools/mine.sh
read: docs/briefs/templates/COMMON.md · docs/briefs/m17/board3b/sim-model.md (whole file, 35 lines) · tools/tests/proc-sweep-test.sh:1-12 (shell test style)
changes: BotProfile · LastPlaceChoice · childBot · adultBot · standardNormal (all new, tools/sim/bots.dart) · sim-test.sh (new)
model: haiku
turns: 35
expected-min: 20
tests-first: exempt new files only, nothing on the base to fail
do:
1 New tools/tests/sim-test.sh (style of proc-sweep-test.sh): cd to the repo root, for every tools/sim/*_test.dart run `dart run "$f"`, print PASS or FAIL per file, exit 1 on any failure and 1 when there is no such file.
2 New tools/sim/bots_test.dart: a plain Dart script (no package:test; `void main()` with a small `check(name, bool)` that prints and sets `exitCode = 1` on failure). Cases: same seed gives the same 20 performances; adultBot mean performance (2000 draws) is higher than childBot's; chooseLastPlace with canBuild false and no roadworks gives save; with roadworksAvailable true and a profile with roadworksChance 1 gives roadworks; with saveChance 1, canBuild true, roadworks unavailable gives save; with both chances 0 gives build; childBot never picks roadworks when roadworksAvailable is false (500 draws).
3 New tools/sim/bots.dart (imports dart:math only): `enum LastPlaceChoice { build, save, roadworks }`; `double standardNormal(Random r)` (Box-Muller); `final class BotProfile({name, skill, noise, saveChance, roadworksChance})` with `double performance(Random r)` = skill + noise * standardNormal(r) and `LastPlaceChoice chooseLastPlace(Random r, {required bool canBuild, required bool roadworksAvailable})`: if roadworksAvailable and r.nextDouble() < roadworksChance -> roadworks; else if !canBuild -> save; else if r.nextDouble() < saveChance -> save; else build. Doc comments on every public member. `const childBot = BotProfile(name: 'child', skill: 0.0, noise: 1.4, saveChance: 0.1, roadworksChance: 0.1)`; `const adultBot = BotProfile(name: 'adult', skill: 0.6, noise: 0.8, saveChance: 0.4, roadworksChance: 0.5)` (provisional guesses, say so in the doc).
4 Run `bash tools/tests/sim-test.sh`, `dart format tools/sim`, then `dart analyze tools/sim` and fix every info.
5 Report: the test output lines.
allow: tools/tests/sim-test.sh · tools/sim/bots.dart · tools/sim/bots_test.dart
check: format analyze tools
report: docs/briefs/m17/board3b/g3d1-report.md
