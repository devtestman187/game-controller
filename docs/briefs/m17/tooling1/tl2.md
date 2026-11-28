job: tooling1 tl2 — systest settle(): no fixed 40 ms real wait when a condition is known
stop: test support only; no lib/ change; do not touch the two systest test files unless they fail.
read: docs/briefs/templates/COMMON.md · packages/party_host/test/systest/systest_support.dart:117-145 · packages/party_host/test/systest/night_vote_phones_test.dart:65-110 (webSocket: true users)
changes: Systest.settle (new optional named parameter `done`) · Systest.until
model: haiku
turns: 35
expected-min: 30
tests-first: exempt test-support refactor; the existing systests are the proof
do:
1 Line 123: on a socket listener settle waits a fixed `Future.delayed(40 ms)` in runAsync on every call. Add `Future<void> settle([Duration time = 50 ms, bool Function()? done])`: the real wait becomes a bounded poll inside the same runAsync, in 2 ms slices, up to the same 40 ms, leaving early as soon as `done?.call() == true`. With no `done` it waits the full 40 ms as today (never shorter without a known condition, so no test gets flakier). Clock behaviour (tester.pump(time)) unchanged.
2 `until` passes its `done` to settle, so a reached state ends the real wait early. The limit logic stays as is. In-process path unchanged.
3 Run `flutter test packages/party_host/test/systest` before and after; all must pass. Report both durations. Then `dart analyze` on the file.
allow: packages/party_host/test/systest/systest_support.dart
check: format analyze
report: docs/briefs/m17/tooling1/tl2-report.md
