## Summary

- New `ChoiceRoundPausable` (packages/party_host/lib/src/night/choice_round_pausable.dart): registers with the night controller, forwards pause/resume to the round, detaches when the round closes or on `detach()`; pauses at once if the night is already paused.
- New test file with 7 tests (real HostServer, capable ControllerClient over InProcessListener, real ChoiceRound and NightFlowController). `tools/mine.sh`: ok, 7 tests pass.
- No export added to party_host.dart: no night export file lists NightFlowController (siblings are imported by path).
- tests-first: the test was written first; it failed to compile before the lib file existed.

### Computed test values
- Round 30000 ms, pause at fake clock 4000 ms: paused ChoicesMessage endsInMs = 26000. After resume with the clock moved to 19000 ms: endsInMs = 26000 (time left is frozen, not the clock).
- Grace 200 ms, wait 500 ms after a drop during pause: lockedIds empty, round open.

### Self-check
1. Host setups: in-process link, TV/phone host alike (one capable phone); old peer not covered (round-level tests in connection cover it).
2. State starts at construction (or on round start when night paused first) and ends at close/detach: tests 4, 5, 7.
3. Pause menu / dropped link / results: tests 2, 5, 6. Host away, "Get ready", player away beyond a drop: not covered.
4. Stayed inside allow.
5. No stop needed.
6. No UI.

## Decisions
- `round` and `controller` are public final fields (named initializing formals; private ones are not allowed by the analyzer here).
- Test 5 cannot see removal directly (a closed round ignores pause anyway); it checks nothing throws and the round stays unpaused. Test 7 (`detach`) proves removal on an open round.

## Questions
- None.

## Hand-over
Wiring the pausable at the build stop is M17b.

## Commit message
m17 pausewire pw1: choice round joins night pause

ChoiceRoundPausable adds a ChoiceRound to the night controller's
pausables: night pause freezes the round's timers, picks stay, phones
get paused true; resume carries on with the time left. It detaches when
the round closes. Tested with a real host, phone, round and controller.

## Status row
pw1: ChoiceRoundPausable done and tested; open: wiring at the build stop (M17b), host pause buttons.

## Delete
- none
