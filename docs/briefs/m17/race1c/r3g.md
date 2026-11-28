job: race1c r3g — fuse parameters in one place in settings.dart (PROVISIONAL) and a skill-bot fuse test
stop: no value change (20 s, 12 s, 1.5 s, 4 s stay), no new setting field, no UI; the values lock only after the kid playtest on Nov 28 2026
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/present_rules.dart:1-129 · settings.dart:1-20 · tools/sim/bots.dart:20-60 and :100-128 (BotProfile, childBot, adultBot; imports dart:math only) · test/present_rules_test.dart (names the constants today) · owner (Nov 27): "build with the provisional 20/12/1.5/4 held as named constants in one place in settings.dart, clearly marked provisional; they lock after the kid playtest"
changes: FuseParams (new, settings.dart) · PresentRules.startDelayS · PresentRules.startFuseMs · PresentRules.snapCutMs · PresentRules.minFuseMs (the four become aliases of FuseParams)
model: haiku
turns: 60
expected-min: 30
tests-first: exempt move of constants; the bot test pins behaviour already correct on the base
do:
1 settings.dart: add `abstract final class FuseParams` with `startDelayS = 20.0`, `startFuseMs = 12000`, `snapCutMs = 1500`, `minFuseMs = 4000`, each doc-commented "PROVISIONAL: locks after the kid playtest (Nov 28 2026)". present_rules.dart: the four constants become `static const x = FuseParams.x;` (same names, so tests and other code stay). popMs and gapS stay where they are.
2 New test packages/puzzle_game/test/fuse_skill_test.dart (flutter test): import `../../../tools/sim/bots.dart` (childBot, adultBot) and drive a real PresentRules (onSnap, update) with a bot that snaps at a pace set by `performance` (document the rule in the test), over many fixed-seed presents. Every number compared against is read from FuseParams: never write 20, 12000, 1500 or 4000 in the test. Check: the fuse after k snaps is never under minFuseMs; a present nobody bats survives the start fuse; a child bot (skill 0) still gets at least one bat in on average; an adult bot makes more bats per present than a child. If the import of tools/sim/bots.dart fails under flutter test, stop and say so in the report.
3 Existing tests naming the four constants (present_rules_test.dart etc.) must pass unchanged.
4 Before finishing run `dart analyze` on your changed files and fix every info.
allow: packages/puzzle_game/test/present_match_test.dart · packages/puzzle_game/lib/src/settings.dart · packages/puzzle_game/lib/src/present_rules.dart · packages/puzzle_game/test/fuse_skill_test.dart · packages/puzzle_game/test/present_rules_test.dart
check: format analyze
report: docs/briefs/m17/race1c/r3g-report.md
