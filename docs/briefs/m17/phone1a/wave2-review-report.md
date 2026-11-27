# phone1a wave 2 review: y0b (ChoiceRound host side)

## Summary
- Verdict: **needs Claude**
- Counts: must 1 · should 5 · could 7
- Most important:
  1. No test calls `dispose()`, so "dispose leaves nothing running" (guidelines §5) is unproven (`choice_round_test.dart:67`).
  2. After `dispose()`, `close()`, `pick()` and `start()` still act: they throw StateError or start timers nothing cancels (`choice_round.dart:89`, `:114`, `:136`).
  3. The reconnect and grace tests run on real 200 ms timers and can fail when the reconnect is slow (`choice_round_test.dart:161`).

## Findings
- **must** packages/connection/test/choice_round_test.dart:67 `dispose()` is only passed to `addTearDown`; no test proves it cancels timers, subscriptions and sends → add a fake_async test: start the round, dispose it, then fire the end and grace timers and send a pick, and check nothing is sent or run.
- **should** packages/connection/lib/src/choice_round.dart:134 This `server.send(...ChoicesEndMessage...)` line is over 120 columns, though the report says mine.sh format passed → wrap it as `dart format` does and re-run the format check.
- **should** packages/connection/lib/src/choice_round.dart:136 After `dispose()` closes `_changes` (`:147`), `close()` sends ChoicesEnd and then throws StateError at `_changes.add`; `pick()` (`:114`, `:120`) throws the same, and `start()` (`:89`) after dispose starts timers that nothing cancels, although dispose's doc (`:140`) says nothing is sent after it → add a disposed flag that `start`, `pick` and `close` check, with one test each.
- **should** packages/connection/test/choice_round_test.dart:161 The reconnect test (and the grace tests at `:186` and `:230`) use real 200 ms and 100 ms timers; a reconnect slower than 200 ms of real time makes the default win, so `picked` is `save` and the test fails, and §9 forbids real time → drive grace and the end timer with fake_async, or send the 200 ms-versus-§9 conflict to Claude.
- **should** docs/briefs/m17/phone1a/y0b-report.md:1 The report has no part A self-check (every host setup, when kept state starts and ends, combinations, folder, stop, every look), which review-rules A requires → have the worker add the six one-line answers, each naming its test.
- **should** packages/connection/lib/src/choice_round.dart:95 The end timer (`Timer(duration, close)`) and the grace timers (`:194`) run on real time with no owner for pause, leave or "Get ready", so a host pause cannot stop them and the round can close or default a player during a pause → decide the owner (Pausable) before y0d and test that pair then; no change in this job.
- **could** packages/connection/lib/src/choice_round.dart:19 The constructor and the public field `server` (`:32`) have no dartdoc (guidelines §10) → add one line to each.
- **could** packages/connection/lib/src/choice_round_state.dart:6 The `ChoiceOutcome` constructor has no dartdoc → add one line.
- **could** packages/connection/lib/src/choice_round.dart:70 `_started` is a past-tense flag, not a question (guidelines §4) → rename it `_isStarted`.
- **could** packages/connection/test/choice_round_test.dart:199 "a player away at close time with no pick change" takes the same path as the test at `:186` (grace lock, then close), and its name does not match → rename it or remove it.
- **could** packages/connection/test/choice_round_test.dart:77 `Duration(seconds: 5)` is a bare literal here and at `:232` → name one timeout constant; the doc at `:22-23` says "the fake clock's start" for `_clockStepMs`, and `:74` says "the away first phone" → fix both docs.
- **could** packages/party_host/lib/src/host_service.dart:141 The comment above the capability list explains metrics, rating and identity but not `Capability.choices` (guidelines §10: say why) → add one line saying a phone that lists it is sent the M17 choice round.
- **could** docs/briefs/m17/phone1a/y0b-report.md:1 The report has no Summary block in its first 40 lines (run-findings.md:1) → put a Summary at the top of worker reports.

## Decisions to confirm
- `packages/connection/lib/src/choice_round.dart:119` A player the host defaulted (locked, `byDefault`) can pick again after reconnecting, because `pick()` does not check `byDefault`; the report does not list this → the owner confirms a reconnected player may change a default.
- `packages/protocol/lib/src/choices.dart:89` `ChoicesMessage` has no `byDefault` field, so a phone reconnecting after a default sees its own card as `locked: true` → confirm, or add the field in y0c.
- `docs/briefs/m17/phone1a/contract.md:22` "a picked but unlocked card counts at the timer end" is what `choice_round.dart:165` does, but the contract still lists it as an open assumption → the owner confirms.
- `packages/party_host/lib/src/host_service.dart:144` The host now advertises `Capability.choices` before any round or phone screen exists → harmless while no round starts; confirm the order with y0d.

## Could not check
- The host's own player ("Play on this phone", "Show on this device") as a choices player: no caller in this job (review-rules A1).
- Each rule failing when broken (a mutation check): not run, the review is read-only. The runner's `tests-first ok` (`run.log:36`) shows only that the test file fails on the old code, where the class does not exist.
- The old phone getting no ChoicesEnd because `server.send` returns false (`host_server.dart:219`, gate at `:232`): read by grep, not traced.
- `dart analyze`, `dart format` and the tests were not run here; only the 120-column scan was done with grep.
- `docs/protocol.md` not checked (this job touched no docs).

## Commit message
docs: review of phone1a wave 2 (y0b ChoiceRound) findings

Review only: records the findings on the y0b ChoiceRound host side
(dispose untested, use after dispose, real-time grace tests, missing
part A self-check, no pause owner yet) and the decisions to confirm.
No code or test changed.

## Status row
phone1a y0b review: needs Claude. Open: dispose test (must), after-dispose guard, real-time grace tests, 120-column line, part A self-check, pause owner before y0d.

## Delete
- none
