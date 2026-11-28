# Verdicts (driver, Nov 27)
- present_wiring_test.dart:91 no-present test compares plain with plain - minor (it still pins a deterministic render; the positive tests at :80-89 carry the proof) - code-health
- present_match_test.dart:54 no Little+Lively positive - invalid (the test at :43 covers Little+Lively and Party+Calm)
- match_painter.dart:193 no phone-size test - must - f2
- old-peer tests missing (helper claim) - invalid (present_snapshot_test.dart has 'zz' unknown-key and 'pr'-removed cases)
- should/could items (bare 0.5, dartdoc, 6-param _fuse, line length, job-letter comments, no pause tests, stale r3d-report names) - minor - docs/code-health.md
