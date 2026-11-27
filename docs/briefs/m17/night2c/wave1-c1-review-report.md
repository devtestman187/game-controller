# Review of night2c c1 (commit a8ebf10a)

## Summary

small fixes
Counts: must 0, should 1, could 3.
- **should** `docs/briefs/m17/night2c/c1-report.md:32`: the self-check says the test's old phone is "a peer one build older", but the test only drops the choices capability; both phones share appVersion `test`, so no version mismatch is modelled.
- **could** `packages/party_host/test/phone_text_test.dart:51`: `text!` is used with no proof on the line before (`expect` does not promote it); a null text would throw instead of failing the check.
- **could** `docs/briefs/m17/night2c/c1-report.md:26`: the version text is given as 150 characters; by my hand count the literal is 148.

## Findings

- **should** `docs/briefs/m17/night2c/c1-report.md:32` The self-check says the test's old phone is "a peer one build older", but `shop_demo_test.dart:72` gives it the same appVersion `'test'` and only drops `Capability.choices`; no version mismatch is modelled → reword the line to "a phone without the choices capability (not a version mismatch)".
- **could** `packages/party_host/test/phone_text_test.dart:51` `text!` is used with no proof (the `expect` above does not promote it), against the `!` rule; a null result would throw rather than fail the check → write `final text = PhoneText.problemText(mismatch) ?? '';` and drop the `!` and `text!`, so a null text fails the equality on line 46.
- **could** `packages/party_host/test/shop_demo_test.dart:185` The test name says "and only if it lists choices", but its body only checks a capable last phone (Bea with choices); the old-phone rule is pinned at line 198 → shorten the name back to "Roadworks is offered to the last player number only", or move the old-phone assertion into this test.
- **could** `docs/briefs/m17/night2c/c1-report.md:26` The version text length is written as 150; counting the literal by hand gives 148 → correct the number, or count it with a tool before the report is used.

I checked and found no fault in: the `cardsFor` change (`shop_demo_screen.dart:83`, `_listsChoices` at `:99-101`, using `ControllerInfo.controllerId` and `supports` as defined in `host_types.dart`); the doc comments; the line lengths of the changed lines (all within 120); the version text (no "protocol", under 200); the old-phone test (`shop_demo_test.dart:198-212`), which would fail without the change because X would carry the Roadworks label; no other test or doc pins "Install matching builds"; `choice_fallback_test.dart` untouched; no debug code.

## Decisions to confirm

- The old-phone test gives its phone `Capability.layout` (`shop_demo_test.dart:72`) so it receives a layout; a real old app is assumed to have layout too. Why: the test's pass depends on it; the worker flagged it as unverified on a device.
- The version text says "the Thumb Party app on the TV, or on this phone (Android or iPhone)"; the owner's wording was "the TV app, or the phone app on Android/iPhone". Why: the owner should confirm the wording for kids and parents.
- `_listsChoices` re-derives the old-phone rule that `choice_fallback.dart:199` already encodes (`!controller.supports(Capability.choices)`). Why: two copies of one rule can drift; the worker suggested a shared helper, which is outside this job's allow list.

## Could not check

- The worker's test result (`tools/mine.sh` → `OK 20 tests`) was not re-run: this review changes nothing and runs no tests. The claim is unverified here.
- Whether `cardsFor` runs only after the old phone is in `host.server.snapshot.controllers` at round start (timing) was not traced.
- Whether a real old app sends layout capability (device check, not possible here).
- `dart analyze` and `dart format` were not run on the changed files.
