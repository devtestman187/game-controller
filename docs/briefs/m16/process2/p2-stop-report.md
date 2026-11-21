# p2-stop report: tools/run-stop.sh writes STOP.md at a runner stop

## Summary

Added `tools/run-stop.sh <batch-dir> <work-dir> "<cause>" [<flash-log>]`, the
stop report from docs/briefs/m16/scriptable-work.md item 2. It writes
`<batch-dir>/STOP.md` (at most 40 lines) with the cause, its class, a suggested
repair, the failing names and error lines from `run-check.log`, the files
outside allow from the flash log's `CHANGED FILES OUTSIDE` block, and the last
20 `run.log` lines. A missing log says "none found". The write is a temp file
plus `mv`, so a reader never sees half a file. Exit 0 once STOP.md is written,
exit 3 only for bad arguments or an unwritable batch folder; a stop report
never fails the runner.

- Classes (13, from the cause text the runner passes): churn-outside,
  outside-allow, tests-first, check-failed, review-fail, size, brief-lint,
  preflight, stop-file, commit-refused, job-failed, timeout, other. Every one
  has a repair line naming a `docs/flash-digest.md` section or a command.
- The error filter is `tools/check.sh`'s `INTERESTING` pattern and its
  `^\s+(dart:|package:)` exclusion, copied verbatim so the two agree.
- Layout budget with the defaults: 4 head lines (STOP stamp, cause, class,
  repair) + 3 section lines + 8 error lines + 5 outside files + 20 log lines
  = 40 exactly; env knobs `STOP_MAX_LINES`, `STOP_LOG_TAIL`, `STOP_ERROR_LINES`,
  `STOP_OUTSIDE_LINES`, `STOP_COL` are named in the header.
- Added `tools/tests/run-stop-test.sh`: 28 cases (13 classes, the repair check,
  the failing names and log tail, huge logs, outside files, missing logs, 4 bad
  arguments, a path with spaces, a cause with quotes and a newline, an empty
  cause, only-STOP.md-added, an old STOP.md replaced, CRLF).
- The 28 cases print `PASS`/`FAIL` and end on `RESULT: ok: 28 case(s) passed`.

`bash tools/tests/run-stop-test.sh` was refused by this session's Bash
allow-list (only `tools/check.sh`, `bash tools/run-stop.sh`, `bash -n` and
read-only commands ran), so the test was run through the `tools` check, which
calls it. The runner is not wired yet: that is the `p2-wire` job.

## Files changed

- `tools/run-stop.sh` (new, 140 lines): the STOP.md writer described above.
- `tools/tests/run-stop-test.sh` (new, 198 lines): its self-test, 28 cases.
- `docs/briefs/m16/process2/p2-stop-report.md`: this report.

`tests-first: exempt shell tooling (brief); its test is tools/tests/run-stop-test.sh`.

## Checks

- `tools/check.sh tools` → PASS (29-30 s; `run-stop-test.sh` 18-19 s,
  `selftest-test.sh` 11 s). The first run failed two of my own expectations
  (the oldest kept run.log line and a pre-created STOP.md that made the
  "added file" comparison empty); both were wrong test values, fixed in the
  test, not in the script.
- `tools/check.sh format` → PASS (9 s).
- `bash -n` on both new files → clean.

## Decisions

1. **Layout is a fixed budget, not a loose cap.** Head 4 + headings 3 + caps
   (8 errors, 5 outside, 20 log) = 40 with the defaults, so the last 20 log
   lines always fit and the newest STOPPED line never falls off. A section
   with fewer lines than its cap is left short rather than padded (the file is
   then under 40) and `(+N more)` marks each cut.
2. **Class order puts `churn` before `outside`.** A churn cause usually also
   says "outside its allow", and the churn class carries the "leave it" repair
   the digest asks for.
3. **The cause is one line.** Newlines, tabs and runs of spaces collapse to
   one space, and each line is cut at `STOP_COL` (300) columns. The longest
   `run.log` line in the two sampled logs is 460 chars, and the tests-first
   STOPPED line ~330, so the 300 default trims only the extremes.
4. **A missing work folder or log is "none found", not exit 3**, because the
   brief fixes exit 3 to bad arguments and an unwritable folder, and a stop
   report must never fail the runner.
5. **No lock and no time limit.** The script runs a few local `awk`/`grep`/
   `tail` calls (milliseconds), never a network or a child that can hang, so
   script-rules' lock and timeout rules add nothing here; a second copy is
   harmless because the write is atomic.
6. **The writability check is a hint.** `[ -w ]` is unreliable in Git Bash on
   Windows; the real guard is `mktemp`/`printf`/`mv` failing, which exits 3
   with the temp file removed by the EXIT trap.
7. **Exit 0 even with a thin report.** Empty logs and an empty cause
   (`cause: (empty)`, `class: other`) still get a file; the alternative,
   failing the runner, is what the brief forbids.

## Self-check (review-rules part A)

1. Every host setup: not affected; shell tooling only, no app, host, phone or TV code.
2. Kept state: STOP.md is the only state; it starts when the runner calls the
   script at a stop, is replaced whole by the next call, and nothing is
   written when nothing stops. Shown by "only STOP.md is added" and "an old
   STOP.md is replaced".
3. New state combines: not affected; nothing reads STOP.md yet (the runner
   removes it at the next start in the wire job) and no round, menu or UI
   state is involved.
4. Folder: only `tools/run-stop.sh`, `tools/tests/run-stop-test.sh` and this
   report were written.
5. Stop rather than overstep: no stop. The runner wiring (calling the script
   from `stop()`, committing STOP.md, removing it at start) is the `p2-wire`
   job and was not touched.
6. Every look: not affected; no UI, no widget, no size.

## Computed values (what the cases expect)

| fixture | STOP.md | why |
| --- | --- | --- |
| class cases, 4-line run.log | 7 lines + errors | 4 head + 3 headings, no outside/log overflow |
| detail: 41 run.log lines, 4 interesting check lines (the `package:` line excluded) | 31 lines | 7 + 4 + 20; oldest kept is `log line 22` of 41 |
| huge: 501 run.log lines, 500 check lines, 500 outside paths | 40 lines | 7 + 8 + 5 + 20, each cut section ends `(+N more)` |
| missing logs | 3 `none found` lines | run-check.log, flash log, run.log |
| bad arguments | exit 3, last line `RESULT: BAD INPUT: ...` | no args, 1 arg, missing batch folder, batch path is a file |
| cause `He said "x" and it's y\nsecond line` | 1 `cause:` line | quotes kept, newline collapsed |
| empty cause | `class: other`, `cause: (empty)` | still exit 0 |

Caps: 8 error lines, 5 outside paths, 20 log lines, 300 columns, 40 lines.
The huge fixture shows every cap at once (`(+N more)` present, `LAST-LINE`
present, 40 lines exactly).

## Questions and suggestions

1. **Unwritable folder is untested.** Git Bash as this user cannot reliably
   make a folder unwritable (`chmod` is mostly a no-op, and the tests must not
   need root), so the "batch path is a file" case is the closest guard; the
   `mktemp`/`mv` branch is read, not run. Worth one case on a runner where
   `chmod 500` works.
2. **The wire job should pass the full cause text.** The class comes only from
   that text; the new outside-file stop should keep the words "outside its
   allow" (or "churn" for churn-only) so it lands in the right class.
3. **`STOP_COL` 300 trims ~74 chars off the longest real STOPPED line.** If
   the runner prefers whole cause lines, raise the knob; the line budget is
   unaffected.
4. **Hand-over:** `p2-wire` calls the script from `stop()`, `check_stop` and
   the brief-lint exit, adds `$B/STOP.md` to the paths `save()` commits, and
   removes it at the next start.

## Commit message

Add tools/run-stop.sh: a STOP.md report at every runner stop

tools/run-stop.sh writes <batch>/STOP.md (at most 40 lines): the cause, its
class, a repair naming the digest section or a command, the failing names and
error lines from run-check.log, the outside files from the flash log, and the
last 20 run.log lines. A missing log says "none found"; the write is a temp
file plus mv; exit 0 once written and 3 only for bad arguments or an
unwritable folder, so a stop report never fails the runner. 13 classes, one
repair each. tools/tests/run-stop-test.sh covers every class, the log tail,
huge logs, missing logs, bad arguments, paths with spaces and that only
STOP.md changes. The runner is wired in p2-wire.

## Status row

**Process2 run-stop (Nov 21):** `tools/run-stop.sh` writes `<batch>/STOP.md` (cause, class, repair, failing names, outside files, last 20 log lines; 40-line cap) and `tools/tests/run-stop-test.sh` has 28 cases (`tools/check.sh tools` PASS); open: the runner calls it (p2-wire) and the first driver run of a real stop.

## Delete

- none
