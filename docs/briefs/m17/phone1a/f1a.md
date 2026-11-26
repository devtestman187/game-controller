job: phone1a f1a — fix: ChoiceRound constructor takes value objects (docs/coding-guidelines.md:43, at most 5 parameters)
stop: no behaviour change; do not touch choice_fallback.dart or the wire messages; no other finding of the reviews.
read: docs/briefs/templates/COMMON.md · docs/coding-guidelines.md:40-45 · packages/connection/lib/src/choice_round.dart:1-80 · packages/connection/lib/src/choice_round_state.dart · packages/connection/lib/connection.dart:35-40 · packages/connection/test/choice_round_test.dart:55-100 · packages/connection/test/choice_fallback_test.dart:50-90 · driver decision: wire messages keep their flat fields (precedent ViewStartMessage); only the ChoiceRound constructor is regrouped
changes: ChoiceRound.new · ChoiceRoundSetup · ChoiceTiming
turns: 45
expected-min: 25
tests-first: exempt refactor: the existing tests pin the behaviour and only their constructor calls change
do:
1 New packages/connection/lib/src/choice_round_setup.dart with `ChoiceRoundSetup({required round, required title, required cardsFor, this.defaultId, this.currency})` and `ChoiceTiming({required duration, required grace, required nowMs})`, each field with its dartdoc line moved from ChoiceRound. Export both from connection.dart.
2 choice_round.dart: the constructor becomes `ChoiceRound({required this.server, required this.players, required this.setup, required this.timing})`. Keep the getters `cardsFor`, `defaultId`, `currency` (choice_fallback.dart uses them); every other use reads `setup.` or `timing.`. Behaviour identical.
3 Update the two constructor calls in choice_round_test.dart (:67) and choice_fallback_test.dart (:59), nothing else in them.
4 Before finishing run `dart analyze` and `dart format` on the changed files and fix every info, warning and error; run `dart test packages/connection/test/choice_round_test.dart packages/connection/test/choice_fallback_test.dart`.
allow: packages/connection/lib/src/choice_round_setup.dart · packages/connection/lib/src/choice_round.dart · packages/connection/lib/src/choice_round_state.dart · packages/connection/lib/connection.dart · packages/connection/test/choice_round_test.dart · packages/connection/test/choice_fallback_test.dart
check: format analyze
report: docs/briefs/m17/phone1a/f1a-report.md
