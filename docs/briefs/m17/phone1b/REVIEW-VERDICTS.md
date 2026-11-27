Q2 (flat wire fields, small types in one file, ChoiceRound constructor regrouped into setup and timing value objects): accepted by the owner as an internal style call (Nov 26); no change.
Wave 1 review (wave1-review-report.md, 11 findings, 0 must), all go to y0h or code-health:
- choice_round.dart:121 resume() re-arms grace for an already-defaulted absent player and can overwrite a pick - should, y0h (skip players whose pick is already by default).
- pause test :166 no wait before pause() - should, y0h (wait until the round saw the drop).
- real timers in the pause test (guidelines section 9) - same as B5: fake_async is not a connection dependency; kept, code-health.
- docs/protocol.md: say an unlocked pick counts at round end and picks are accepted while paused - should, y0h (Q3 default, pending).
- y0dc: night_end_client_test.dart not run - driver runs it in the final check; y0p: pause x host away / "Get ready" / results belong to B4 n1g - listed for the main line in REPORT.
- dispose() leaves isPaused true and repeats the away-timer loop; hashCode-inequality assert in choices_codec_test:112; protocol.md direction rows grouped; y0p report has no Summary - could, y0h (first three) / ignored.
- Owner questions: none new (full re-grace on resume kept as stated: "no player is defaulted until resume").
Wave 2 + run review (REVIEW.md, 5 must, 9 should, 7 could). y0d did not land in the first try (class brief: pin phone_metrics_test.dart outside allow, 95 turns; the ladder-2 retry could not read the parked patch outside the tree: class environment, patch now committed as probe-y0d-parked.patch, ladder 3). Verdicts:
- storage.dart:55 lacks choices (must) - fixed by the y0d retry (it lists the cap).
- shop button < 48 dp (must) - y0h2; card heights 340/186 -> 308/154 minimal, owner told in REPORT. _PickerBody 6 parameters, comment 387 - y0h2.
- night_start_frame_test phoneInfo caps (must), guard test (must), looks, local controller test (should) - y0h3. Q: phoneInfo gets an optional capabilities argument (samples.dart).
- shop_demo_test format (must), _ShopText to its own ShopText file, Roadworks comment (last player number, no scores in the demo), unused export - y0h4.
- countdown drifts from the round's end, old-phone path test, real timers in the shop test - minor, code-health (owner default: accept real timers for the demo).
- protocol.md paused wording, unlocked-pick wording - y0h. One predicate for "old app" - code-health. Summary blocks in y0d/y0f reports - ignored.
- Wave 1 items (choice_round.dart:121, pause test wait, dispose, hash line, B5 coulds: title limit constant on ChoiceCard, code-point cut, literal-expected cut test) and the build-stop default guard (assert in start, dartdoc, shop test) - y0h.
