## Summary

Review findings 1, 3 and 4 of `docs/briefs/m14/stats1/REVIEW.md` are fixed; nothing else was
touched. `live_stats.dart` is unedited (it is at the 380 cap).

- `SessionRecorder` takes an optional `int Function()? nowMs` (default: `host.nowMs`), so the
  app is unchanged. `round_start` stamps `_now` and the rating prompts read the same clock.
- New `packages/party_host/test/round_offset_clock_test.dart` runs three rounds on a fake
  clock: offsets **0.0, 61.5, 125.0**, plus 13340 ms → **12.3** for the tenth rounding.
- `round_offset_recorder_test.dart` lost its two real-clock tests: it now proves the offset is
  the clock at `round_start` (session 20 s old, clock then moves 60 s, offset stays **20.0**)
  and that a round with no `round_start` has no `startS`.
- `round_stats_test.dart` no longer strips `startS`: the recorder's clock is fixed at 61500 ms
  with the session at 0, so each played round asserts `'startS': 61.5`.
- `round_frames_test.dart` is back to
  `endsWith(',players,frames_drawn,frames_late,fps,start_s')`, keeping the 17-column count.
- `_sinceStartS` divides by `Duration.millisecondsPerSecond`.

Tests: before the change the new file failed to load (1 failing: "No named parameter with the
name 'nowMs'"); after it, 2 + 6 party_host round tests pass, metrics 145 pass, host 467 pass.
`tools/review.sh`: 0 fail, 2 notes, both pre-existing (`session.dart` size 341, `roundEnded`
body at :238 — review finding 5, not this job's).

## Files changed

- `packages/party_host/lib/src/session_recorder.dart` — added the `nowMs` parameter,
  `_injectedClock` and the `_now` getter; `round_start` and the rating prompts read `_now`.
  160 lines.
- `packages/party_host/test/round_offset_clock_test.dart` — new: the injected-clock offsets.
- `packages/party_host/test/round_offset_recorder_test.dart` — fake clock, two non-duplicate
  cases (stamp at start, no start ⇒ no offset).
- `packages/party_host/test/round_stats_test.dart` — fake clock at 61500 ms; exact `startS`.
- `packages/metrics/lib/src/session.dart` — named ms-to-s divisor. 341 lines (cap 380).
- `packages/metrics/test/round_frames_test.dart` — header check back to `endsWith` + `start_s`.
- `docs/briefs/m14/stats1/fix2-tests-clock-report.md` — this report.

## Test values

| Case | Clock | Session start | `startS` |
|---|---|---|---|
| First round of the clock test | 1000 | 1000 | 0.0 |
| Second round | 62500 | 1000 | 61.5 |
| Third round | 126000 | 1000 | 125.0 |
| Tenth rounding | 13340 | 1000 | 12.3 |
| Recorder test: start stamp | 900000 | 880000 | 20.0 (still 20.0 after +60 s) |
| `round_stats_test` rounds | 61500 | 0 | 61.5 |

## Decisions

1. Both party_host test files are kept: the brief asks to drop the real-clock assertions, not
   the file, and each file now asserts values the other does not.
2. The clock is a nullable field plus a `_now` getter, because an initializer list cannot read
   `this.host` to default from it, and `late` is not allowed to dodge that.
3. The rating scheduler reads `_now` too: one recorder, one clock, and the default is still the
   host's clock, so nothing changes for the app.
4. `round_stats_test` uses 61.5 rather than 0.0, so even a clock that reads zero would fail.
5. Constructor keeps 5 parameters (at the guideline limit) instead of a value object, since
   only one is added and the brief asks for exactly this injection.

## Questions

1. Findings 2, 5–8 need files outside this job's allow list (docs, `session.dart` shape,
   milestone `STATUS.md`, code-health); confirm they are for a later fix job.
2. `SessionRecorder` is at 5 parameters now; a sixth would need a value object — should the
   fix batch before the recorder grows further do that?

## Suggestions

- Make `_now` the only clock read in `SessionRecorder`, and say so in the class doc, so the
  next record type does not reach for `host.nowMs` again.
- The two docs that give the rounds CSV as 16 columns ending `fps` (review finding 2) are one
  line each; they could ride along with the next docs-allowed job.

## Hand-over

- Clock seam: inject `nowMs`; every stamp in `SessionRecorder` reads `_now`.
- `SessionRecorder`: host, session, log, random, nowMs (5 parameters, the limit).
- Still open from the run review: CSV docs 16→17 columns (2), `roundEnded` value object and
  body split (5), `run-base` (6), milestone `STATUS.md` line (7), code-health rows (8).

## Commit message

stats1 fix2: inject the recorder's clock and exact round offsets

- SessionRecorder takes an optional nowMs (default host.nowMs); round_start and the
  rating prompts read it, so LiveStats is unchanged.
- New round_offset_clock_test.dart pins round offsets 0.0, 61.5, 125.0 and 12.3 on a fake
  clock, with no real time.
- round_offset_recorder_test.dart drops the real-clock assertions; round_stats_test.dart
  asserts 'startS': 61.5 instead of stripping it.
- round_frames_test.dart's header check is endsWith(...,fps,start_s) again (review 1).
- session.dart's _sinceStartS divides by Duration.millisecondsPerSecond (review 4).

## Status row

M14 stats1 fix2: review findings 1, 3 and 4 fixed (recorder clock injected, exact offset
tests, CSV header check, named ms-to-s divisor); open: review findings 2 and 5–8 (CSV docs,
roundEnded shape, run-base, milestone STATUS.md, code-health rows).

## Delete

- none
