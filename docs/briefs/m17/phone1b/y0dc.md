job: phone1b y0dc — the phone client receives choices and sends picks (connection client plumbing) and docs/protocol.md
stop: no phone UI, no controller_app change, no change to ChoiceRound or the host files, no protocolVersion bump.
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/client_messages.dart:40-80 · packages/connection/lib/src/client_controls.dart:1-80,125-140 · packages/connection/lib/src/controller_client.dart:115-180,285-295,345-355 · packages/connection/test/night_end_client_test.dart (copy its setup) · packages/protocol/lib/src/choices.dart (messages) · docs/briefs/m17/phone1a/contract.md (Wire) · docs/protocol.md:47-62,242-254,327-343 · owner, Nov 26: old phones keep playing through A/B/X/Y; no protocolVersion bump
changes: ControllerClient.choices · ControllerClient.choicesEnds · ControllerClient.sendChoicePick · ClientControls.addChoices · ClientControls.addChoicesEnd
model: haiku
turns: 60
expected-min: 30
tests-first: exempt new streams with no earlier behaviour; the new test is the first test
do:
1 client_controls.dart: broadcast streams for ChoicesMessage and ChoicesEndMessage with addChoices/addChoicesEnd (closed in close(); reset() leaves them as the night end does).
2 client_messages.dart: route ChoicesMessage and ChoicesEndMessage to them only while paired AND the identity lists Capability.choices (as RatingAskMessage does); drop them from the "ignored" case list and fix the comment above it (ChoicePickMessage stays ignored, it is phone to host).
3 controller_client.dart: getters `choices` and `choicesEnds`, and `sendChoicePick(ChoicePickMessage)` sent only while connected and the host listed Capability.choices (like sendRating).
4 New test connection/test/client_choices_test.dart: a paired phone that lists the cap gets both messages on the streams; a phone without the cap gets none; an unpaired one gets none; sendChoicePick reaches the host when it listed the cap and is dropped when it did not.
5 docs/protocol.md: add `choices` to the capability table (near line 59: `choices` | `choices` (host to controller, with `choice_pick` back and `choices_end`) | M17 phone1a), a new section 8f "Choices (capability `choices`, M17)" in the style of 8e: the three messages and their fields (copy from contract.md Wire; also `paused` on `choices`, true while the host has frozen the timer, the phone shows it and stops its countdown), the rules (a side sends only what the other listed; pick is allowed until the timer ends and a pick with locked false is an undo; nothing chosen gets the host default; an older phone without the cap is played through A/B/X/Y on the pad), and one line "A peer one build older" as 8e has; add the three rows to the direction summary in section 11.
6 Before finishing run `dart analyze` on the changed files and fix every info, warning and error; run `dart test packages/connection/test/client_choices_test.dart packages/connection/test/night_end_client_test.dart`.
allow: packages/connection/lib/src/client_controls.dart · packages/connection/lib/src/client_messages.dart · packages/connection/lib/src/controller_client.dart · packages/connection/test/client_choices_test.dart · docs/protocol.md
check: format analyze connection
report: docs/briefs/m17/phone1b/y0dc-report.md
