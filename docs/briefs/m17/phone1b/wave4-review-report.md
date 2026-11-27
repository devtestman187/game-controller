# Review of phone1b wave 4 (y0h3, y0h4, y0h5)

## Summary

Verdict: needs Claude (two must findings change scope or pin a test that does not fail on the old code).
Counts: 2 must, 8 should, 2 could.
1. **must** The pause tests' "keeps it after resume" check passes on the code before the wave; the report's mutation check does not show the test fails on the old code.
2. **must** `pick()` keys the "kept over resume" rule on any pick made while paused, phone picks included, not only host picks.
3. **should** The "already away" pause test (`choice_round_pause_test.dart:172-182`) lost its delay and has no wait for the drop, so it passes whether or not the round saw the drop.

## Findings

- **must** packages/connection/test/choice_round_pause_test.dart:198 The new `expect(changes, 0)` passes on the code before this wave, because the pre-wave `resume()` (choice_round.dart:121-127 at cd40b310) already skipped `byDefault` players, so the test does not fail on the old `resume()` as brief item 3 and the y0h5 commit draft say → Say in the commit draft and the report that this test pins existing behaviour and passes on the old code, or find a case that fails there; the mutation in y0h5-report.md:12 removes a guard the old code never had.
- **must** packages/connection/lib/src/choice_round.dart:145 `pick()` records every pick made while paused, and `_onMessage` (:224) calls `pick()` for a phone's own ChoicePickMessage, so a phone that picks during a pause and drops before resume keeps its unlocked pick and is never defaulted (the owner's rule covers host picks only) → Limit the set to host picks, or list this in the report's Decisions and have the owner confirm it.
- **should** packages/connection/lib/src/choice_round.dart:39 The dartdoc line is 124 columns, over the 120-column limit; dart format does not wrap comments → Rewrap it onto two `///` lines.
- **should** packages/connection/test/choice_round_pause_test.dart:172-182 The fixed delay is gone and nothing waits for the round to see the drop; `lockedIds` is empty whether or not the drop was handled, so the test passes either way and does not prove the ordering its comment claims. Brief item 2 said to stop if the round had no signal, and the worker went on → Restore a wait on a public signal, or stop and ask Claude.
- **should** packages/connection/test/choice_round_test.dart:331 The added line asserts `defaultId == 'save'`, not that the default card is applied with `byDefault: true` before the pick, which brief item 4 asked for (the report's Q3 says `byDefault` is not visible) → Add the check through a public path, or have Claude approve the `defaultId`-only assertion.
- **should** packages/party_host/lib/src/testing/samples.dart:85 `phoneInfo` now takes six parameters (id, player and four named), over the five-parameter limit in coding-guidelines §3; the brief asked for the argument and the report flags it → Claude decides between a value object for the optional fields and accepting the breach.
- **should** packages/party_host/test/night_start_old_app_test.dart:112 The guard's fail-first check was not run (y0h3-report.md:33). The production night screen did not change in this wave, so the test passes on the old code; what makes it a guard is the mutation check (line never shown, line always shown), which was not run → Run both mutations and record the result in the report.
- **should** packages/party_host/test/shop_demo_test.dart:161 The test keeps literal strings ('Spend your Bolts' at :161, 'Time is up' at :170, 'Ann: Build 2 = 6 Bolts' at :171), where brief item 2 says the test uses `ShopText` → Claude confirms the worker's reason (constants would compare the words with themselves) and amends the brief, or the test uses `ShopText`.
- **should** docs/briefs/m17/phone1b/y0h4-report.md:25 `flutter test` on `games_screen_frame_test.dart`, which brief item 5 names, was not run (the report says mine.sh runs only touched tests) → Run it on its own and record the result.
- **should** docs/briefs/m17/phone1b/y0h3-report.md:34 `night_screens_test.dart`, which brief item 3 names, was not run → Run it and record the result.
- **could** packages/party_host/lib/src/testing/samples.dart:78 The comment cites the job id "M17 y0e", which a later reader cannot use; the comment should say why the default is empty → Drop the job id and keep the reason.
- **could** packages/connection/lib/src/choice_round.dart:132 `pick()`'s dartdoc does not say that a pick made during a pause is kept over `resume()`, which is now a rule → Add one sentence to the dartdoc.

## Decisions to confirm

- Phone picks are kept over resume as well as host picks (choice_round.dart:145): the owner's rule names host picks only.
- The fixed delay is removed from the "already away" test without a sync point (choice_round_pause_test.dart:172): the brief said to stop instead.
- `phoneInfo` takes six parameters (samples.dart:85): accepted by the brief, breaks the guideline.
- The shop test keeps literal strings (shop_demo_test.dart:161): not what brief item 2 says.
- `ShopDemoScreen` stays exported (party_host.dart:103): kept because shop_demo_test.dart:4 imports the barrel and uses it, which the brief allows.
- The pick guard is cleared at `resume()` (choice_round.dart:128): a player who drops again after resume gets the normal grace and can be overwritten (the report's Q5).
- The `byDefault` check uses `defaultId` only (choice_round_test.dart:331).

## Could not check

- I did not run any test, analyzer or mutation: this is a read-only review. The mutation claims in y0h5-report.md:12 and the mine.sh counts in the three reports are unverified.
- I read `FakeHostService.gameHost.addLocalPlayer` only by its use in the old-app test (night_start_old_app_test.dart, the host-own test); the fake's API was not read.
- The pause test "host pick survives for a player away" is reasoned to fail on the old `resume()` (it starts a grace for phone-2, which expires to `save`); it was not run.
- Line widths: a grep for lines over 120 columns found none in shop_demo_screen.dart, shop_text.dart, samples.dart, night_start_frame_test.dart, night_start_old_app_test.dart, shop_demo_test.dart or choice_round_pause_test.dart. The only one is the choice_round.dart:39 finding.
- run-findings.md has five entries, all for other jobs (y0p, y0d, y0f); none is about y0h3, y0h4 or y0h5, so none counts as a finding here.

## Commit message — a draft

review: phone1b wave 4 (y0h3 y0h4 y0h5)

Read-only review of the three wave-4 jobs against the guidelines, the review
rules and their briefs. Findings and the questions for Claude are in
docs/briefs/m17/phone1b/wave4-review-report.md. No code or test was changed.

## Status row

phone1b wave 4 review: done; needs Claude: 2 must (a pause test that passes on the old code; phone picks kept over resume as well as host picks), 8 should, 2 could. Open: those findings and the decisions listed in the report.

## Delete

- none
