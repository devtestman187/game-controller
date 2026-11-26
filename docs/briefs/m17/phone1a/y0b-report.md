# phone1a y0b report

tests-first: exempt new class with no earlier behaviour; its new flow test is the first test.

## Files
- packages/connection/lib/src/choice_round.dart: new `ChoiceRound` (start, pick, close, dispose, lockedIds, outcomes, changes).
- packages/connection/lib/src/choice_round_state.dart: part with `ChoiceOutcome` and the private stored pick.
- packages/connection/lib/connection.dart: exports ChoiceRound, ChoiceOutcome.
- packages/connection/test/choice_round_test.dart: new tests on both transports (WirePhone capable `[choices]` and old `[]`).
- packages/party_host/lib/src/host_service.dart: `Capability.choices` added to the capabilities list.

## Checks
tools/mine.sh: ok (format, analyze, connection 400 tests, party_host 1 test).

## Computed test values
- endsInMs at start = 30000 (round duration, fake clock 0); after fake clock 4000 the resend shows 26000.
- Count clamp: build maxCount 3: count 9 gives 3, count 0 gives 1.
- Null defaultId outcome: cardId null, count 0, byDefault true.

## Decisions (small, flagged)
- A player away for grace overwrites any stored pick with the default (locked, byDefault); with a null defaultId the pick is removed (outcome is the abstaining default).
- Outcome count for a null card is 0 (ChoicesEnd count is required).
- A pick cleared with null removes the stored pick (falls back to the default at close).
- Away is judged from `HostServer.changes` transitions (connected to not connected); players not connected at start() get a grace timer at once.
- The old phone gets no ChoicesEnd (server.send returns false); it still has an outcome in the map.
- Timer test and grace tests use short real timers (100/200 ms); the clock for endsInMs is injected.

## Questions
1. Should a dropped player's earlier unlocked pick be replaced by the default (done), or kept?

## Suggestions
- none

## Commit message
m17 phone1a y0b: ChoiceRound host round for the choices screen

ChoiceRound sends the round only to phones that list Capability.choices,
takes picks (undo until the timer ends), resends on reconnect, gives
the default to players who chose nothing or stayed away for the grace
time, and ends once with ChoicesEnd. The host welcome now lists
Capability.choices.

## Status row
phone1a y0b: ChoiceRound host side and host capability done with tests; no phone lists the cap yet (y0c fallback, y0d UI open).

## Delete
- none
