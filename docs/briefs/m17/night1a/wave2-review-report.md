# Wave 2 review: n1b (night1a)

## Summary
- Verdict: small fixes
- Counts: must 1, should 2, could 3
- 1. n1b-report.md has no review-rules part A self-check, which guidelines §11 requires (must).
- 2. n1b.md names NightCaptions; the code has only a top-level captionFor, and the report does not say why (should).
- 3. The brief asks for a player joining between rounds; the only join is at round 0, before round 1 (should).

## Findings
- **must** docs/briefs/m17/night1a/n1b-report.md:1 The report has no answer to the part A self-check (every host setup, kept state, state combinations, folder, stop), which guidelines §11 requires for every job → Add the five one-line answers, each with its test; "not affected" is a valid answer for this consumer.
- **should** packages/party_host/lib/src/night/night_captions.dart:7 The brief's changes line (n1b.md:4) names NightCaptions, but the code is a top-level captionFor with no such type, and the report does not mention the difference → Claude decides: wrap captionFor in NightCaptions, or reword n1b.md:4 to match the code, and the report records which.
- **should** packages/party_host/test/night_captions_test.dart:9 Brief item (a) asks for a player joining between rounds; the only join is `NightPlayerJoined('a1', 0)`, before round 1, so no join after a scoreboard is folded or captioned → Add `NightPlayerJoined('a2', 1)` after line 17 and `'Avatar a2 joined at round 1'` to the expected list.
- **could** packages/party_host/lib/src/night/night_captions.dart:8 A legal one-round night (NightFlow.start asserts only rounds > 0, night_flow.dart:245) shows "Tonight: 1 rounds" → Use "round" when n is 1.
- **could** packages/party_host/lib/src/night/night_captions.dart:20 A join during setup reads "Avatar a1 joined at round 0", a number a young player will not understand (guidelines §7) → Drop "at round $r" when r is 0, or say "before round 1".
- **could** packages/party_host/lib/src/night/night_captions.dart:32 The left caption reads "Avatar a1 left at round 1: a player left", which repeats "left" → Give NightReason.playerLeft a phrase that does not repeat the verb.

## Decisions to confirm
- captionFor is a top-level function, not a NightCaptions type as n1b.md:4 names it (see the should finding on line 7); the report does not record the choice.
- `Avatar <id>` prints the raw avatar id. That is safe only while ids are codes and never nicknames, which night_flow.dart:45-46 promises; Claude confirms the id format.
- The how-to card has no last-round flag, so "How to play round 3" cannot say "last round" (n1b-report.md:13 says so). This is the event type's limit, not a change in this job; accepted unless Claude says otherwise.
- night_captions.dart is not pure Dart in the brief's sense: it imports night_flow.dart, which imports flutter/foundation (night_flow.dart:1). party_host is a Flutter package, so no rule breaks; the brief's word "pure" is loose.

## Could not check
- I ran no analyze, format or test. The test result rests on run.log:49 (n1b finished, result 0) and run.log:52 (tests-first ok: the test fails on the old code). The 120-column format is unchecked.
- I traced the 22 events through night_flow.dart:265-287 by reading: every step is legal, and the expected caption list matches captionFor line by line. This is not a run.
- Not read: docs/briefs/templates/COMMON.md and packages/party_host/test/night_flow_test.dart (both named in n1b.md:3).
- Docs: n1b touched no document, so there is nothing to check there.
- Review rules B and C: the consumer has no screen, timer, state or input, so they do not apply.

## Commit message — a draft
Review wave2 n1b: one must, two shoulds, three coulds (night1a)

Review of the n1b job (night1a). The report lacks the part A self-check,
captionFor is named differently from the brief, no test has a join between
rounds, and some caption wording is not kid-safe. Report only; no code changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row
wave2 review of n1b: done (small fixes: 1 must, 2 should, 3 could). Open: the report's part A self-check, the NightCaptions naming, a join-between-rounds test, and the caption wording (Claude to decide).

## Delete
- none
