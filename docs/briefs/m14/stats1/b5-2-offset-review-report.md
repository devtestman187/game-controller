# Review of M14 stats1 b5-2-offset

## Summary

Verdict: **small fixes** (1 must, 3 should, 3 could).

- Re-ran the evidence: `dart test test/round_offset_test.dart` in `packages/metrics` → 11 passed; `flutter test` for `round_offset_recorder_test` → 3, `round_stats_test` → 4, `live_stats_fixes_test` → 3 passed; `tools/review.sh --base 8b32bb5` → 0 fail, 3 note. The two new test files do test the new behaviour.
- The change does what the brief asks: `startS` is written from `atMs`, omitted when unknown, clamped at 0, cleared on both end paths; `SessionRecorder` is the only production caller of `roundStarted` and it passes `host.nowMs`; `start_s` is appended last.
- Most important: `round_frames_test.dart:62` was loosened from `endsWith(',players,frames_drawn,frames_late,fps')` to `contains(...)` (and renamed) to let the new column pass, and that edit is not in the report's Files changed.
- Second: `session.dart:237` `roundEnded` is now 43 body lines, over the ~40 limit, and the report dismisses the note as pre-existing "50 lines before" — review.sh counts the body, which was 40, so this job took it over.
- Third: the new `1000` at `session.dart:207` is reported by review.sh on that added line; the report files it as "unchanged".
- `docs/dev-tools.md:343` still describes the rounds CSV as 16 columns ending `fps`; the code writes 17 ending `start_s` (docs were outside `allow:`, so this is a gap to schedule, not a job error).
- The offset is not read by any table yet, and `summarySchema` staying 1 is right: old summaries parse and old callers write no `startS` (both tested).

## Findings

- **must** packages/metrics/test/round_frames_test.dart:62 the header check went from `endsWith(',players,frames_drawn,frames_late,fps')` to `contains(',players,frames_drawn,frames_late,fps')` and the test was renamed, so it no longer pins the order or that nothing follows `fps`, which coding-guidelines §2 "weakened checks" rejects and the report's Files changed does not mention → assert `endsWith(',players,frames_drawn,frames_late,fps,start_s')` and keep the test name about the whole tail.
- **should** packages/metrics/lib/src/session.dart:237 `roundEnded` is 43 lines of body now against §3's "about 40 at most", and the report calls the note pre-existing ("the function was 50 lines before it"), but review.sh measures the body, which was 40 lines and under the limit before this job added three lines → move the round-map construction (session.dart:246-263) into a private helper and correct that line of the report.
- **should** packages/metrics/lib/src/session.dart:207 the new `1000` in `_sinceStartS` is a bare ms-to-s divisor, which §2 magic numbers rejects, and the report lists the review.sh note as "numeric literal 1000 (unchanged)" though review.sh reports added lines only and prints it at 207 → divide by `Duration.millisecondsPerSecond` (or a named `_msPerS` constant as record_text.dart:41 does).
- **should** docs/dev-tools.md:343 the rounds CSV is documented as 16 columns ending `fps`, while `roundsCsvHeader` (report_rounds.dart:159-161) now writes 17 ending `start_s` → put `docs/dev-tools.md` in a later job's `allow:` and update that sentence (the job could not, §10 docs match code).
- **could** packages/party_host/test/round_stats_test.dart:20 the `rounds()` helper deletes `startS` from every round it hands to an assertion, so this file cannot notice a missing or wrong offset from the recorder → give `SessionRecorder` an injected `nowMs` and assert the exact value instead of stripping it.
- **could** packages/party_host/test/round_offset_recorder_test.dart:40 the `61.5` assertion leans on the real `ServerGameHost` clock (server.nowMs) moving under 50 ms between `startSession` and the record → the injected clock in the finding above removes the assumption.
- **could** packages/party_host/test/round_offset_recorder_test.dart:76 this new test passes on the old code too, since a round with no `round_start` also has no `startS` there → keep it as the absence guard the brief asked for, but it adds no proof of the new behaviour beyond the two tests above it.

## Decisions to confirm

- Clamp to 0 (Decision 2): safe, and no reader can be handed a negative; the cost is that a backwards host clock and a round at the session's start both read `0.0`, so the two cannot be told apart later.
- One decimal in the JSON (Decision 5): consistent with `_startS` and `timeS` in the CSV; the tenth is lost for good in the summary, so a later finer-grained timeline would need a new key.
- `start_s` after `fps` (Decision 4): no code reads the rounds CSV by position (only `docs/dev-tools.md:343` describes it), so appending is safe.
- Stripping `startS` in `round_stats_test` (Decision 3): it does keep that suite green and deterministic, but it is the one place where the recorder's real clock is hidden rather than injected (see the `could` findings).
- Not listed as a decision but made: `round_frames_test`'s header check was loosened and its name changed, which the report's Files changed does not mention (the `must` above).

## Could not check

- The report's full-suite counts (metrics 145, host 466): I ran the new files plus `round_stats_test` and `live_stats_fixes_test` only.
- The report's "failed 2/3 on the old code" for `round_offset_recorder_test`: inferred from the old `roundStarted({int? hz})` and the old recorder, not run against the old commit.
- Whether the `61.5` and `0.0` recorder tests ever flake on a loaded CI machine: they depend on the real clock moving under 50 ms, which I cannot measure here.
- Nothing on a phone host or a device: no app was started.

## Commit message

```
docs: review of b5-2-offset, the round start offset

Read the change against the guidelines, the review rules and its brief,
and re-ran the evidence: round_offset_test 11, round_offset_recorder_test
3, round_stats_test 4, live_stats_fixes_test 3 passed; review.sh 0 fail
/ 3 note. Small fixes, one must: round_frames_test's header check was
loosened from endsWith to contains and the edit is not in the report.
roundEnded is 43 body lines (the report says it predates the job) and the
new 1000 at session.dart:207 is this job's; docs/dev-tools.md still lists
the old 16-column rounds CSV.
```

## Status row

M14 stats1 b5-2-offset: reviewed — verdict small fixes (1 must, 3 should, 3 could), evidence re-runs green (metrics 11, host 10, review.sh 0 fail / 3 note); open: the loosened header check in round_frames_test, `roundEnded` over 40 lines, the bare `1000`, `docs/dev-tools.md:343` still 16 columns.

## Delete

- none
