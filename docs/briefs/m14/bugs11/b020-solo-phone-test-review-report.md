# M14 bugs11 b020-solo-phone-test review

## Summary

Verdict: `clean`. 0 must, 0 should, 3 could.
- The test does what the brief asked: a lone night player on a phone host gets the waiting card, is not ready,
  nothing starts for a second, and one tap on `arenaReady` starts the round; it is mode-agnostic and every pump
  is awaited. It would fail on the pre-B-020 code (the card's keys are absent there), so it is not a test that
  passes on old code.
- The report's own numbers are right except the line count of the new file (53 vs 52).
- The new file skips the sibling's `setUpAll(loadLookFonts)`; the new test is the only night/phone card test laid
  out with the test font.

## Findings

- **could** packages/party_host/test/arena_touch_solo_night_test.dart:40 after the one-second pump only `arena` is checked, so a waiting card that vanished without a round would pass, while the sibling it copies checks both (solo_arena_card_test.dart:61-62) → also expect `arenaWaitingCard` to still be there after the pump.
- **could** packages/party_host/test/arena_touch_solo_night_test.dart:13 the file has no `setUpAll(loadLookFonts)`, unlike arena_touch_ready_test.dart:19 whose night-card test it copies, so the card is laid out with the test font on a phone-sized screen → import support/toy_fonts.dart and add `setUpAll(loadLookFonts);` as that file does.
- **could** docs/briefs/m14/bugs11/b020-solo-phone-test-report.md:20 the report says the new test file is 53 lines; it is 52 (its last line is the closing `}`), and the diff adds 52 → correct the count.

## Decisions to confirm

- Decision 4 (nothing to await: no `settleUploads`/`deleteTempFolder`): true — `pumpHost` builds `FakeHostService`/`FakeStats`, and only the `live_stats*` tests use those helpers; no arena or night test does. Safe.
- Decision 5 (no shared helper): the `ownPhoneOverrides` copy is now in two files (`arena_touch_ready_test.dart:23`, new file:16); a third user would be the point to put it in `test/support/host_harness.dart`, as the report's own suggestion 2 says.
- Decision 3 (1 s pump before the tap): harmless and matches solo_arena_card_test.dart:59-62, but see finding 1 for the assertion it drops.

## Could not check

- The report's claim that the test failed at the "waiting card is gone" expectation before the 200 ms frame was added: reproducing it needs an edit to the test, and this job is read-only.
- The "was 468 tests" baseline: the parent commit's suite was not run (no checkout allowed).

## Commit message

A lone night player on a phone host starts on Ready

The phone host's night card was only tested with a second phone added. Add
one test for the setup whose behaviour changed (run review finding 1): a
phone that plays here, a night of one player, the waiting card asking for
that player's Ready. The card opens, a second of frames starts nothing, and
one tap on the card's Ready button starts the round. The test is
mode-agnostic, so it does not pin which mode button a solo night opens on;
only the ready path is checked. No lib change; host suite 469 tests.

## Status row

M14 bugs11 b020-solo-phone-test: reviewed, clean (0 must, 0 should, 3 could — test-file robustness, font setup, report line count); open: the three could items, if Claude wants them.

## Delete

- none
