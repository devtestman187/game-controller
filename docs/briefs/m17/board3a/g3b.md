job: board3a g3b — CityRules config + pure rule functions (placementBolts, draftStepsFor, tileBuildCost), tests first
stop: owner answer PENDING; defaults below are Fable-reviewed, build on them; no drive-cost field; no import from night/ or the host service; no edit outside allow:
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/city/board.dart:24-92
changes: CityRules · placementBolts · draftStepsFor · tileBuildCost
model: haiku
turns: 45
expected-min: 25
do:
1 Write packages/party_host/test/city/rules_test.dart FIRST (it fails until rules.dart exists). Tests read the CityRules config, never literals.
2 packages/party_host/lib/src/city/rules.dart: one const CityRules holding ALL values: tileCost 3, placementBolts [5,3,2,1] (places 1-4), lastGameMultiplier 2, saveBonus 2, buildCap 3, roadLength 8, draftStepsPerStop 2 (an "unlimited" value = roll to the road front), roadworks flag (kids preset: false). Use District, Board, Token, Bolts, Plaza from board.dart. No drive-cost field.
3 Pure functions: placementBolts(place, isLastGame), tileBuildCost(tiles), draftStepsFor(...). draftStepsFor is the ONLY place the draft rule lives.
4 One test per rule: tileCost, placement 5/3/2/1, last game x2, saveBonus, buildCap, roadLength, kids preset no roadworks, "driving on paved road costs 0 Bolts".
5 Late join test: token starts at the slowest district's position. Absent-token test: absent token holds still.
6 Draft tests: a follower on paved road rolls up to draftStepsPerStop tiles free; the unlimited value rolls to the road front.
7 Worked example (greedy: buy the max affordable up to buildCap; first place every round; 5 games): R1 +5 buy 1 (left 2); R2 +5=7 buy 2 (left 1); R3 +5=6 buy 2 (left 0); R4 +5=5 buy 1 (left 2); R5 +10=12 buy 3 (cap), tiles 9; tile 8 is reached in round 5. Last place with 2 Bolts takes Save +2 (Bolts 4) and drafts 2 tiles on paved road.
8 Pure Dart; no lib file over 300 lines; new dirs only.
9 Run dart format, dart analyze and flutter test by explicit path (never tools/mine.sh, it skips untracked folders). Fix every analyzer info.
allow: packages/party_host/lib/src/city/rules.dart · packages/party_host/test/city/rules_test.dart
check: format analyze host
report: docs/briefs/m17/board3a/g3b-report.md
