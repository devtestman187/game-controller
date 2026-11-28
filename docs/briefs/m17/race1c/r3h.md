job: race1c r3h — golden slot fixes: input object, no claim on a wrong re-snap, gap rename
stop: no new rule beyond these three; no UI, no wire; do not touch present_rules.dart or party_host
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/golden_slot.dart:1-139 · puzzle_points.dart:36-60 · match.dart:170-235 (golden hook, stepBoards call) · test/golden_slot_test.dart · REVIEW.md findings: update has 8 parameters (cap 5); claim runs on a wrong re-snap (base is wrongSnap); gapS means 10.0 here and 15.0 in present_rules.dart. Owner suggestion for Q2: "no; only a correct snap claims."
changes: GoldenSlot.update (parameters) · GoldenInputs (new value object, in golden_slot.dart) · GoldenSlot.gapS (renamed glowGapS) · PuzzlePointsRules._awardSnap (claim only when not again) · GoldenSlot.slot · GoldenSlot.claimedBy (read-only getters over private fields)
model: haiku
turns: 60
expected-min: 30
tests-first: the re-snap test must fail on the base (a wrong re-snap on the glowing target pays double there); run it first
do:
1 golden_slot.dart: group openLeft, openRight, placedLeft, placedRight into a `GoldenInputs` value object; `update(dt, {required enabled, required inputs})` has at most 3 parameters; drop `random:` from update (the held `_random` is used). Update match.dart's call. Make `slot` and `claimedBy` read-only getters over private fields. Rename `gapS` to `glowGapS` and say in its doc that it is the golden gap, not the present's. Rewrap the doc line over 120 columns at :38.
2 puzzle_points.dart `_awardSnap`: the golden claim only runs when the snap is not a try-again (`again` false); a wrong re-snap pays its normal points and does not use the slot.
3 Tests in golden_slot_test.dart (new cases first, then fix existing call sites): a re-snap on the glowing target pays 2 and leaves the slot glowing; a first-try snap there pays 4. Add the one-board case expecting normal points, and rename the Chaos-off test honestly.
4 Before finishing run `dart analyze` on your changed files and fix every info.
allow: packages/puzzle_game/lib/src/golden_slot.dart · packages/puzzle_game/lib/src/puzzle_points.dart · packages/puzzle_game/lib/src/match.dart · packages/puzzle_game/test/golden_slot_test.dart
check: format analyze
report: docs/briefs/m17/race1c/r3h-report.md
