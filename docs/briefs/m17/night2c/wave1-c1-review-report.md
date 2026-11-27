# Review of night2c c1 (commit a8ebf10a)

## Summary

small fixes
Counts: must 0, should 3, could 3.
- **should** `packages/party_host/lib/src/ui/shop_demo_screen.dart:83`: `cardsFor` reads the live controller list on every call, so a last phone that drops out of it mid-round loses Roadworks and its pick is refused.
- **should** `packages/party_host/lib/src/text/phone_text.dart:112`: the working tree has uncommitted c1 edits (new wording, test changes) that differ from the reviewed commit.
- **should** `docs/briefs/m17/night2c/c1-report.md:32`: self-check 1 says the old phone is "a peer one build older"; the test gives both phones the same build.

## Findings

- **should** `packages/party_host/lib/src/ui/shop_demo_screen.dart:83` `cardsFor` calls `_listsChoices` (`:100-101`), which reads `host.server.snapshot.controllers` on every call; `cardsFor` runs on each press and each completion check (`packages/connection/lib/src/choice_round.dart:194`, `choice_fallback.dart:153,165`), and each read rebuilds the list (`packages/connection/lib/src/host_server.dart:301-313`). If the last phone's entry is missing at a later call (for example a forgotten pairing mid-round), its card list flips to the shop cards and a Roadworks pick is refused (`choice_round.dart:152`); the dropped-link pair in rule A3 has no test → evaluate `_listsChoices(host, lastId)` once when the round is set up, capture the bool, and add a test where the last capable phone's link drops and Roadworks stays offered.
- **should** `packages/party_host/lib/src/text/phone_text.dart:112` The reviewed commit says "Update the Thumb Party app on the TV, or on this phone (Android or iPhone), so both are new." (148 characters). The working tree, not committed, says "This phone app and the Thumb Party TV app ... Update the Thumb Party TV app, or this phone app (Android or iPhone)" (154 characters), with matching test edits (`phone_text_test.dart:46-51`) and a shortened test name (`shop_demo_test.dart:185`); run.log (11:18) records it as a HAND-FIX → Claude picks one wording, then commits the text, the test and the report together so the reviewed state is the committed one.
- **should** `docs/briefs/m17/night2c/c1-report.md:32` Self-check 1 says the old phone is "a peer one build older", but `packages/party_host/test/shop_demo_test.dart:55` and `:71` give every phone `appVersion: 'test'`, and the old phone only drops `Capability.choices`; no older build is modelled, so the A1 claim is false → reword to "a phone without the choices capability; no older build is tested".
- **could** `docs/briefs/m17/night2c/c1-report.md:26` The version text is stated as 150 characters (also `:11`); the committed literal is 148 characters (counted with `wc -m`). `REVIEW-VERDICTS.md:17` records this as fixed by hand, but the committed report still says 150. The test asserts only `< 200`, so no test is wrong → write 148 in both places (154 if the working-tree wording is chosen).
- **could** `packages/party_host/test/phone_text_test.dart:51` `text!.length` follows `expect(text, ...)`, which does not promote the nullable, so the `!` is not proven by the line before (guidelines §2); a null text would throw rather than fail the check → `final text = PhoneText.problemText(mismatch) ?? '';` (the working tree already does this).
- **could** `packages/party_host/test/shop_demo_test.dart:185` The name "…only, and only if it lists choices" claims the old-phone rule, but the body checks only the capable last phone (line 190); the old-phone rule is pinned at line 198 → use "Roadworks is offered to the last player number only" (the working tree already does this).

Checked and no fault found: the `cardsFor` change's use of `ControllerInfo.controllerId` and `supports` (`packages/connection/lib/src/host_types.dart:39,120`); no line over 120 columns in the four changed files; `dart format --output=none --set-exit-if-changed` on the four files reports 0 changed; the version text has no "protocol" and is under 200 characters; no other file or doc pins "Install matching builds"; `choice_fallback_test.dart` is untouched; no debug code, TODO or print. The new old-phone test should fail on the old code: the old `cardsFor` gives Bea three cards, so X carries the Roadworks label and the `isFalse` assertion at `shop_demo_test.dart:209` fails (reasoned, not run).

## Decisions to confirm

- The old-phone rule sits in `cardsFor` (`shop_demo_screen.dart:83`) and `choice_fallback.dart` is unchanged, although the owner named "the old-phone fallback". Why: the X button hides because the fallback maps only the cards it is given; Claude should confirm this is the intended place. It also repeats the rule at `choice_fallback.dart:199` (`!controller.supports(Capability.choices)`).
- The old-phone test gives its phone `Capability.layout` (`shop_demo_test.dart:72`), and the host sends layouts only to phones whose hello lists it (`host_server.dart:247`). Why: the test passes only if real old apps also list layout, which is unverified on an old build.
- Which version text ships: the committed "Thumb Party app on the TV, or on this phone" or the working-tree "Thumb Party TV app". Why: the owner's words were for kids and parents.

## Could not check

- Scope: commit a8ebf10a was reviewed as the brief asks. The working tree holds uncommitted edits to `shop_demo_test.dart:185`, `phone_text.dart:112` and `phone_text_test.dart:46-51`; they were read only as differences.
- No test was run (read-only job). The worker's `tools/mine.sh` → `OK 20 tests` is unverified here. The "fails on old code" reasoning above is not run.
- Whether a real old app lists `Capability.layout`: no old build here.
- Whether `ShopDemoScreen` is reachable on a phone host: `shop_demo_screen.dart:74` returns early unless the host is a `ServerGameHost`; the reachability was not traced.
- Whether a paired phone leaves `controllers` while away or after a forgotten pairing: read from `host_server.dart:301-313` (sessions with a hello, plus paired offline pairings), not run.
- The report layout: the brief asks for four sections in order and nothing else; the task also asks for three closing sections, placed after this section.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
review: wave1-c1 (a8ebf10a) findings, report only

Reviews night2c c1 against its brief, the coding guidelines and the
review rules. Findings: 0 must, 3 should, 3 could (see the report).
Main items: the Roadworks rule is read live on each call to cardsFor
(shop_demo_screen.dart:83); self-check 1 claims an older build that
the test does not model. The working tree has uncommitted c1 edits
that differ from the reviewed commit; Claude picks the wording.
```

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2c wave1-c1 review: done (0 must, 3 should, 3 could). Open: the 3 should findings, and the choice between the committed and working-tree version text (Claude).

## Delete

- none
