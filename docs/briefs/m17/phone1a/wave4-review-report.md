# Review of wave 4 (f1a): ChoiceRound constructor regrouped

## Summary
- Verdict: small fixes
- Counts: must 0, should 1, could 1
- 1. Self-check line 3 claims the existing tests cover "pause" paths; ChoiceRound has no pause (see finding 1).
- 2. The code matches the brief: 4-parameter constructor, both value objects exported, two call sites changed, behaviour unchanged.
- 3. Two public types share one file (ChoiceRoundSetup, ChoiceTiming); the brief asked for it, but the report does not list it as a decision (see Decisions to confirm).

## Findings
- **should** docs/briefs/m17/phone1a/f1a-report.md:34 Self-check 3 says the existing tests cover "the pause/away/grace/close paths", but `choice_round.dart` has no pause logic (no "pause" in that file) and the tests named at `choice_round_test.dart:196`, `:209` and `:264` cover away, grace, close and dispose only → rewrite the line to name the pairs that are tested (away + close, away + dispose) and say that pause is owned outside this class.
- **could** packages/connection/lib/src/choice_round_setup.dart:7 The constructor dartdoc says what it does ("Groups what a round shows…") and not why; guideline §3 wants comments that say why → reword to say why the values are grouped (so one round's setup is passed as one value), or leave as is.

## Decisions to confirm
- `packages/connection/lib/src/choice_round_setup.dart:5` and `:33`: two public types in one file. Guideline §3 allows this only for small types that make sense together; `ChoiceTiming` is independent of `ChoiceRoundSetup`, so confirm this, or split it into a second file. The brief asked for one file, so this is not hidden.
- The three getters `cardsFor`, `defaultId`, `currency` stay on `ChoiceRound` (`choice_round.dart`, the getters after the constructor docs), so `choice_fallback.dart` is unchanged. Brief-driven; listed in the report.

## Could not check
- No runner evidence for f1a: `docs/briefs/m17/phone1a/run.log` and `run-findings.md` have no f1a entry, so the 431-test result in `f1a-report.md:25-27` and the "exempt" tests-first claim are the worker's words only.
- Tests were not run (read-only job). The diff is a constructor regroup; the existing tests in `choice_round_test.dart` and `choice_fallback_test.dart` are the only evidence of unchanged behaviour, and they are not new.
- Line lengths over 120 were checked by search in the changed files: none found. Line counts: `choice_round.dart` 218 lines, `choice_round_setup.dart` 45 lines (both within the limits).
- `choice_round_state.dart` (unchanged) was searched for the moved names (`round`, `title`, `cardsFor`, `duration`, `grace`, `nowMs`, `defaultId`, `currency`): only doc-comment hits, no reads of the moved fields.
