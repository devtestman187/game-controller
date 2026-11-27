# Verdicts (driver, after the run review)
- must night_save_test.dart:96 clear test proves no save - must - e0g
- should round-0 resume (night_save.dart:31) - must - e0g
- should roster change not saved (party_night.dart:65) - must - e0g
- should corrupt save silent / failed write unlogged - minor - code-health (brief said silent; log with LogSink when M15 hall of fame lands)
- should no version field, night_save.dart 187 lines, round-trip asserts thin, nightContainer unused, _JoinBody 9 params, isFull rename, all_looks helper - minor - code-health
- should n1d-report counts - trivial - fixed by hand
- could (12): fake_prefs doc fixed by hand; rest - minor - code-health; championsAmong not wired yet (second champion rule): wire with n1f/n1g (B4)
- Open questions 1,4,7,9,10: settled by e0g or code-health. 3,5,6,8: kept as built.
