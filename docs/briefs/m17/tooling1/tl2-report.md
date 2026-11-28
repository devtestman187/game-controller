# tl2 report: systest settle() polls for a known condition

## Summary

- **Result: the change works, but it made the systest suite slower, not faster.** Suite time went from 10 s to 18-19 s
  (two runs after the change, both 18-19 s). This is the opposite of the goal, so the job is stopped for review.
- `Systest.settle` takes an optional `done` callback. On a socket listener the real wait is polled in 2 ms slices, up
  to the same 40 ms, and ends early when `done()` is true. With no `done` the full 40 ms is still waited.
- `Systest.until` passes its `done` to `settle`. Its limit logic is unchanged. The in-process path is unchanged.
- The whole systest suite passes after the change (`All tests passed!`, 12 tests in each run).
- `tools/mine.sh`: format OK (1 file), analyze OK (1 package), no tests touched. It does not run the systest suite,
  so the suite numbers come from my own `flutter test packages/party_host/test/systest` runs.

## Timings (`flutter test packages/party_host/test/systest`, Windows, same machine)

| Run | Wall time reported by flutter |
|---|---|
| Before the change | 00:10 (All tests passed) |
| After, run 1 | 00:19 (All tests passed) |
| After, run 2 | 00:18 (All tests passed) |

## Files changed

- `packages/party_host/test/systest/systest_support.dart`: `settle` takes `done`; the 40 ms socket wait is now
  `_waitForSocket`, a 2 ms poll with the constants `_socketWait` and `_socketPollSlice`; `until` passes `done` to `settle`.

No other file was changed. The two systest test files were not touched, since the suite passed.

## Decisions

- **Signature.** The brief's `do` item gives `settle([Duration time, bool Function()? done])`, a positional optional
  parameter. The brief's `changes` line says "named parameter". I followed the `do` item, since it is the exact code.
  If a named parameter is wanted, it is one line to change, and the callers would need `done:`.
- **Slice size.** I used the 2 ms slice the brief names, with no tuning.
- **Constants.** The 40 ms and 2 ms are named constants, with the no-`done` behaviour in the doc comment.

## Why it is slower (not measured, a likely cause)

With no `done` (most `settle` calls), the old code made one `Future.delayed(40 ms)`. The new code makes 20
`Future.delayed(2 ms)` calls in a row. If each small delay takes much longer than 2 ms on this Windows machine, which
is common because of timer granularity, each socket `settle` now costs several times 40 ms. That fits the suite going
from 10 s to 18-19 s. I did not measure timer granularity, so this is a guess that fits the numbers.

## Self-check (review-rules part A)

1. Host setups: this is test support only; the systest suite (which covers the TV and phone host setups) passes.
2. Kept state: none added. `settle` and `_waitForSocket` hold no state across calls.
3. Combination with other states: `until` and `settle` only change how long the real wait lasts; the clock pump is
   unchanged, so the pause menu, the away states, and the results are not affected. The suite passes.
4. Files: only `systest_support.dart` was edited.
5. Stop: none needed.
6. Looks: no UI or look code touched.

## Questions and suggestions

1. Should the slice stay at 2 ms? On this machine 2 ms polling is slower than one 40 ms wait. Options to try: a single
   `Future.delayed(40 ms)` when `done` is null (exactly the old timing), and a larger slice (for example 10 ms) when
   `done` is given. Which should I try?
2. Should `settle` use the named `done:` parameter the `changes` line describes, not a positional one?
3. Is there a faster real-time wait that a test can use instead of a timer, for example the socket's own ready event,
   so the wait would end as soon as the reply arrives?

## Hand-over

The change is in `systest_support.dart` and passes the suite, but it makes the suite about 8-9 s slower on this
machine. Do not merge it as a speed-up. It needs question 1 settled first.

## Commit message — a draft

Systest settle: poll for a known condition instead of a fixed 40 ms

settle() now takes an optional done callback. On a socket listener the real wait is polled, and ends early once
done() holds; with no callback it waits the full 40 ms as before. until() passes its condition through.
Note: on Windows the 2 ms poll slices make the systest suite slower (10 s to about 18 s), so this needs a tuning
change before it is a speed-up.

## Status row

tl2 (systest settle): the done-aware settle and until are in, and the systest suite passes; the speed-up is not
achieved: the suite is slower (10 s to 18-19 s) with 2 ms poll slices. Open: choose the slice or the no-callback path
(question 1).

## Delete

- none
