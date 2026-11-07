# s3d report — two corrections to the viewer's measurements (G4)

Both rules were Claude's contract, not code bugs, so this job changes the contract text and the code that follows it. Nothing on the wire changes.

## Files changed

- `packages/connection/lib/src/viewer_stats.dart` — `lateDrawMs` (25 ms) replaced by `lateFactor` = 1.5 and a private `_lateLimitMs` = `lateFactor * 1000 / hz`; `frameDrawn` now records one `touch_to_frame` sample per remembered input seq in (last acked, ack seq], in seq order, instead of only the highest one. Doc comments updated.
- `packages/connection/test/viewer_stats_test.dart` — the touch_to_frame and late-draw tests rewritten to the new rules; two new late-limit tests (20/30 Hz, `reset(hz:)`); the gaps and drain-cap tests unchanged.
- `packages/connection/test/client_view_test.dart` — the two tests that draw a frame now expect a sample for the pairing input as well, and one of them now waits for the state `sendInput` sends (see Q1). Names/reasons adjusted to the new rule.
- `docs/design/m12-sessions.md` §4 — the **Measurements** bullets replaced with the new rules, with a dated note (Nov 7) saying they replace the earlier ones and why.
- `packages/game_kit/test/frame_view_test.dart` — **not changed**: its only case with an ack sends one input (seq 5 at 1000, drawn at 1016), so it still yields `[16]`.

## The rules as implemented

- `touch_to_frame`: on a drawn frame whose ack seq is above `_lastAckedSeq`, for each remembered seq `s` with `lastAcked < s <= ackSeq` add `drawnAtMs - sendAtMs(s)`, sorted ascending by seq. A frame with no ack, or with an ack not above the last one, records nothing. `_lastAckedSeq` and the remembered times still carry across a drain; `reset` clears them. `drain` still thins a stage above `MetricsMessage.maxStageSamples` = 256 the same way, so a frame acking many inputs costs at most one thinned batch.
- `late`: `drawnAtMs - previousDrawnAtMs > lateFactor * 1000 / hz`, strict. `lateFactor` = 1.5, computed as 1500 / hz first so the limit is exactly 25.0 ms at 60 Hz, 50.0 at 30 and 75.0 at 20 (the brief's `lateFactor × (1000 / hz)` order gives 25.000000000000004 at 60 Hz; same verdicts for integer ms, but the exact value reads better against the doc).

## Computed values — every old → new expectation

viewer_stats_test:
1. touch_to_frame case: old inputs 1, 2, 3 at 100, 110, 120 and `frameDrawn(2, 150)` → `[40]` (only seq 2). New: inputs 5, 6, 7 at 0, 16, 33 and `frameDrawn(7, 60)` → `[60, 44, 27]` = 60−0, 60−16, 60−33.
2. same test, second ack: old `frameDrawn(3, 182)` → `[62]` (182−120). New: `frameDrawn(7, 76)` (nothing above 7) → no stage, i.e. `isEmpty`.
3. same test, unremembered seq: old `frameDrawn(5, 200)` with 4 and 5 never sent → `isEmpty` (kept in spirit). New: `inputSent(8, 50); frameDrawn(9, 80)` → `[30]` = 80−50, because 8 is remembered and 9 isn't.
4. same test, null ack: `frameDrawn(null, 216)`, old `isEmpty`, new `isEmpty` (`null` ack at 96).
5. "remembered seqs and acked seq survive a drain": send 4 at 200, draw at 240, drain → old `[40]`, new `[40]` (unchanged). Added: `frameDrawn(4, 260)` after the drain → no stage (4 is still acked). After `reset(hz: 60)`, `frameDrawn(4, 300)` → none (old and new).
6. late draws at 60 Hz: old draws 0, 16, 50 → `late` 1 (limit 25, gap 34). New: draws 0, 24, 50 → `late` 1 (24 is not > 25, 26 is). frames 3, gaps 0 both.
7. new, 20 Hz: draws 0, 60, 140, limit 75 → `late` 1 (60 not late, 80 late). New, 30 Hz: draws 0, 50, 101, limit 50 → `late` 1 (50 not late, 51 late).
8. new, `reset(hz:)`: from 60 → `reset(hz: 20)`, draws 0 and 80 → `late` 1 (80 > 75); then `reset(hz: 60)`, draws 100 and 124 → `late` 0 (24 < 25; the reset also clears the previous draw time, so the 100 counts as the first draw).
9. drain cap (1000 jitter samples → 256, first 0, elementAt(1) 3, last 996): unchanged.

client_view_test (both transports; the pairing state is remembered too, so any frame acking a later input measures it):
10. "a drawn frame measures every input it newly acks": old `[40]`; new `[state.sentAtMs + 40 - paired.sentAtMs, 40]` — 40 + the gap between the pairing state's send and the drawn input's send, then 40 for the drawn input itself. The two sends land in the same ms in these runs, so it passes as `[40, 40]`; the expression is computed from the wire values, so it holds whatever the gap.
11. "the input state the phone sends as it pairs is measured too": `[25]`, unchanged — that frame acks the pairing seq, the only input remembered.
12. "a batch a host without metrics keeps its samples": old `[40]`; new `[state.sentAtMs + 40 - paired.sentAtMs, 40]`, 42 and 40 in the runs (the two sends were 2 ms apart). Also, `state` is now the message `sendInput` sends (`firstWhere(seq > paired.seq)`, subscribed before `sendInput`) — see Q1.
13. "a phone without view sends the batch it was given": unchanged (no viewer, no stages).

frame_view_test: "touch_to_frame is the draw time minus the send time of the input the frame acks" still expects `[16]`; no other case sends an input, so no other sample list changes. kit passes unchanged.

## Line counts (before → after)

- `packages/connection/lib/src/viewer_stats.dart`: 140 → 149
- `packages/connection/test/viewer_stats_test.dart`: 107 → 137
- `packages/connection/test/client_view_test.dart`: 152 → 161
- `packages/game_kit/test/frame_view_test.dart`: 264 → 264 (unchanged)
- `docs/design/m12-sessions.md`: 198 → 198

## Test counts (before → after)

- `packages/connection`: 232 → 234 (`viewer_stats_test` 8 → 10: two new late-limit tests; `client_view_test` 9, unchanged; the gaps, drain and stage-name tests kept).
- `packages/game_kit`: 29 → 29 (`frame_view_test` 9 widget tests, unchanged).

## Checks

- `tools/check.sh format analyze connection kit`: PASS format, PASS analyze, PASS connection (234 tests), PASS kit (29 tests).
- `tools/review.sh` (job diff): 0 FAIL, 1 NOTE — `packages/connection/lib/src/viewer_stats.dart:53 numeric literal 1000`. That 1000 is ms per second, the same expression `viewer_timing.dart:109` uses (`maxPlayoutFrames * 1000 / _hz`); a `msPerS` constant would clear the note but adds public surface for a unit, so I left it.

## Questions and suggestions

1. `client_view_test`'s "keeps its samples" case used `inputs.stream.first` to get "the state sendInput sends", but the pairing state arrives at the host after the client reports `connected`, so `first` actually returned the pairing state. It only passed before because the old rule measured the highest acked seq and both cases yielded one `40` sample. I switched it to `firstWhere((s) => s.seq > pairedState.seq)`, subscribed before `sendInput`, which also lets the test assert both samples. Worth knowing if another test relies on the same call.
2. The new rule means a phone sending inputs at 60 Hz adds about one sample per input per drawn frame — up to twice the old rate at 60 Hz, and only thinned once per batch. That is what the brief asks for (every input's trip), but the host's report will see a different sample distribution than before; no thresholds that read `touch_to_frame` were changed here.
3. `sim_view.dart` and `frame_view.dart` call `frameDrawn` unchanged; no other caller of `lateDrawMs` existed, so the removal is safe.

## Commit message

```
Measure every newly acked input, and scale late draws by hz

touch_to_frame recorded one sample per drawn frame for the newest input
it acked, so at 60 Hz input rate the wait for the next frame was never
measured; it now records one sample per remembered input in (last acked,
ack seq], giving every input its trip to the screen (m12 §4).

A draw was late after a fixed 25 ms, which only fits 60 Hz; it is now
late after lateFactor = 1.5 frame intervals, so 25 ms at 60 Hz, 50 at
30 and 75 at 20. lateDrawMs goes. Tests and the §4 contract updated,
dated Nov 7.
```

## Status row

s3d done: `ViewerStats` measures every newly acked input and counts a draw late after 1.5 frame intervals; contract §4 updated — open: the phone measurement itself (step 6) on devices.

## Delete

- none
