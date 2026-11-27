job: phone1a y0g — fix: ChoiceRound after dispose, dispose test, format, docs (wave 2 review findings)
stop: no change to ChoiceRound's public API or behaviour while running; no y0c work; do not touch host_service.dart.
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/choice_round.dart:1-224 · packages/connection/lib/src/choice_round_state.dart · packages/connection/test/choice_round_test.dart:1-120,155-240 · docs/briefs/m17/phone1a/wave2-review-report.md (findings 1-4 and the could items on choice_round files)
changes: ChoiceRound._isDisposed · ChoiceRound._isStarted
turns: 50
expected-min: 25
tests-first: exempt the new tests pin the use-after-dispose behaviour, which needs the new flag
do:
1 choice_round.dart: add `bool _isDisposed`; `dispose()` sets it first. `start()`, `pick()` and `close()` return at once (close returns the stored outcomes or an empty map, sends nothing) after dispose; the end and grace timer callbacks and `_onMessage`/`_onServerChange` check it too. Rename `_started` to `_isStarted`. Wrap the over-120-column `server.send(...ChoicesEndMessage...)` line the way `dart format` does. Add one dartdoc line each to the constructor, the `server` field and `ChoiceOutcome`'s constructor (choice_round_state.dart).
2 choice_round_test.dart: new tests (real short timers, margins of at least 300 ms for grace and end so a slow machine does not flip them): (a) dispose before the end timer: no ChoicesEnd reaches the capable phone after the duration, and a later pick, close and start do not throw and change nothing; (b) dispose while a player is away: the grace never applies a default. Rename the test at about :199 so its name says what it checks (or delete it if it repeats :186), name the 5 s timeout one constant, fix the two doc lines named in the review (:22-23 and :74). Widen the 200 ms and 100 ms margins in the reconnect and grace tests to 300 ms and 250 ms of slack.
3 Before finishing run `dart analyze` and `dart format` on the changed files and fix every info, warning and error; run `dart test packages/connection/test/choice_round_test.dart`.
allow: packages/connection/lib/src/choice_round.dart · packages/connection/lib/src/choice_round_state.dart · packages/connection/test/choice_round_test.dart
check: format analyze
report: docs/briefs/m17/phone1a/y0g-report.md
