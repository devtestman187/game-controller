# night1b n1c report: cap a night at 5 rounds

## Summary

- `nightRoundCap = 5` added in `night_state.dart` with a doc comment: nights stay at 5 rounds until about 15 game variants exist, so 8 rounds stays unavailable.
- `NightLength` const constructor asserts `rounds <= nightRoundCap`. Shipped lengths stay 3 and 5.
- `NightFlow.start` asserts `rounds > 0 && rounds <= nightRoundCap` with a message naming the cap. `night_flow.dart` now imports `night_state.dart` (same folder, no layer change).
- New test file `night_round_cap_test.dart` with 5 tests (see below).
- No change to NightFlow's events or stages, no UI change, no new length.

Tests: `tools/mine.sh` returned `OK 42 tests packages/party_host` and `RESULT: ok: 3 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`. Analyze on the package reported no findings.

Tests-first: the new test file references `nightRoundCap`, which does not exist on the base, so it cannot compile there. I did not run it on the base (git commands that change state are not allowed for me); the runner's check is what proves that.

## Files changed

- `packages/party_host/lib/src/night/night_state.dart`: added `const nightRoundCap = 5;` with doc; added `assert(rounds <= nightRoundCap, ...)` to the `NightLength` constructor. 348 lines (under 380).
- `packages/party_host/lib/src/night/night_flow.dart`: added `import 'night_state.dart';`; `NightFlow.start` assert now `rounds > 0 && rounds <= nightRoundCap`, message `'a night plays 1 to $nightRoundCap rounds'`. 312 lines.
- `packages/party_host/test/night_round_cap_test.dart`: NEW. Tests:
  1. every `NightLength` has rounds in `1..nightRoundCap` (checks each value against 1 and 5).
  2. `NightLength.values` rounds are exactly `[3, 5]`.
  3. no `NightLength` has 8 rounds.
  4. `NightFlow.start(5)` gives stage setup, round 0, rounds 5.
  5. `NightFlow.start(8)` throws `AssertionError`.
- `docs/briefs/m17/night1b/n1c-report.md`: this report.

## Self-check (review-rules part A)

1. Host setups: not applicable, no UI or host wiring changed (covered by the unchanged suite run by the runner).
2. Kept state: none added; the cap is a compile-time constant.
3. Combinations: not applicable, no state or flow change.
4. Stayed inside `allow:`: yes, four files only.
5. Stop: none needed.
6. Looks: not applicable, no UI.

## Decisions

- The `NightLength` assert message is built from the constant, so it stays correct if the cap changes.
- The `start` assert keeps the existing message's wording style ("a night plays ...").

## Questions

1. The brief names `NightLength` as a const-constructor assert, and `NightFlow.start` as an assert too. Both now check the cap. Is a second check in `start` wanted, or should `start` rely only on `NightLength`? I kept both, as the brief says.

## Suggestions

- When the variant count reaches about 15, bump `nightRoundCap` and add an 8-round `NightLength` in the same change; the test at item 3 will then need updating on purpose.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 night1b n1c: cap nights at 5 rounds

Add nightRoundCap = 5 in night_state.dart and assert it in the
NightLength constructor and in NightFlow.start, so an 8-round night is
refused until about 15 game variants exist. The shipped lengths stay 3
and 5. New night_round_cap_test.dart pins the cap, the lengths and the
start assert.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

n1c done: nightRoundCap = 5 asserted in NightLength and NightFlow.start, 8 rounds unavailable, pinned by night_round_cap_test.dart. Open: raise the cap when about 15 variants exist.

## Delete

- none
