# wave 1 verdicts (Claude)
- must gateTileIndex still in rules.dart (verified by grep) - must - g3h item 1 (done)
- must rules_test.dart:161 gate tile test tests a local value - must - g3h (done)
- should forPlayers chained re-pricing - must (cheap trap) - g3h (done)
- could literal pins (cap 3, 5 games) - minor - kept as config pins
- could 15-field CityRules copy in three places - minor - docs/code-health.md
- could forPlayers test misses two fields - trivial - g3h (done)
- could g3r1-report line 17 says tests moved - trivial - fixed by hand
- decision nextTileGated default false - accepted (brief asked; no caller yet)
- decision gateTargets does not exclude a gated rival - accepted (gateOffered guards the call); note for the gate-game job
- process: workers ran tools/mine.sh despite the stop line - invalid (COMMON.md governs)
- later: placeGate/openGate pause, away, reconnect cases untested - next job (M17b gate-game wiring)

# run review verdicts (Claude)
- must rules_test:65/69 chains pass on old code - must - g3h2
- must matrix prices every cell by road variant (sim_report:195) - invalid as a bug: the v2 matrix is the research grid of road variants V0-V3 at every player count; the owner's final rule (V0 price at 2-4, V2 at 5-8) is the matching cells; SimRules.forNight now builds the exact owner night. No rerun. Listed as an assumption in the report.
- must night_sim_test gate-game check passes on the old formula - must - g3h3
- should cityRulesWith tileCostSmallNight, gate-blocks test, header, wrap - g3h3
- should adapter gap test, decider points - g3h2 (accept the City Rush chain only; doc)
- should two public types in night_adapter.dart - minor, exception accepted (adapter pair), docs/code-health.md
- should report text findings (g3m 13 tests, format line, g3h counts, g3n 77) - trivial - fixed by hand
- should board-gate literals; could wc count, content from HEAD, test cases - g3h4
- could dev-tools.md row, 'place' constant, sim_report 423 lines, base=m17 default - minor - docs/code-health.md

# wave 4 verdicts (Claude)
- should night_adapter doc-only guard for a points chain - minor, accepted (no caller passes another chain; docs/code-health.md)
- should night_sim.dart:6 "marked in the stop" - trivial - fixed by hand (the gate before the stop's Builds is an owner rule)
- should g3h3-report mechanism text, count of long lines - trivial - fixed by hand
- should tileCostSmallNight change affects matrix prices - invalid: the matrix never calls forPlayers; cityRulesWith still sets tileCost; no matrix row changes
- should g3h2 ran mine.sh against its stop line - invalid (COMMON.md governs)
- decisions (gate-blocks proxy check, deleted paths skip, default base m17) - accepted
