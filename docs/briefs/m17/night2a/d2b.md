job: night2a d2b — rate the five Arena maps (first rating, the owner confirms)
stop: no code change in lib, no bot run (none exists), no other map field; the ratings below are the default the owner confirms and are not yours to change
read: docs/briefs/templates/COMMON.md · packages/test_game/maps/index.json · packages/test_game/maps/playroom.json:1-12 (where "theme" is) · packages/test_game/lib/src/arena_map.dart (mapTiers, ArenaMap.tier, from d2a) · docs/levels.md:318-340 (the maps part of the guide) · packages/test_game/test/map_tier_test.dart (d2a's test) · plan, quoted (M17-dev-plan d2b): "Rate the 3 Race and 4 Bumper maps (first rating from a short bot run; P7 hardens it; owner confirms)". No Arena-map bot exists, so this first rating is by obstacle count (walls + 2 x hazards + 2 x movers + belts: playroom 13, pinball 10, toy-factory 12, spinning-tops 20, block-castle 30) and is provisional.
changes: mapRatings
model: haiku
turns: 35
expected-min: 15
tests-first: exempt data rating; the test pins the table and fails on the base because no map has a tier yet
do:
1 In each map file add `"tier": "<tier>"` on its own line right after "theme": playroom easy · pinball easy · toy-factory medium · spinning-tops medium · block-castle hard. Nothing else in the files changes.
2 docs/levels.md: add a `tier` row after the `theme` row of the file-format table (about line 235; optional, easy, medium or hard), and in the maps part add a short "Tier" paragraph (at most 8 lines): what the field is (easy, medium or hard, used by the night director to keep a night inside the host's difficulty range), the first rating by obstacle count with the five numbers above and the table of the five maps, "provisional: the owner confirms and the Arena-map bots harden it (M17 P7)", and that `tools/level.sh new map` starts a map at easy.
3 Tests: NEW packages/test_game/test/map_ratings_test.dart, written and run first: every id in maps/index.json loads (ArenaMap.parse of its file) with a tier in mapTiers; the table above is pinned exactly (a map's tier changes only on purpose); the tier counts are easy 2, medium 2, hard 1.
4 Before finishing run `dart analyze` on the test file and `tools/check.sh arena`.
allow: packages/test_game/maps/playroom.json · packages/test_game/maps/pinball.json · packages/test_game/maps/toy-factory.json · packages/test_game/maps/spinning-tops.json · packages/test_game/maps/block-castle.json · docs/levels.md · packages/test_game/test/map_ratings_test.dart
check: format arena
report: docs/briefs/m17/night2a/d2b-report.md
