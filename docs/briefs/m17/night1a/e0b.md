job: night1a e0b — the champion chain as a pure Champion type (ordered tie-break steps ending in shared)
stop: no wiring into night_state.dart, the scoreboard or the ceremony; no Plaza or Bolts data source (the type takes numbers)
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_state.dart:268-300 (rows: most points wins, ties share a place) · plan, quoted: "Quick night champion is most points; tied players share the win (today's behaviour). City Rush: closest to the Plaza, then Bolts, then shared." The owner's other option, "best place in the last game breaks a tie", must be one added step.
changes: ChampionStep · ChampionEntry · ChampionChain
probe: docs/briefs/m17/night1a/probe-e0b.patch
model: haiku
turns: 35
expected-min: 20
do:
1 New packages/party_host/lib/src/night/champion.dart (under 200 lines, pure Dart). `enum ChampionStep { points, plazaDistance, bolts, lastGamePlace, shared }`: points = most wins, plazaDistance = least wins, bolts = most wins, lastGamePlace = least wins (1 is best), shared = terminal (everyone still level shares the win). `final class ChampionEntry { String id; int points; int? plazaDistance; int? bolts; int? lastGamePlace }` (const). A null value on a step is the worst for that step. `final class ChampionChain`: const constructor taking `List<ChampionStep> steps`, asserts: not empty, `shared` last and only there. Static finals `quickNight` = [points, shared] and `cityRush` = [plazaDistance, bolts, shared]. `Set<String> champions(Iterable<ChampionEntry>)`: start with all entries; for each step before shared keep only the entries best on it; stop early when one is left; what remains is the champion set (a shared win). Empty input gives an empty set.
2 Doc comment on ChampionChain: "Where the owner's other option goes: 'best place in the last game breaks a tie' is one added step, quickNight = [points, lastGamePlace, shared]."
3 Tests: NEW packages/party_host/test/champion_test.dart, one test per step: quickNight with a single leader; a points tie shares the win (today's rule); cityRush picks least plazaDistance; a plaza tie falls to most bolts; a bolts tie shares; null plazaDistance loses to any number; lastGamePlace as an added step breaks a points tie ([points, lastGamePlace, shared]); the constructor asserts (shared not last, empty). Plus one pin that quickNight equals NightState.rows place 1: find one existing test under packages/party_host/test that builds a NightState and calls `.rows(` (grep), follow it for 3 players with a tie for first, and compare the place-1 ids with quickNight.champions.
4 Report: the final constructors, and where the extra step goes.
5 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/champion.dart · packages/party_host/test/champion_test.dart
check: format analyze party_host
report: docs/briefs/m17/night1a/e0b-report.md
