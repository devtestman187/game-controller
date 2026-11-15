# a3 round frames — report

## Summary

Per-round frame counts now exist, and the rounds CSV shows them.

- `SessionCollector.frames()` puts the first frames record that follows a
  round's end into that round as `framesDrawn` / `framesLate`, and keeps the
  session totals as before (M14 a3). A round added by `roundEnded` sets a flag;
  the next `frames()` uses it up; the next `roundEnded` clears it. An abandoned
  round adds no round and clears the flag, so its frames stay session totals, as
  do those of a round the 1000-round cap drops.
- The rounds CSV ends with `frames_drawn,frames_late,fps`: the fps is
  `framesDrawn / timeS` to one decimal (3000 frames in 60 s → `50.0`), and is
  blank when the round kept no frames or `timeS <= 0`. Rounds from before the
  key leave all three cells empty, so old summaries stay valid.
- **Puzzle rounds get frames too** (brief item 4): `puzzle_report.dart:83`
  records `frames` right after its `round_end` (line 69), so the puzzle's rounds
  take the counts the same way the arena's do. Its mid-match `abandon`
  (`puzzle_session.dart:169`) writes a `round_end` with only a reason and no
  frames, so nothing is added there. No finding.
- `party_host` needed no change: `session_recorder.dart`'s `frames` case already
  forwards both counts in the order the collector now relies on.

Tests, seen failing first: `packages/metrics/test/round_frames_test.dart` (new,
9 tests) failed 7 of 9 on the old code — the two that already passed are the
abandoned-round and no-round-before cases, which old code also satisfied. After
the change: metrics 132 tests pass, host 460 pass.

Existing tests updated for the three new columns (not weakened): the header and
every rounds-CSV row in `csv_app_version_test`, `report_games_test`,
`report_rates_test`, `report_two_hosts_test` and `round_winner_csv_test`, and
the known summary in `metrics_test` (its round now carries 4200 drawn, 3 late).
`round_winner_csv_test`'s header test went from `endsWith` + length 13 to
`contains(',host_app,winner,draw,players,')`, since the header goes on; the new
test file holds the exact header and its 16 cells.

Computed values in the new tests: 3000 / 60 = 50.0 fps; 830 / 12.5 = 66.4 fps;
timeS 0 → `frames_drawn 40,frames_late 1`, fps empty; two records after one
round → round 3000/20, session 3100/25.

## Decisions

- A `bool _roundWaitsForFrames` flag rather than a round index or a "last round"
  guess: it is the only thing that tells a frames record that belongs to the
  round from the one a session end records later (arena `dispose`).
- Cleared at the top of `roundEnded` and set only where a round is added, so an
  abandoned round and a capped-out round both leave the frames to the session.
- The keys sit in the round map only when the round has them, like `battery` and
  `thermal` from `roundBattery`: a summary without them reads as before.
- fps is worked out in `report_rounds.dart` from the round's own numbers, so no
  second stored figure can disagree with `frames_drawn` and `time_s`.
- `roundEnded` had to stay at about 40 lines: the two `p.games[game] ??= {}`
  lookups in its player loop were folded into one (same behaviour), and the
  "waiting for frames" flag is explained on the field instead of inline.

## Self-check (review-rules part A)

1. **Every host setup.** Not host-specific: the counts come from the games'
   `frames` records, the same code on a TV, a PC, a phone host and a joined
   phone. Tested by `round_frames_test`.
2. **Kept state.** The flag starts at `roundEnded`'s add, ends at the next
   `frames()`, the next `roundEnded`, or the session's end; with no round ended
   before it, `frames()` adds to the totals only (`round_frames_test`: "frames
   recorded with no round before them stay session totals").
3. **Combining states.** Nothing pauses, hides or waits; the flag touches only
   the summary's rounds, so the pause menu, host away, player away and results
   see no new state. `metrics_test`'s "a summary does not change as the session
   goes on" still passes.
4. **Folder.** Wrote only `packages/metrics/lib/src`, `packages/metrics/test`
   and this report; `session_recorder.dart` and `party_host/test` were read and
   left alone.
5. **Stop rather than overstep.** Nothing outside `allow:` was needed.

## Notes

- The host suite's `live_stats_lifecycle_test.dart` failed twice with
  `PathNotFoundException … sessions\*` during `tools/check.sh host` and passed
  on its own and in the final check run (460 tests). It is the temp-folder flake
  a2's report already names, not this diff; it fails at a directory listing, and
  nothing in this change touches session files.
- `git status` also shows changed `docs/design/m13-*.png` and
  `tv_test_app/windows/.../generated_plugin*` files. This job did not edit them
  (the generated ones can be refreshed by running a Flutter build or test);
  they are outside `allow:` and should not be staged with this diff.

## Hand-over

- The rounds CSV gains three columns at the end; any reader of `rounds.csv`
  that counts cells by position (there was none in the repo; `bin/report.dart`
  only writes the file) must use the new header.
- Only the first frames record after a `round_end` is the round's. A game that
  ever writes more than one per round (none does today) would have the extra
  counts in the session totals only.
- A round whose frames record never arrives keeps the three cells empty; it is
  not back-filled from the session total, per the brief.
- The session totals still count the round's frames as well as the round does:
  `frames.drawn` is unchanged in meaning.

## Commit message

stats: per-round frames and fps in the rounds CSV

A round's frame counts were only session totals: the games write their frames
record just after round_end, and the collector added it to the session's sum
only. Now the first frames record after a round's end is the round's too
(framesDrawn, framesLate); an abandoned round takes none, and a frame-less round
stays without. The rounds CSV gains frames_drawn, frames_late and fps (drawn
over timeS, one decimal) after players, with empty cells for old summaries.
Tests: a new round_frames_test, seen failing first (7 of 9), and the existing
CSV rows and known summary updated for the three columns.

## Status row

Per-round frames kept in the summary and shown as `frames_drawn`, `frames_late` and `fps` in the rounds CSV (both games) — done; no table reads them yet, and the host-suite temp-folder flake is open.

## Delete

- none
