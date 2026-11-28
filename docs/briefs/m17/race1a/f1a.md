job: race1a f1a — MatchFormat for 3v3, 4v4 and uneven sides, with right labels
stop: no join, side-panel or settings change; the 1v1, 2v1, 2v2, solo and team results stay as they are
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/match.dart:18-50 (MatchFormat) · packages/party_host/lib/src/text/host_text.dart:86-94 (formatName, no default) · packages/puzzle_game/test/match_test.dart:1-40 and :350-370 · packages/puzzle_game/test/match_round_test.dart:30-50 · packages/party_host/test/host_text_test.dart:15-35 · owner plan: "MatchFormat for 3v3 and 4v4 with right labels, no 2 vs 1 mislabel"
changes: MatchFormat.threeVsThree · MatchFormat.fourVsFour · MatchFormat.uneven
model: haiku
turns: 40
expected-min: 20
tests-first: exempt none; the new cases in match_test.dart fail on the base (3v3 gives twoVsOne); run them first
do:
1 match.dart: add enum values threeVsThree('3v3'), fourVsFour('4v4'), uneven('uneven'). `of`: 3 and 3 gives threeVsThree, 4 and 4 gives fourVsFour, 2 and 1 (either order) stays twoVsOne, any other unequal split (3v1, 3v2, 4v1, 4v2, 4v3 ...) gives uneven; 1v1 and 2v2 as now. Fix the doc comment "at most two players" to "up to four". `split` stays true for them.
2 host_text.dart formatName: arms '3 vs 3', '4 vs 4', 'uneven sides'. The file is at the size gate: do not make it longer than now (shorten a nearby comment if you add lines).
3 Tests first: match_test.dart cases for each split 3v3, 4v4, 3v2, 4v1 and the unchanged ones; host_text_test.dart the three names. Fix any test the change breaks.
4 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/puzzle_game/lib/src/match.dart · packages/party_host/lib/src/text/host_text.dart · packages/puzzle_game/test/match_test.dart · packages/puzzle_game/test/match_round_test.dart · packages/party_host/test/host_text_test.dart
check: format analyze
report: docs/briefs/m17/race1a/f1a-report.md
