# d2c report: the Variant model and the pool filter

## Summary

Added the pure-Dart `Variant` model, the ten launch variants, and the pool filter. No provider, no UI, no hook into the night, no setting change. `NightSettings` and the old two-value `NightVariant` are read or untouched.

Files changed:
- `packages/party_host/lib/src/night/variant.dart` (new, about 70 lines): `VariantGame` enum; `Variant` (const, value equality, `id`, `isKind`, `toString` = id, assert that Shape Race has no map and the other games do); `launchVariants(tierOfMap)` returns the ten variants in the planned order; `variantPool(all, settings)` filters by pool (empty, variant id, or game name) and by tier index within `difficultyMin..difficultyMax`, keeping order. Map ids are two named constants (`_arenaRaceMapIds`, `_bumperRoundMapIds`) taken from plan 1.6.
- `packages/party_host/test/night_variant_test.dart` (new, written first): 14 cases across three groups (launchVariants, Variant, variantPool).

Test values computed for the expectations:
- Launch ids, in order: `shapeRace:easy, shapeRace:medium, shapeRace:hard, arenaRace:playroom, arenaRace:block-castle, arenaRace:toy-factory, bumperRound:pinball, bumperRound:block-castle, bumperRound:toy-factory, bumperRound:spinning-tops`. Ten unique ids.
- Default settings with every map medium: 10 kept.
- `NightSettings.kids` with every map easy: 8 kept (`shapeRace:easy` plus the seven map variants).
- Pool `{'shapeRace'}`: 3 kept (the three Shape Race tiers).
- Pool `{'bumperRound:pinball'}`: 1 kept.
- Difficulty medium..medium with every map medium: 8 kept (`shapeRace:medium` plus the seven map variants).
- Pool `{'no-such-game'}`: empty list.
- Shape Race with a map id and Arena Race without one: both throw `AssertionError`.

Decisions:
- `id` for Shape Race uses `tier.name`; for the map games it uses `mapId`. `mapId ?? tier.name` is written so no `!` is needed; the assert guarantees the null case is Shape Race only.
- The Kids test uses a `tierOfMap` returning easy for every map, so the "only easy variants" expectation has more than one kept variant to check.
- `mine.sh` reformatted `variant.dart` once after the first write (the assert moved onto one line, and one loop body was joined). The content is the formatter's output; no logic changed.

## Self-check (review-rules part A)

1. Host setups: not applicable. Pure Dart, no host, no UI; B8 wires it into the night.
2. Kept state: none. The types are const and stateless; `launchVariants` and `variantPool` build new lists each call.
3. Combination with the pause menu, away, "Get ready", dropped link, results, leaving: not applicable (no hook into the night).
4. Files: only the two `allow:` files and this report were written.
5. Stops: none; no file outside `allow:` needed a change.
6. Looks: not applicable (no UI).

## Checks

- `tools/mine.sh`: format (2 files formatted), analyze (1 package, no findings), touched tests: `OK 19 tests packages/party_host`. Result `ok`. The 19 is the count the script printed; my new file has 14 cases, so the script ran more than that file. I did not check which others.
- The "fails on the base" proof is the runner's job (probe-d2c.patch); I did not run it.

## Hand-over

- Nothing is wired; B8 is the next consumer of `launchVariants` and `variantPool`.
- `isKind` is `tier == Level.easy` as the brief says; no co-op or catch-up variant exists yet.

## Commit message

```
m17 d2c: Variant model, launch variants and pool filter

Adds the pure-Dart Variant model (game plus tier or map, with a stable
id and value equality), the ten launch variants from M17 plan 1.6, and
variantPool, which filters by the night's pool and difficulty range.
Nothing is wired into the night yet; B8 is the first consumer.
Tests are in a new file; NightSettings and NightVariant are unchanged.
```

## Status row

d2c done: `Variant`, `VariantGame`, `launchVariants` (ten launch variants) and `variantPool` (pool and difficulty filter) in `packages/party_host/lib/src/night/variant.dart`, with 14 tests in `night_variant_test.dart`. Open: no hook into the night (B8); `isKind` stands in on the easy tier until a co-op or catch-up variant exists.

## Delete

- none
