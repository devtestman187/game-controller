## Summary

Verdict: small fixes
Counts: must 0 · should 2 · could 5 (7 findings)
Top three:
1. should: `start()` after `dispose()` still subscribes to input, server changes and round changes (choice_fallback.dart:95).
2. should: f3's self-check says `_phones` and `held` are cleared in `_finish`; they are not (f3-report.md:20).
3. could: the 24-character title limit is a second copy of the protocol's "24", not next to `ChoiceCard` (choice_round.dart:24).

## Findings

- **should** packages/connection/lib/src/choice_fallback.dart:95 `start()` only checks `_started` and `round.isClosed`, so after `dispose()` (which sets `_finished`) it subscribes `_inputSub`, `_serverSub` and `_roundSub`, and nothing cancels them → add `_finished` to the guard: `if (_started || _finished || round.isClosed) return;`.
- **should** docs/briefs/m17/phone1a/f3-report.md:20 The self-check says `_phones` and `held` are "cleared in `_finish`", but `_finish` (choice_fallback.dart:174-184) only sets `_finished`, resets layouts and statuses, and cancels subscriptions; it never clears `_phones` or `held` → correct the line to say what `_finish` does, or clear `_phones` in `_finish` if that is the intent.
- **could** packages/connection/lib/src/choice_round.dart:24 `maxTitleLength = 24` lives in ChoiceRound, while the wire doc says "the host cuts it to 24" in packages/protocol/lib/src/choices.dart:22, next to the existing precedent `ChoiceCard.maxCountLimit` (choices.dart:17) → move it to `ChoiceCard` as `maxTitleLength` and use it from ChoiceRound, so the number has one owner.
- **could** packages/connection/lib/src/choice_round.dart:222 `substring(0, maxTitleLength)` can split a UTF-16 surrogate pair (emoji in a card name), sending a lone surrogate to the phone; `_cut` in choice_fallback.dart:221 does the same → cut on runes, or write in the doc that the count is UTF-16 units.
- **could** packages/connection/test/choice_fallback_test.dart:109 The label-cut test expects `_longTitle.substring(0, GameLayoutMessage.maxLabelLength)`, which repeats the code's own cut rather than checking the result → expect `label.length` to equal `GameLayoutMessage.maxLabelLength` and the label to start with `_longTitle`, so the test is not a copy of `_cut`.
- **could** docs/briefs/m17/phone1a/f1b-report.md:19 Self-check item 1 answers only the capable phone and the old phone; the TV host, PC host, "Play on this phone", "Show on this device" and the one-build-older peer are not answered, not even as "not affected" → add one line for each (the title cut touches only sent cards, so "not affected" is likely true for most).
- **could** packages/connection/test/choice_fallback_test.dart:245-259 The drop test checks counting only; labels after a reconnect are not asserted, and the test uses MemoryGameHost, which does not replay layouts to a rejoined phone (server_game_host.dart:316-320 does) → add one assertion on `host.layouts` after the reconnect, or note in the report that the replay is only covered by ServerGameHost code.

## Decisions to confirm

- choice_fallback.dart:198 A late old phone is set up when it is listed in `snapshot.controllers`, not when it is connected (f3 Question 2). A listed but offline old phone is set up at start, as before, and now also on each change. Why: it matches `start()`; the owner should say if a set-up should wait for a connection.
- f3 Question 1 (a reconnecting phone's layout): the real host replays layout and status to a rejoined phone (server_game_host.dart:316-320), so the drop path is covered in production; the tests use MemoryGameHost, which does not. Why: the owner should accept that coverage.
- choice_round.dart:24 `ChoiceRound.maxTitleLength` is a public static constant; see the could finding above for moving it to the protocol.
- f1b-report.md:26 The worker ran `tools/mine.sh` and did not run `dart test packages/connection/test/choice_round_test.dart` as f1b.md step 3 asked. mine.sh covers that file, so this is accepted unless the owner wants the brief's command.
- choice_fallback_test.dart:205 The f3 worker kept "the outcome at close is the stored pick". It is not a repeat: no other test asserts the byDefault false outcome of a single A press. Accepted.

## Could not check

- I did not run the tests, `dart analyze` or `dart format`: the job is read-only, and checking out the old code to see the new tests fail was not allowed. The "fails on the old code" statements below come from reading the code: the late-connect test fails on the old code (old `start()` never sets up phone-2, so `host.layouts['phone-2']` is null); the drop test fails on the old code (`held` stays `{b}` at choice_fallback.dart:136, so the second press is suppressed and the status stays "Build 1 = 3 Bolts"); the 40-character title test fails on the old code (the full 40-character title is sent). Values checked by hand: "Build 1 = 3 Bolts", "Build 2 = 6 Bolts" (cost 3 × 2), label 'Save +2' and status 'Default: Save +2' match `_cards` (choice_fallback_test.dart:10-14).
- The worker's counts (mine.sh: 30 tests in f1b, 59 in f3) are not verified.
- Line length: a regex search for 121+ characters in the four changed files found none.
- Whether `dart format` accepts the new multi-line calls in choice_round_test.dart:297-300 and choice_fallback_test.dart:223-244 is not checked.
- Whether any party_host caller calls `start()` after `dispose()` is not checked; the should finding stands on the code alone.

## Commit message — a draft

Add wave 5 review of f1b and f3

- Review of the wave 5 jobs f1b (ChoiceRound title cut and timer
  tidy) and f3 (old-phone fallback late set-up and drop fix).
- Findings: start() after dispose() still subscribes; f3's self-check
  claims _finish clears state it does not clear; title-limit placement
  and a few test and report points.
- No code changed; this report is the only file added.

## Status row

wave5 review (f1b, f3): done, 0 must, 2 should, 5 could. Open: start() guard for dispose (choice_fallback.dart:95), f3 self-check line 20 correction; owner to confirm late set-up on listed phones and the MemoryGameHost replay coverage.

## Delete

- none
