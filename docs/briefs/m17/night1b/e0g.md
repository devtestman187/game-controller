job: night1b e0g — fix the night save: a never-played night is not resumed, a roster change is saved, the clear-on-end test proves a save existed
stop: no new save fields, no version field, no logging, no file split; only these three fixes
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_save.dart:20-45 (load, save, clear) · packages/party_host/lib/src/night/party_night.dart:55-125 (build, the roster listener at about :65, _set, dropIfUnplayed at :116-118: B-032 drops a night with round 0) · packages/party_host/test/night_save_test.dart:85-110 · review findings, quoted: "a night started but never played (round 0) is resumed after a restart, against B-032"; "the roster listener sets state directly, so the entries remember adds are not saved"; "the 'ending the night clears the save' test ... never asserts a save exists before end()".
changes: NightSave.load · PartyNight.build
model: haiku
turns: 35
expected-min: 20
tests-first: exempt the roster-save and clear-test fixes are test-side; the round-0 test fails on the base
do:
1 night_save.dart `load()`: a saved night with `round == 0` is cleared and null is returned (a night nobody played does not come back, as dropIfUnplayed does).
2 party_night.dart: the gamePlayersProvider listener saves what `remember` adds: use the class's `_set(night.remember(players))` (keep its null and over handling) instead of assigning `state` directly.
3 night_save_test.dart: (a) split the cascade in the "ending the night clears the save" test so `start` plus one `recordRound` happen first, then `expect(prefs.containsKey('party_night_v1'), isTrue)`, then `end()`, then the key is gone; (b) NEW test: a night saved with round 0 is not resumed by a second container and its key is cleared; (c) NEW test: a player who joins after a round and then leaves is in the resumed night's seen rows after a second container loads it (the roster change was saved).
4 Report: the three fixes.
5 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/night_save.dart · packages/party_host/lib/src/night/party_night.dart · packages/party_host/test/night_save_test.dart
check: format analyze host
report: docs/briefs/m17/night1b/e0g-report.md
