Q2 (flat wire fields, small types in one file, ChoiceRound constructor regrouped into setup and timing value objects): accepted by the owner as an internal style call (Nov 26); no change.
Wave 1 review (wave1-review-report.md, 11 findings, 0 must), all go to y0h or code-health:
- choice_round.dart:121 resume() re-arms grace for an already-defaulted absent player and can overwrite a pick - should, y0h (skip players whose pick is already by default).
- pause test :166 no wait before pause() - should, y0h (wait until the round saw the drop).
- real timers in the pause test (guidelines section 9) - same as B5: fake_async is not a connection dependency; kept, code-health.
- docs/protocol.md: say an unlocked pick counts at round end and picks are accepted while paused - should, y0h (Q3 default, pending).
- y0dc: night_end_client_test.dart not run - driver runs it in the final check; y0p: pause x host away / "Get ready" / results belong to B4 n1g - listed for the main line in REPORT.
- dispose() leaves isPaused true and repeats the away-timer loop; hashCode-inequality assert in choices_codec_test:112; protocol.md direction rows grouped; y0p report has no Summary - could, y0h (first three) / ignored.
- Owner questions: none new (full re-grace on resume kept as stated: "no player is defaulted until resume").
