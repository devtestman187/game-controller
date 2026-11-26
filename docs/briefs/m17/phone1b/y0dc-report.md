# phone1b y0dc report: the phone receives choices and sends picks

## Summary

Done: the phone client now takes `choices` and `choices_end` from the TV and sends `choice_pick`, with the same gates as the rating and layout messages. No phone UI, no controller_app change, no ChoiceRound or host change, no protocolVersion bump.

Files changed (all in the allow list):
- `packages/connection/lib/src/client_controls.dart`: two broadcast streams `_choices` and `_choicesEnds` with `addChoices` / `addChoicesEnd`; both closed in `close()`. `reset()` does not touch them, as with the night end.
- `packages/connection/lib/src/client_messages.dart`: `ChoicesMessage` and `ChoicesEndMessage` routed (in `_onControlMessage`) only while paired and only when the identity lists `Capability.choices`. Removed from the ignored list, and the comment above it rewritten. `ChoicePickMessage` stays ignored (phone to host).
- `packages/connection/lib/src/controller_client.dart`: getters `choices` and `choicesEnds`; `sendChoicePick(ChoicePickMessage)`, sent only while connected and the host welcome listed `Capability.choices`. File is 366 lines (limit 380).
- `packages/connection/test/client_choices_test.dart` (new): 5 tests per transport, 10 runs in all.
- `docs/protocol.md`: capability table row `choices`; section 8f "Choices (capability `choices`, M17)"; direction summary rows for `choices` / `choices_end` (host to controller) and `choice_pick` (controller to host).

Test values used:
- `choiceRound`: round 1, title "Shop", one card `save` ("Save +2"), `endsInMs` 5000, `defaultId` "save".
- `choiceEnd`: round 1, result "save", count 1, byDefault true.
- Pick sent: round 1, pick "save", locked true.
- Stats-share marker used to prove a pick was not sent: `setStatsShare(true)` sent after the pick on the same channel.

Decisions (low-usage mode, safest choice):
1. The library does not add `choices` to `ControllerIdentity.libraryCapabilities`. The app lists it in its identity, as it does for `rating`. Adding it to the library list would make every phone claim the cap.
2. Sync in the negative tests: a `PlayersMessage` (paired phone takes it) sent after the choice messages, then wait for `players`. The stats-share message is the sync for the pick-not-sent test, because the channel is ordered.
3. Docs: the pick rule is written as the brief says (a `locked: false` pick is an undo until the timer ends). Q3 is still pending, see Questions.
4. Test host uses a `fromPhone` broadcast stream to see what the phone sent (FakeHost has no send method and the test captures the channel as night_end_client_test does).

## Self-check (review-rules part A)

1. Host setups: a TV host with `choices` in its welcome (test 1, pick test); a TV without it (pick-not-sent test); the paired phone with the cap and without it (tests 1 and 2); unpaired (test 3); a peer one build older is covered in 8f and by the unknown-type rule, not by a test (no older-host double exists).
2. Kept state: none of the new code keeps state beyond the streams, which live for the app's life and close in `close()`. Nothing going on: no message, no stream event.
3. Combination with pause menu, host away, player away, Get ready, dropped link, results, leaving: the phone only forwards; no combination logic (that is y0d). The `connected` gate drops messages after a link drop; `reset()` leaves the streams alone.
4. Stayed inside the folder and allow list (verified with `git status`; other modified files were there before the job).
5. Nothing overstepped; no file needed that was not in allow.
6. Looks: no UI in this job, so no look check.

## Checks run

- `tools/mine.sh`: format OK (8 files formatted by the script), analyze OK on packages/connection and packages/protocol, touched tests OK: "OK 41 tests packages/connection", "OK 18 tests packages/protocol", RESULT ok. Ran once; no fix needed.
- Brief asked for `dart test` on client_choices_test.dart and night_end_client_test.dart directly. I did not run them raw: the worker rules say `tools/mine.sh` only. mine.sh reports failures only, so its output does not list which files ran; I did not confirm client_choices_test.dart is among the 41 tests it counted. The 10 new test runs (5 tests x 2 transports) have not been seen passing one by one, and the new-test-fails-on-old-code check was not run either. night_end_client_test.dart was not touched, so mine.sh did not run it; it is not verified in this job.
- Did not run tools/check.sh (the runner does it).

## Questions

1. Q3 (owner, pending): does a picked but unlocked card count at timer end? The doc currently follows the brief (undo until the timer ends, no mention of the timer-end count). Adjust 8f once answered.
2. Should the app's identity list `choices` on every build, or only once the phone UI (y0d) is in? This job assumes the app lists it when it wants the round.
3. night_end_client_test.dart was not run in this job (see Checks).

## Suggestions

- The `paused` field on `choices` is in the protocol doc but no test in this job covers it; a later job that wires the phone's countdown should add one.
- The 8f text says the host maps old-phone buttons "with its layout messages (§8a)". That matches the contract (oldPhoneButtons uses GameLayoutMessage.hidden) but it is worth a check when y0c lands.

## Hand-over

Phone client plumbing is in place for y0d (phone UI). Nothing in the phone UI, host, or ChoiceRound was touched.

## Commit message — a draft

m17 phone1b y0dc: phone client receives choices and sends picks

Route choices and choices_end to ControllerClient streams, paired and
only when the identity lists choices, as rating is. Add sendChoicePick,
sent only when the host listed choices. Document choices in
protocol.md (section 8f, capability table, direction summary).
No phone UI, no protocolVersion bump: old phones keep the pad buttons.

## Status row

phone1b y0dc DONE: the phone client gets choices/choices_end (paired and listed) and sends choice_pick (host listed); protocol.md 8f. OPEN: phone UI (y0d), Q3 unlocked-pick rule, night_end_client_test not run here.

## Delete

- none
