job: night2a d2c — the Variant model (game plus map or tier) and the pool filter
stop: pure Dart, no provider, no UI, no hook into the night (B8 wires it), no new setting; NightSettings is read, not changed
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_variant.dart (the old two-value NightVariant: leave it alone) · packages/party_host/lib/src/night/night_settings.dart:1-60 (pool, difficultyMin, difficultyMax) · packages/puzzle_game/lib/src/puzzle.dart:82-90 (Level) · plan, quoted (M17-proposals 1.6): "Shape Race tiers 3 variants; Arena Race maps 3; Arena Bumper Round maps 4: 10 variants from 2 games"; Race maps are playroom, block-castle, toy-factory; Bumper maps are pinball, block-castle, toy-factory, spinning-tops
changes: Variant · VariantGame · launchVariants · variantPool
probe: docs/briefs/m17/night2a/probe-d2c.patch
model: haiku
turns: 45
expected-min: 20
tests-first: exempt a new type: the test cannot compile on the base
do:
1 NEW packages/party_host/lib/src/night/variant.dart (under 150 lines). `enum VariantGame { shapeRace, arenaRace, bumperRound }`. `final class Variant` const with value equality and hashCode: `VariantGame game`, `Level tier`, `String? mapId` (null for shapeRace, a map id otherwise; assert). `String get id` = `<game.name>:<tier.name>` for shapeRace and `<game.name>:<mapId>` otherwise (for example `shapeRace:easy`, `bumperRound:pinball`). `bool get isKind => tier == Level.easy` (dartdoc: the director's kind variant; no co-op or catch-up variant exists yet, so the easiest tier stands in). toString is the id.
2 Same file: `List<Variant> launchVariants(Level Function(String mapId) tierOfMap)` returns exactly the 10 launch variants in this order: shapeRace easy, medium, hard; arenaRace playroom, block-castle, toy-factory; bumperRound pinball, block-castle, toy-factory, spinning-tops (a map variant's tier is `tierOfMap(mapId)`). `List<Variant> variantPool(Iterable<Variant> all, NightSettings settings)` keeps a variant when (settings.pool is empty, or contains its id, or contains its game.name) and its tier index is within difficultyMin..difficultyMax; the order is kept.
3 Tests: NEW packages/party_host/test/night_variant_test.dart, written and run first (import the src files directly; no widget): launchVariants gives 10 with the ids and order above; ids are unique; equality and hashCode; a shapeRace with a mapId or a map game without one asserts (expect throwsA(isA<AssertionError>())); variantPool with default settings and a tierOfMap that returns Level.medium keeps all 10; Kids settings (NightSettings.kids, easy..easy) keep only the easy variants; a pool of {'shapeRace'} keeps the 3 Shape Race variants; a pool of {'bumperRound:pinball'} keeps that one; difficulty medium..medium keeps only medium ones; an empty result is an empty list.
4 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/variant.dart · packages/party_host/test/night_variant_test.dart
check: format analyze
report: docs/briefs/m17/night2a/d2c-report.md
