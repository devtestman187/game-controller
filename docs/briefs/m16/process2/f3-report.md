# M16 process2 f3 report: validate the env knobs and pin the mine.sh rename case

## Summary

The three REVIEW.md findings of this brief, fixed in place:

1. `tools/run-stop.sh` no longer trusts its five knobs. Each one is checked as a
   whole number through `bad_input` (exit 3, `RESULT: BAD INPUT` last, no
   STOP.md), `STOP_MAX_LINES` must be at least 10, and `STOP_LOG_TAIL` is capped
   at `STOP_MAX_LINES - 9` so the head line, the three section lines and one
   line each for errors and files always fit: `STOP_LOG_TAIL=60` with the
   default limit now writes exactly 40 lines (it wrote 69 before), and
   `STOP_MAX_LINES=10` writes exactly 10. A capped tail prints one `NOTE:` line.
2. `tools/wait-run.sh` checks `WAIT_STALL_MIN`, `WAIT_POLL_S` and
   `WAIT_RECENT_ROWS` beside the `WAIT_MAX_S` check (whole number, exit 3,
   `RESULT: BAD INPUT`), and each must be at least 1 (a 0 poll spins, a 0 stall
   minute stalls at once), matching the existing `WAIT_MAX_S` floor.
3. `tools/tests/mine-test.sh` rename case now also asserts the stub log shows
   `flutter test test/screen_test.dart`, so p2-mine decision 2 (the old
   basename keeps its tests) has a test.

Tests: `run-stop-test.sh` 38 cases (29 + 9 new: 5 non-numeric knobs, 2 below the
minimum, 2 too-large caps), `wait-run-test.sh` 25 cases (19 + 6 new: 3
non-numeric, 3 zero), `mine-test.sh` 14 cases (one assertion stronger). The new
cases fail on the old scripts (69- and 29-line STOP.md, an abort with no RESULT
line, exit 4 instead of 3 for a bad wait knob).

## What changed

- `tools/run-stop.sh`: a `whole` helper beside `bad_input`; a knobs section after
  the folder checks (whole number, minimums, tail cap, one `NOTE:` when the tail
  is capped); the two clamps in the room calculation removed because the cap now
  guarantees them (room >= 2, outmax >= 1); header lists the rules; the `usage()`
  range moved from `2,25` to `2,27` for the two extra header lines.
- `tools/wait-run.sh`: three `case` checks and three minimum checks beside
  `WAIT_MAX_S`; one header sentence naming the rules. No other line changed.
- The three self-tests, described above; `run-stop-test.sh`'s header now names
  the knob cases.

## Computed test values

- Tail cap `STOP_MAX_LINES - 9`: 40 - 9 = 31; 10 - 9 = 1. The 9 is 4 head lines +
  3 section lines + 1 error line + 1 outside-file line.
- `STOP_LOG_TAIL=60`, `STOP_MAX_LINES=40`, 61 run.log lines: cap 31, oldest kept
  line = 61 - 31 + 1 = 31, file = 4 + 2 + 2 + 1 + 31 = 40 lines exactly.
- `STOP_MAX_LINES=10`, tail 20 capped to 1: room = 10 - 7 - 1 = 2, one error and
  one file line, file = 4 + 2 + 2 + 2 = 10 lines exactly.
- Old code on the same inputs: 7 + 2 + 60 = 69 lines, and 7 + 2 + 20 = 29 lines
  for the 10-line limit, as REVIEW.md reported.

## Checks run

- `tools/check.sh tools` PASS (162 s, 164 s; runs `tools/selftest.sh`, i.e. every
  `tools/tests/*-test.sh`) — also PASS earlier at 159 s and 162 s on the way.
- `tools/check.sh format` PASS (9 s, 5 s).
- `bash -n` on the five edited scripts: no output.
- `bash tools/tests/<name>-test.sh` directly is refused by this session's Bash
  allow-list, as p2-stop's report noted; the `tools` check is the evidence.

## Self-check (review-rules part A)

1. Host setups: not affected — no game, controller or host code; the change is
   three shell scripts and their self-tests ("the files outside allow are quoted
   from the flash log" shows the only input they read).
2. Kept state: none added. STOP.md still goes to a temp file and a rename
   ("only STOP.md is added to the folder (no temp file left after two runs)");
   wait-run's lock, position and marker are untouched ("an interrupted waiter
   (TERM from timeout) leaves no lock and no marker").
3. New state combining: the only new outcome is a bad knob, which now exits 3
   before any file is written ("a non-numeric STOP_LOG_TAIL is bad input (exit 3)"
   asserts no STOP.md; "a non-numeric WAIT_STALL_MIN is bad input (exit 3)" shows
   the RESULT line). It cannot combine with pause, host away or results: no UI.
4. Stay in the job's folder: only the five allowed files are mine in
   `git status`; `run.log` and the tv_test_app generated files were already dirty.
5. Stop rather than overstep: `docs/dev-tools.md`'s knob list now understates the
   rules (no minimums, no cap) and is outside `allow:` — left alone, see question 3.
6. Every look: not affected — no widget, menu look or TV look in this change.

## Decisions

1. The tail cap is `STOP_MAX_LINES - 9`, not the `- 8` REVIEW.md suggests: with
   `- 8` the 40-line default yields 7 + 2 + 32 = 41 lines, because the script
   already floors room at 2 (one line each for errors and files).
2. A too-large tail is clamped with a `NOTE:` line, not refused: the brief says
   "cap", and a stop must still write STOP.md. Every other bad value is bad input.
3. `STOP_MAX_LINES` below 10 exits 3 (the brief calls 10 the minimum) rather than
   being raised to 10, so a small knob is never silently ignored.
4. The other four run-stop knobs and the three wait-run knobs must be at least 1:
   a 0-line tail or column, a 0-row median or a 0-second poll makes the output
   or the loop meaningless.
5. `WAIT_EXPECT_DEFAULT_MIN` is left unvalidated: it is only printed and is not
   one of the brief's four.

## Questions and suggestions

1. Should `STOP_MAX_LINES` below 10 be raised to 10 instead of refused? Refusing
   matches "bad input, exit 3" and keeps the limit honest; easy to flip.
2. `WAIT_EXPECT_DEFAULT_MIN` (and `RUN_WORK`'s path) are still unchecked; adding
   them to the same four checks is a two-line follow-up if wanted.
3. `docs/dev-tools.md` and the header knob lists do not mention the minimums or
   the tail cap; a docs job (f5/f8) could add one sentence each.
4. REVIEW.md's "could" item at `wait-run.sh:249` (the `WAIT:` banner) is outside
   this brief's three fixes and was left as it is.

## Hand-over

The stop text is unchanged for every class and input; only a bad knob or a tail
larger than the limit behaves differently, and both are now visible in the last
line. Nothing else in the scripts moved.

## Commit message

M16 process2 f3: validate the run-stop and wait-run env knobs

Each numeric knob in run-stop.sh and wait-run.sh is now checked as a whole
number through the bad-input path (exit 3, RESULT: BAD INPUT) instead of
aborting inside $(( )) with no line saying why, and small or zero values are
refused. run-stop.sh caps STOP_LOG_TAIL at STOP_MAX_LINES - 9, so a 60-line
tail no longer writes a 69-line STOP.md and the 10-line minimum still writes a
whole file. mine-test.sh's rename case now also asserts that the old basename's
test still runs. The self-tests gain 9 and 6 cases.

## Status row

**Process2 f3 (Nov 21):** `tools/run-stop.sh` and `tools/wait-run.sh` reject a non-whole or too-small env knob with `RESULT: BAD INPUT` (exit 3) and run-stop caps the log tail so STOP.md fits `STOP_MAX_LINES` (min 10); `mine-test.sh` proves a renamed file's tests still run — open: `docs/dev-tools.md` and the headers do not state the new minimums/cap (f5/f8), and REVIEW's `WAIT:` banner note (`wait-run.sh:249`) stays.

## Delete

- none
