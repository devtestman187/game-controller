job: phone1a f1b — fix: ChoiceRound titles cut, dead guards, 121-column line, round tests (reviews of waves 2 and 3, run review)
stop: no API change; do not touch choice_fallback files.
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/choice_round.dart (whole, after f1a) · packages/protocol/lib/src/choices.dart:18-30 (title doc: the host cuts to 24) · packages/connection/test/choice_round_test.dart:1-100,235-290 · docs/briefs/m17/phone1a/run-review.md (findings on choice_round)
changes: ChoiceRound._sendState · ChoiceRound.maxTitleLength
turns: 45
expected-min: 25
tests-first: exempt the title-cut test pins a cut the doc already promised; the others are test repairs
do:
1 choice_round.dart: wrap the `server.send(... ChoicesEndMessage ...)` call as `dart format` does (it is over 120 columns); remove the dead `_isDisposed` tests inside the end-timer and grace-timer callbacks (dispose cancels those timers; keep `isClosed` where it is needed); cut each card title to 24 characters in `_sendState` (copy the card with a shorter title; one named constant `maxTitleLength = 24` in ChoiceRound); say "old phone" instead of "legacy" in the docs.
2 choice_round_test.dart: (a) start the round after the phone drains in `_setup` (or pass start: false and call start() after them) so the 300 ms rounds cannot end early, and fix the comment on `_shortRound`; (b) the test "dispose while a player is away" checks only that dispose leaves nothing set and closes nothing: rename it to say so and drop the claim about the grace; (c) new test: a card title of 40 characters reaches the phone cut to 24.
3 Before finishing run `dart analyze` and `dart format` on the changed files and fix every info, warning and error; run `dart test packages/connection/test/choice_round_test.dart`.
allow: packages/connection/lib/src/choice_round.dart · packages/connection/test/choice_round_test.dart
check: format analyze
report: docs/briefs/m17/phone1a/f1b-report.md
