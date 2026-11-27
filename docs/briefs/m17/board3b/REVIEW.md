# board3b review verdicts (wave reviews by Haiku; verified by the driver at the file lines)
## wave1 (g3d1s, 6 findings)
- seed-inequality test missing (bots_test.dart:52): must-ish, FIXED by hand (75fd... commit "wave1 review fixes").
- greedy with nothing pickable returned self (bots.dart:97): FIXED, now throws StateError, tested.
- tests-first proof is a compile failure for new files: invalid (tests-first exempt, new files only).
- doc line over 120 columns, dartdocs on check/main: FIXED. blockGap unit name: code-health.
## wave2 (g3d2, 1 must, 4 should, 3 could)
- Gate test vacuous (night_sim_test.dart:212): must, FIXED in g3g (rulesWith tileCost 1; the cap now binds in a 5-game night, 300 of 300 nights).
- Gate tile never binds at standard numbers: real fact, recorded in docs/briefs/m17/city/REPORT.md (proposal 3).
- midLeaders/midLast/firstPlazaGame/leaderReachedPlaza untested, roadworks cost 0 test weak: FIXED in g3g (cost 0 leaves more Bolts, 2328 vs 1986).
- midLeaders-equal-on-vs-off brief check: invalid (contradicts sim-model step 5; dropped correctly).
- File 379 lines, simulateNight 49 lines, main 147 lines, `rulesWith` takes tileCost too: code-health board3b / accepted.
## wave3 (g3d2b, 0 must, 6 should, 7 could): all code-health board3b (kids-cell test, night_games column, SimCell value object accepted, run_sim argument tests, file split, long comments).
## g3g review: same tools-suite selftest failures as every run (environment); no new finding read.
## Environment
- tools suite: run-stops, run-wave and run-wire2 selftests fail in the runner's check of every job (4 runs, same cases); run-wave-test passes alone on the base. Class environment. g3d1s, g3d2, g3d2b, g3g committed by hand with sim-test, dart analyze and dart format green (HAND-FIX events in run.log).
- Worker note: g3d1 first brief stale after the owner's roadworks answers (twice): briefs renamed g3d1r, g3d1s.
## Metrics (job-metrics) 
JOB          WORKER MODEL            TURNS IN   OUT   CACHE MINUTES WALL RESULT
g3d1         claude claude-haiku-5-5    17 30 12437  388843     1.1 10.4 5 (subtype=success, terminal_reason=completed)
g3d1r        claude claude-haiku-5-5    21 32 13444  442462     1.2    - no result (subtype=success, terminal_reason=completed)
g3d1s        claude claude-haiku-5-5    18 30 17205  444411     1.6 13.2 5 (subtype=success, terminal_reason=completed)
g3d2         claude claude-haiku-5-5    18 28 51546  754518     3.6  4.6 0 (subtype=success, terminal_reason=completed)
g3d2b        claude claude-haiku-5-5    42 64 52299 1992134     6.0  7.0 0 (subtype=success, terminal_reason=completed)
g3g          claude claude-haiku-5-5    30 46 23944  844875     4.8  5.5 0 (subtype=success, terminal_reason=completed)
wave1-review claude claude-haiku-5-5    19 18 12971  271912     1.1    - 0 (subtype=success, terminal_reason=completed)
wave2-review claude claude-haiku-5-5    19 24 28017  607654     2.3    - 0 (subtype=success, terminal_reason=completed)
wave3-review claude claude-haiku-5-5    21 24 38568  501629     3.0    - 0 (subtype=success, terminal_reason=completed)
agent-cost: not separable by agent in a mixed window; since 2026-11-27 00:00 total $11.99 (opus 4.26, sonnet 5.26, fable 1.88, haiku 0.59)
