# Wave 1 verdicts (driver)
- arena suite not run after the move - invalid: the runner's combined check ran it (run.log 22:55-22:59, green); d2a result 0
- d2a report no self-check lines - minor - code-health (report only)
- d2c unused mapId param in test helpers - minor - code-health
- d2c all-ten test asserts length only - minor - code-health
- dartdoc/schema 'uses' wording, two-sentence schema description - minor - code-health
- docs/levels.md file-format table lacks tier row - must but trivial - folded into d2b (allow already has docs/levels.md)
- decisions: isKids is equality with the preset (an edited Kids night is no longer capped): accepted, noted for owner; tier optional until d2b rates all five: d2b covers all five; isKind = easy tier: accepted default
# Run review verdicts (driver)
- M1-M4 director tests pass without their rule - must - f1
- M5 pick has six parameters - must - f1 (DirectorInput)
- M6 three public types in night_pickers.dart - must - f2 (split, file stays as re-export)
- S1 pick 52 lines, S3 line over 120, S4 DirectorReason docs - should - f1
- S2 tier table vs obstacle rule - owner question Q1; levels.md now says set by hand, owner confirms (trivial, done)
- S5 puzzle_screen.dart at 380 lines - minor - code-health (split before the next job touches it)
- S6 tier String vs Level - minor - code-health, B8 converts at the map boundary
- S7 tests-first proof only a compile failure - minor - lesson candidate
- Q4 one-player table steady - f1; Q5/Q6/Q7 keep as built
- could items: C wording "uses" fixed in levels.md; rest (toString removed in f1, pickers doc/test in f2) else code-health: report self-check lines, d2a Summary, hard-coded map ids in variant.dart (plan 1.6 content), isKind vs isKids naming, duplicated no-repeat rule, k1 tests-first not proved by runner
# Wave 3 verdicts (driver)
- night_director.dart:128 and test:127 over 120 columns - invalid: awk length shows no line over 120 in either file, and dart format is clean
- ten-draw pickers test passes on base - minor: pins behaviour that was already right (tests-first exempt in the brief); kept
- steady dartdoc - trivial, fixed by hand (names the close-but-cannot-rise case)
- NightDirector third public type in night_director.dart - minor - code-health (split with the DirectorInput move in B8)
- duplicate expect in pickers test (line 41) - trivial, removed by hand
- "eases one tier" test name - minor - code-health
