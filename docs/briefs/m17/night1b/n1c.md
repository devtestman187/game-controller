job: night1b n1c — cap a night at 5 rounds, pinned by a constant and a test
stop: no new length, no UI change, no change to NightFlow's events or stages; 8 rounds stays unavailable
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_state.dart:9-17 · packages/party_host/lib/src/night/night_flow.dart:243-247 · plan, quoted (M17-dev-plan n1c): "Cap nights at 5 rounds until about 15 variants; 3 and 5 stay. Test pins that 8 is unavailable."
changes: nightRoundCap
model: haiku
turns: 35
expected-min: 15
tests-first: exempt the shipped lengths are already 3 and 5; the new test needs the new constant, so it fails to compile on the base
do:
1 night_state.dart: add `const nightRoundCap = 5;` with a doc comment (nights stay at 5 rounds until about 15 game variants exist). Give `NightLength` a const-constructor assert `assert(rounds <= nightRoundCap)`.
2 night_flow.dart: in `NightFlow.start` extend the assert to `rounds > 0 && rounds <= nightRoundCap` with a message naming the cap (import night_state.dart only if it is not already imported; check the layer rules in tools/review.sh).
3 Tests: NEW packages/party_host/test/night_round_cap_test.dart, written and run first: every NightLength has rounds in 1..nightRoundCap; NightLength.values rounds are exactly [3, 5]; no NightLength has 8 rounds; NightFlow.start(5) works; NightFlow.start(8) throws an AssertionError (expect(() => ..., throwsA(isA<AssertionError>()))).
4 Report: the cap constant and where it is asserted.
5 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/night_state.dart · packages/party_host/lib/src/night/night_flow.dart · packages/party_host/test/night_round_cap_test.dart
check: format analyze host
report: docs/briefs/m17/night1b/n1c-report.md
