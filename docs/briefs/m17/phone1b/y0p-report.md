# y0p report: ChoiceRound pause() and resume()

tests-first: exempt new methods with no earlier behaviour; the new test file is the first test.

## Files changed
- packages/protocol/lib/src/choices.dart: `ChoicesMessage.paused` (default false, written only when true, optional bool read, in == and hashCode).
- packages/protocol/test/choices_codec_test.dart: one case, paused round trip, old payload reads false.
- packages/connection/lib/src/choice_round.dart: `isPaused`, `pause()`, `resume()`; a drop while paused starts no away timer; `_sendState` carries `paused` and the frozen time left; `close()` clears the pause.
- packages/connection/test/choice_round_pause_test.dart (new): the nine pause tests, per transport.

## Checks
tools/mine.sh: ok (connection 18 tests, protocol 18 tests, analyze clean). choice_round.dart is 279 lines.

## Computed test values
- Pause state: clock at 4000 ms of a 30000 ms round, so endsInMs 26000 on the paused and the resumed message, even with the clock moved to 8000 during the pause.
- Resume timing: 3000 ms round paused with 300 ms left; closes within 1500 ms of resume (full length would be 3000).
- Grace: after resume no default at 100 ms; the default comes after more than 100 ms (grace 300 minus 2 x 100 margin).

## Self-check
1. Host setups: capable phone and old phone in the test setup; the old phone gets no ChoicesMessage (state test). TV or PC host, "Play on this phone" and "Show on this device" are not in scope here.
2. Kept state starts at pause(), ends at resume() or close() (close test, "after close" test); nothing going on: pause before start, twice, after close do nothing.
3. Pause menu, host away, "Get ready", results: the night controller wires these (B4 n1g). Dropped link: drop and reconnect tests. Leaving: close while paused.
4. Stayed inside allow.
5. No stop needed.
6. No look involved.

## Questions
- `resume()` starts a grace timer for every player who is not connected, including one already defaulted before the pause. The default is re-applied (the same value), which would overwrite a host pick() made in between. I followed the brief.
- Tests use real short timers, so the timing margins (100 ms, 1500 ms) could flake on a very slow machine.

## Commit message
m17 phone1b y0p: ChoiceRound pause and resume

ChoiceRound.pause freezes the end timer and the away timers and keeps
the time left; resume restarts the end timer and gives every absent
player a full grace. ChoicesMessage.paused tells the phone (written
only when true, no protocol version change). A drop while paused
starts no away timer; picks and close still work.

## Status row
y0p done: ChoiceRound pause/resume, ChoicesMessage.paused, tests; open: night controller wiring (B4 n1g), phone UI for paused.

## Delete
- none
