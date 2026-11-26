# Wave 1 review: y0p and y0dc (phone1b)

## Summary
Verdict: small fixes
Counts: 0 must, 6 should, 5 could
Top three:
1. choice_round.dart:121 resume() re-arms grace for an already-defaulted player, so a host pick() made during the pause is overwritten; the pause test at choice_round_pause_test.dart:164 can pass without exercising pause()'s cancel.
2. choice_round_pause_test.dart:19 the pause tests use real timers and Future.delayed; guidelines §9 says no real time in tests, and the brief asked for them. Owner decision.
3. docs/protocol.md:276 the pick rule does not say that an unlocked pick is applied at the round's end, which choice_round.dart:202 does.

## Findings
- **should** packages/connection/lib/src/choice_round.dart:121 resume() starts a grace timer for every absent player, including one already defaulted before the pause; when it fires it overwrites any pick() made for that player during the pause (line 242) → skip a player whose held pick is already byDefault, or confirm the brief's literal rule (see Decisions).
- **should** packages/connection/test/choice_round_pause_test.dart:166 nothing waits for the round to see the drop before pause() at line 168, so the test can pass with no away timer ever started and pause()'s cancel (choice_round.dart:108) is never exercised → add `await Future<void>.delayed(_insideGrace);` after line 166.
- **should** packages/connection/test/choice_round_pause_test.dart:19 real timers and Future.delayed in the pause tests (lines 33-34, 112, 122, 151, 155, 169); guidelines §9 says no real time in tests → convert to fake_async with the injected nowMs, or get the owner to accept real timers (see Decisions).
- **should** docs/protocol.md:276 the pick rule says a pick is accepted until the timer ends but not whether an unlocked pick counts at the end, and says nothing about picks during a pause; choice_round.dart:202-204 (_outcomeFor) applies the held pick whatever `locked` says → add one sentence stating that an unlocked pick is applied at the end and that picks are accepted while paused (pending the owner's Q3).
- **should** docs/briefs/m17/phone1b/y0dc-report.md:38 night_end_client_test.dart, a check the brief names, was not run by anyone (not in run.log), although client_messages.dart routing changed → run it before the wave is accepted.
- **should** docs/briefs/m17/phone1b/y0p-report.md:22 self-check line 3 defers pause × host away, pause × "Get ready" and pause × results to B4 n1g, with no test and no combination row; review rule A3 asks for the pairs to be named and tested → name them as "not tested, B4 n1g" in the report, or add the tests when n1g lands.
- **could** packages/connection/lib/src/choice_round.dart:167 dispose() does not clear `_pausedLeftMs`, so isPaused stays true after dispose; y0p-report.md:21 says the kept state ends at resume() or close() → add `_pausedLeftMs = null;` to dispose(), or correct the self-check line.
- **could** packages/connection/lib/src/choice_round.dart:170 dispose() repeats the away-timer loop of _cancelAwayTimers() (line 187) → call `_cancelAwayTimers()`.
- **could** packages/protocol/test/choices_codec_test.dart:112 asserts that two unequal messages have different hashCodes; hash collisions are allowed, so this is not a rule and can break on an unrelated change → delete the line; the == check at line 111 stays.
- **could** docs/protocol.md:368 the brief asked for three direction-summary rows, one per message; the worker wrote two grouped rows (the table's existing style) → confirm the grouping, no change if accepted.
- **could** docs/briefs/m17/phone1b/y0p-report.md:1 there is no `## Summary` block (run-findings.md:1 logged the same) → add one when the report is re-issued.

## Decisions to confirm
- choice_round.dart:121: resume() re-arms a full grace for every absent player (the brief's literal rule). Keeping it means an already-defaulted player is defaulted again, and a host pick() in between is replaced. Owner to choose: keep, or skip already-defaulted players.
- choice_round_pause_test.dart:19: real short timers, as the brief asked, against guidelines §9 (no real time). Owner to accept the flake risk (the 100 ms and 1500 ms margins) or require fake_async.
- choice_round.dart:202-204: an unlocked pick is applied at the round's end (the code does not look at `locked`); docs/protocol.md is silent. Owner's Q3 is still open, so the doc should say what the code does once it is answered.
- y0dc: `ControllerIdentity.libraryCapabilities` is unchanged, so the app must list `choices` itself when y0d lands (y0dc-report.md Decisions 1 and Questions 2). Confirm this is the intended order.
- docs/protocol.md:28 (8f, `paused`): "the phone shows it and stops its countdown" describes phone behaviour that does not exist until y0d.

## Could not check
- The night_end_client_test.dart result: not run by me (read-only review) and not in run.log.
- dart analyze and tools/mine.sh results: not re-run; I relied on the reports' claims.
- Real-timer flakiness under load: not measurable from reading.
- docs/protocol.md 8f (the pad's A/B/X/Y mapping through §8a layout messages): not checked against the host's layout code.
- The tests-first result: run.log:15-16 says both new test files fail on the old code; I did not re-check it.
- choice_round.dart:194: the int return type of `_timeLeftMs` with `clamp`; I trusted the analyzer, which the reports say is clean.
- client_choices_test.dart:120-142: that isConnected is false before PairResult; I did not trace it in the client code.

## Commit message — a draft
m17 phone1b wave1 review: findings only, no code change

Review of y0p and y0dc against the guidelines, review rules and briefs.
Only the review report is written. Result: small fixes (0 must,
6 should, 5 could). Main points: the pause test may not exercise
pause()'s cancel; resume() re-arms defaulted players; protocol.md
does not say that an unlocked pick is applied at the end.
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row
phone1b wave 1 (y0p, y0dc) reviewed: small fixes open (0 must, 6 should, 5 could); open: pause test cancel and real timers, unlocked-pick doc, night_end_client_test run, Q3.

## Delete
- none
