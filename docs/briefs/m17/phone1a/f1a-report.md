# phone1a f1a: ChoiceRound constructor takes value objects

## Summary

Done. `ChoiceRound.new` now takes four parameters (`server`, `players`, `setup`, `timing`), which meets the
at-most-5 rule in docs/coding-guidelines.md:43. The old nine-parameter constructor is gone. No behaviour change.

Files changed:
- `packages/connection/lib/src/choice_round_setup.dart` (new): `ChoiceRoundSetup` (`round`, `title`, `cardsFor`,
  `defaultId`, `currency`) and `ChoiceTiming` (`duration`, `grace`, `nowMs`), each field keeps its dartdoc line.
- `packages/connection/lib/src/choice_round.dart`: the constructor is `ChoiceRound({required server, required players,
  required setup, required timing})`. The getters `cardsFor`, `defaultId`, `currency` stay (they forward to `setup`),
  because `choice_fallback.dart` uses them. Every other read is now `setup.` or `timing.`. The dartdoc on
  `[grace]` now reads `[ChoiceTiming.grace]`, since that name no longer exists on the class.
- `packages/connection/lib/connection.dart`: exports `ChoiceRoundSetup` and `ChoiceTiming` next to `ChoiceRound`.
- `packages/connection/test/choice_round_test.dart`: the one constructor call (`_setup`) now builds the two value
  objects. Nothing else in the file changed.
- `packages/connection/test/choice_fallback_test.dart`: the one constructor call (`_roundFor`) changed the same way.

Not changed: `choice_round_state.dart` (a `part` file, nothing in it reads the moved fields), `choice_fallback.dart`,
the wire messages.

Checks:
- `tools/mine.sh`: run twice. First run formatted 5 files (the formatter reflowed the long `ChoicesEndMessage` line
  in `choice_round.dart`). Second run: `OK 431 tests packages/connection`, `RESULT: ok: 5 file(s) formatted,
  1 package(s) analyzed, 1 package(s) tested`. The 431 tests are the whole connection package, which includes
  `choice_round_test.dart` and `choice_fallback_test.dart`. I did not run the two files separately.
- Tests-first: exempt, refactor. The tests pin the behaviour; only their constructor calls changed.

Self-check (review-rules part A):
1. Host setups: this is the host-side class only; `choice_round_test.dart` covers the TV/PC host path and
   `choice_fallback_test.dart` covers the old-phone fallback. No other setup is affected by a constructor change.
2. Kept state: unchanged. The timers, `_picks`, `_outcomes` start and end exactly as before.
3. Combinations: unchanged, since no logic moved. The existing tests cover the pause/away/grace/close paths.
4. Stayed inside `allow:`: yes. The new file is in the allowed `src/` path.
5. No stop needed.
6. Look: no UI touched.

## Decisions
- `ChoiceRoundSetup` and `ChoiceTiming` are standalone files, not `part` files: `connection.dart` exports them, and
  `ChoiceRound`'s public constructor needs them visible to callers.
- The getters for `cardsFor`, `defaultId`, `currency` are kept on `ChoiceRound` rather than changing
  `choice_fallback.dart` (out of scope).
- `ChoiceRoundSetup` and `ChoiceTiming` each have a short constructor dartdoc.

## Hand-over
- Nothing open in this job.
- Suggestion (not done): the `_connected` / `_awayTimers` bookkeeping could also move into a small class, but that
  is a separate change and was not asked for.

## Commit message — a draft

connection: group ChoiceRound's constructor into setup and timing

ChoiceRound took nine parameters; the guideline allows five. Its round
setup (round, title, cardsFor, defaultId, currency) now sits in
ChoiceRoundSetup, and its timing (duration, grace, nowMs) in ChoiceTiming.
The constructor is now server, players, setup and timing. No behaviour
changes; the wire messages keep their flat fields.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

M17 phone1a f1a: ChoiceRound constructor regrouped into ChoiceRoundSetup and ChoiceTiming (4 parameters), behaviour
unchanged, 431 connection tests pass. Open: the other review findings, which are not in this job.

## Delete

- none
