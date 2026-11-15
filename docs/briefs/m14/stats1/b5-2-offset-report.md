# M14 stats1 b5-2-offset: each round records how far into the session it began

## Summary

Every round now says when in its session it began. `SessionCollector.roundStarted` takes an optional
`atMs` (the host's clock, the one `startMs` is from) and `roundEnded` writes `startS` — seconds from the
session's start, to one decimal, never negative — into the round JSON only when a start was recorded.
The rounds CSV gains `start_s` at the very end of the header, blank when a round has none.
`session_recorder.dart` passes `host.nowMs` on `round_start`; `live_stats.dart` is untouched (it already
builds the session with `startMs: host.nowMs`, so the two clocks agree).

Tests first: both new files were written and run before the code changed.
- `packages/metrics/test/round_offset_test.dart` (11 tests) failed to load on the old code
  (11 `No named parameter with the name 'atMs'` errors), now 11/11 pass.
- `packages/party_host/test/round_offset_recorder_test.dart` (3 tests) failed 2/3 on the old code
  (`startS` absent from the round); now 3/3 pass. The third test ("a round the game wrote no start for
  has no offset") passes on old and new code by design — it guards the absence.

Decisions at a glance (details below): the offset is worked out in `roundStarted`; a value before the
session's start reads 0; `round_stats_test` drops `startS` before comparing because its clock is real;
`start_s` goes after `fps`; one decimal, like `timeS`.

Not done: nothing in `docs/` (not in `allow:`) — `docs/dev-tools.md:343` still lists the old 16-column
rounds CSV; no table reads `startS` yet.

## Computed test values

See the tests for the assertions:

| Case | Value |
| --- | --- |
| startMs 0, atMs 1500 | `startS` 1.5 |
| startMs 10000, atMs 12000 | 2.0 (counts from the session, not from zero) |
| startMs 10000, atMs 9000 | 0.0 (clamped, never negative) |
| startMs 0, atMs 12340 | 12.3 (12340/1000 = 12.34, to one decimal) |
| two rounds at 2000 then 5000 | [2.0, 5.0] |
| host test: session at `host.nowMs - 61500` | 61.5 |
| host test: session at `host.nowMs` | 0.0 |
| header | 17 columns, ends `,frames_late,fps,start_s` |
| old summary row (`timeS` 12.5, no `startS`) | `s1,windows,arena,60,12.5,,,,,0.14.0,,,1,,,,` (17 cells) |

## Files changed

Twelve source and test files, plus this report:
- `packages/metrics/lib/src/session.dart` (340 lines) — `_roundStartS` field, `roundStarted({hz, atMs})`,
  `_sinceStartS` helper, `'startS': ?_roundStartS` in the round, cleared on end and on abandon; doc.
- `packages/metrics/lib/src/report_rounds.dart` (256 lines) — `start_s` appended to `roundsCsvHeader`,
  `_startS` cell helper, doc.
- `packages/party_host/lib/src/session_recorder.dart` — `atMs: host.nowMs` on `round_start`.
- `packages/metrics/test/round_offset_test.dart` — new, 11 tests (offset, rounding, clamp, absence,
  increasing offsets, abandoned reset, CSV header/cell/old summary).
- `packages/party_host/test/round_offset_recorder_test.dart` — new, 3 tests (recorder stamps the host's
  clock; a round at the session's start reads 0; no start → no offset).
- `packages/party_host/test/round_stats_test.dart` — `rounds()` drops `startS` before comparing (see
  decision 3).
- Seven existing metrics CSV tests (`csv_app_comma`, `csv_app_version`, `report_games`, `report_rates`,
  `report_two_hosts`, `round_frames`, `round_winner_csv`) — trailing empty `start_s` cell added to the
  expected rows and 16 → 17 columns; `round_frames_test`'s `sublist(13)` became `sublist(13, 16)`.

## Decisions

1. The offset is worked out in `roundStarted` from `atMs`, not in `roundEnded`: the round began then,
   and `roundEnded` already takes ten parameters.
2. Clamp to 0 rather than dropping a negative: a host clock that ran backwards (or a bad `atMs`) then
   reads as the session's start instead of a value the readers would have to guard against.
3. `round_stats_test.dart` strips `startS` in its one `rounds()` helper: the host's clock there is a real
   `Stopwatch`, so the value moves between runs, and the exact values are covered by the two new files.
4. `start_s` after `fps`, as the brief says ("appended at the END"): no reader indexes past `fps` today.
5. One decimal, like `timeS` in the CSV, so the JSON and the CSV never disagree on the digit.

## Checks

- `tools/check.sh format analyze metrics host`: PASS format (3 s), PASS analyze (9 s), PASS metrics
  (145 tests: 134 before + 11 new), PASS host (466 tests: 463 before + 3 new).
- `tools/review.sh`: 0 fail, 3 note — `session.dart` 340 lines (aim 300, limit 400); `session.dart`
  numeric literal 1000 (unchanged); `roundEnded` 50 lines (>40). The last one predates this job (the
  function was 50 lines before it) and the review only reports it now because a changed line falls
  inside it.
- `live_stats.dart` is not in the diff; the B-019 pause/resume tests all pass
  (`live_stats_test`, `live_stats_fixes_test`, `live_stats_lifecycle_test`).

Self-check (review-rules.md part A):
1. Every host setup: unchanged — the offset is a session field, not a host type; all five `HostType`
   tests pass (`host_type_test`, metrics 145 green).
2. Kept state: `_roundStartS` starts at `roundStarted`, is read at `roundEnded`, and is cleared on both
   the recorded and the abandoned path (`round_offset_test`, "an abandoned round's start is not carried
   into the next round").
3. Combining states: nothing new to combine — the offset is cleared with `_roundHz`, so two rounds in a
   row and an abandon-then-round are both covered by `round_offset_test`.
4. Stay in the folder: only files under `allow:` were written.
5. Stop rather than overstep: nothing outside `allow:` was needed. `tv_test_app/windows/flutter/`
   generated files show as modified in `git status`; they were already dirty at 09:55, before this job
   started, and were not touched here.

## Hand-over

- The offset is per session: a paused session (B-019) ends and the next one starts at 0, which is what
  `startMs: host.nowMs` in `live_stats.dart` already gives, so no change was needed there.
- `summarySchema` stays 1: `startS` is an optional round key, like `tags` and `framesDrawn` before it;
  summaries without it still parse (tested through `csvRounds`).
- `docs/dev-tools.md:343` still lists the rounds CSV as 16 columns ending `fps`; it is 17 now, ending
  `start_s`. That file was not in `allow:`.
- Nothing reads `startS` yet: a per-round timeline table (or "first round after N minutes") is the
  obvious next step.

Questions:
1. `round_offset_recorder_test` asserts 61.5 exactly; it leans on the real `ServerGameHost` clock moving
   less than 50 ms between the session's start and the record. A clock injected into `SessionRecorder`
   (`nowMs` in its constructor) would remove the assumption — say if you want it in a later job.
2. Is stripping `startS` in `round_stats_test.dart` acceptable (decision 3), or would you rather those
   tests assert `'startS': 0.0` with the session started at `host.nowMs` and take the small flake risk?
3. `start_s` sits after `fps` as the brief says. If you'd rather it sat next to `time_s` (columns are
   read by name in the report, by eye in a spreadsheet), a later job can move it before it ships.

## Commit message

Round start offset in every round's stats (M14 stats b5-2)

`SessionCollector.roundStarted` takes an optional `atMs` and the round
keeps `startS`: seconds from the session's start, to one decimal, never
negative, and left out when no start was recorded, so old summaries and
old callers still parse. `SessionRecorder` passes `host.nowMs` on
`round_start`, and the rounds CSV gains `start_s` at the end of the
header, blank when a round has none. Nothing reads the offset yet;
`live_stats.dart` is unchanged.

## Status row

Rounds now record their start offset from the session start (metrics + host recorder + rounds CSV
`start_s`), tested; open: docs/dev-tools.md still lists the old 16-column rounds CSV, and no table reads
`startS` yet.

## Delete

- none
