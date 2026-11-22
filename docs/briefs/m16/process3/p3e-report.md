# p3e report: a stand-in worker (tools/fake-flash.sh) for an end-to-end rehearsal

## Summary

New `tools/fake-flash.sh` (152 lines) stands in for `tools/flash.sh` in a rehearsal of the runner: the
same call (`--brief <file>`, and `--preflight`), a sleep in place of a worker run, a fixed report, one
note line and one usage row. New `tools/tests/fake-flash-test.sh` (181 lines, 14 cases, 10 s).

One `--brief` run, in order:

1. reads the brief's `report:` and first `allow:` path, the way `tools/flash.sh` and
   `tools/commit-job.sh` read a header;
2. sleeps `FAKE_FLASH_SLEEP_S` (default 2, whole or fractional); `FAKE_FLASH_HANG=1` sleeps 3600 s
   instead and then exits, writing nothing, so the runner's own limit ends it (REHEARSAL.md run 6);
3. writes the report: `## Summary` first, then `## Commit message`, `## Status row`, `## Delete`,
   `## Hand-over` last (flash.sh's runner check wants Summary in the first 40 lines; commit-job.sh
   wants a Commit message; flash.sh skips a Delete entry of `none`);
4. appends one line `<time>\t<brief>\tallow=<first allow path>\trc=<code>` to
   `FAKE_FLASH_NOTE_FILE`, when it is set;
5. appends one usage row to `FLASH_USAGE_LOG` in `tools/flash_usage.dart`'s ten-field format: time,
   result, `FAKE_FLASH_TURNS` turns (default 10), elapsed seconds, 0, 0, 0, 0, 1 file, and the task
   line `Your brief is <brief>: read it first, then do the job it describes.` — the line that carries
   the brief's path for `tools/run-jobs.sh`'s `usage()` (`index($10, b)`);
6. exits `FAKE_FLASH_RC` (default 0); bad arguments exit 2 with a `fake-flash: ...` line.

`--preflight` prints one line and exits 0, writing nothing. The only folder the script makes is the
report's own; the `allow:` paths' folders get no file.

Checks: `tools/check.sh tools` PASS (297 s); `tools/selftest.sh tools/tests` PASS (12 scripts), the new
script PASS in 10 s against the brief's 15 s budget. No Dart file was touched, so no other check can
see this change.

## Files changed

- `tools/fake-flash.sh` — NEW: the stand-in worker (same call as flash.sh, six env knobs, report +
  note line + usage row, exit code) and its doc header, which is also `--help`.
- `tools/tests/fake-flash-test.sh` — NEW: 14 cases, one per mode and knob, each in its own temp folder.
- `docs/briefs/m16/process3/p3e-report.md` — NEW: this report.

## Decisions

- **Report sections beyond the two the brief asks for.** The brief names `## Summary` and
  `## Hand-over`; I also write `## Commit message`, `## Status row` and `## Delete`, because a
  rehearsal runs `tools/commit-job.sh` (Commit message) and `tools/run-jobs.sh` (Summary in the first
  40 lines); without them the rehearsal stops at the commit walk. Delete holds `- none`, which
  `tools/flash.sh` skips.
- **Task line in the usage row copied from flash.sh.** The row's tenth field is
  `Your brief is <brief>: read it first, then do the job it describes.`, not a shortened label: that
  is what `tools/flash.sh` records and what `usage()` matches a job's turns by. It is 76 characters
  plus the path, so no truncation is needed (the recorder cuts at 100; the path sits at the start).
- **Elapsed seconds are measured, not assumed.** The row's seconds field and the report's `slept:`
  line are whole seconds from `date +%s` around the sleep, so a rehearsal's `min` figures come from
  the clock. No milliseconds: a rehearsal runs in seconds.
- **A hung run writes nothing.** `FAKE_FLASH_HANG=1` sleeps an hour and then exits with the rc, with
  no report and no row: a hung job in a real run leaves no report either, and writing one would let
  the runner's resume path see a finished job.
- **The note file is optional.** With `FAKE_FLASH_NOTE_FILE` unset the script writes no line and the
  report's Hand-over says so; the rehearsal then stays inside the brief's paths alone.
- **Folders are made for the report, the note file and the usage log** (`mkdir -p`), as
  `tools/flash_usage.dart` does for its log: a rehearsal sets `<scratch>/usage.tsv`, whose folder may
  not exist yet. No other file is created.
- **Knobs are validated before anything is read or written**: `FAKE_FLASH_SLEEP_S` is a plain number
  of seconds (whole or with one fraction), the turns and rc are whole numbers, anything else exits 2
  with the variable's name, so a rehearsal typo stops at once instead of after an hour.

## Test cases and the values they check

`tools/tests/fake-flash-test.sh`, 14 cases, each in a fresh temp folder. Computed values:

| case | expectation |
|---|---|
| a brief run | exit 0, elapsed 1–2 s for `FAKE_FLASH_SLEEP_S=1`; report's line 1 is `## Summary`, its last `## ` heading is `## Hand-over`; `## Commit message` present; the first allow path appears in the report |
| nothing else written | allow folder empty (`ls -A` = ""), report folder holds only `report.md`, log folder holds `notes.txt usage.tsv`, exactly 1 note line, `allow=<first allow>` and `rc=0` in it, `second.txt` (the second allow path) not named |
| the usage row | 1 row, 10 fields, field 2 = 0, field 3 = 7 (`FAKE_FLASH_TURNS=7`), field 9 = 1, field 10 = the full task line above |
| the defaults | exit 0, elapsed ≥ 2 s, 10 turns |
| `FAKE_FLASH_RC=4` | exit 4, `exit code: 4` in the report, field 2 of the row = 4 |
| `--preflight` | exit 0, `preflight ok` printed, no report / note / usage file, allow folder empty |
| `FAKE_FLASH_HANG=1` | under `timeout 2`: exit 124, no report, log folder empty |
| bad arguments | unknown argument, `--brief` with no value, a missing brief, a brief with no `report:` line, `FAKE_FLASH_SLEEP_S=1.2.3`, `FAKE_FLASH_TURNS=ten`: exit 2 and a `fake-flash: ...` line each |
| paths with spaces | a brief `my brief.md` and a report `my report.md` under `spaces one/job two`: exit 0, Summary first, the note line names the allow path, field 10 is the full task line |

Wall time of the suite: 10 s (sleeps 1 + 2 + 2 s, the rest is process start).

## Checks

- `tools/check.sh tools` → PASS, 297 s (`All checks passed`), which is `bash tools/selftest.sh` over
  `tools/tests/*-test.sh`.
- `tools/selftest.sh tools/tests` (the same 12 scripts, run before the last wording change) → PASS for
  all 12; the new script PASS in 10 s. `selftest.sh` prints only a PASS line per script, so the
  script's own `RESULT: ok: 14 case(s) passed` line stays in the suite's temp log; the 14 is the
  number of `report` calls in the file (10 direct, plus `bad_case` four times).
- The first full run of the new test failed 2 of its 14 cases (the two that matched the brief's path
  inside the usage row with `awk -v b=<path>`); the fix compares the whole tenth field with the
  expected task line instead. Cause not measured: likely Git Bash's awk converting an absolute
  `/tmp/...` value given with `-v`. `tools/run-jobs.sh` matches a repository-relative path there, so
  it is not affected.

## Self-check (docs/review-rules.md part A)

1. Every host setup — not applicable: no TV, PC host, phone or peer state; the runner's two calls are
   the equivalent, and `--preflight` and the brief run are the preflight and the report cases.
2. When kept state starts and ends, and nothing going on — the stand-in keeps no state: each run ends
   with the report, one note line and one usage row, and the preflight case shows that a run with
   nothing to do writes nothing at all.
3. How a new state combines with the pause menu, host away and so on — not applicable: no UI, no
   session state.
4. Stay in the job's folder and inside `allow:` — only the three allow paths changed (Files changed).
5. Stop rather than overstep — nothing was needed outside `allow:`; `tools/flash.sh`,
   `docs/dev-tools.md` and REHEARSAL.md are untouched, and the two doc changes they could use are
   under Suggestions.
6. Every look — not applicable: no widgets, no look-sized boxes.

Tests-first: exempt as the brief says (a new shell tool). The test file was written after the script
in this job; run against the code before this job, with no `tools/fake-flash.sh`, it fails every case
(`bash` exits 127 for the missing script, so no case sees the rc it expects). That is reasoned from
the script's calls, not run: the runner's revert check is what would prove it.

## Hand-over

- `tools/fake-flash.sh` is ready for REHEARSAL.md's `FLASH_CMD=tools/fake-flash.sh` line; the sleep,
  turns and rc knobs cover runs 1–3 and 6, and `FLASH_USAGE_LOG=<scratch>/usage.tsv` keeps the real
  `~/.thumbparty/flash-usage.tsv` free of fake rows.
- `tools/fake-flash.sh --preflight` exits 0 without running anything, so a rehearsal can leave
  `PREFLIGHT_SKIP` unset once run-jobs.sh calls `${FLASH_CMD:-tools/flash.sh} --preflight`.
- Two consequences a rehearsal will see, worth knowing before it runs: the fake commits report-only
  jobs (it never writes the allow path's file, so run 1's `committed r1` has just `r1-report.md`), and
  the report's sections are fixed text apart from the brief path, the allow path, the seconds and the
  rc.

## Questions

1. Should `docs/briefs/m16/process3/REHEARSAL.md` set `FAKE_FLASH_NOTE_FILE` (its env line has no note
   file, so that line stays untested by a rehearsal)? It is in no job's `allow:` here.
2. Does the preflight case of p3d's wire test expect `tools/fake-flash.sh --preflight` to print
   anything specific, or only exit 0? This one prints `fake-flash: preflight ok (...)`.

## Suggestions

- `docs/dev-tools.md` could get a paragraph on the stand-in (call, knobs) next to the runner's, and
  `REHEARSAL.md` could name `FAKE_FLASH_NOTE_FILE` in its env line — both outside this job's `allow:`.
- `docs/project-notes.md` could keep the awk lesson: in Git Bash, don't pass an absolute path to
  `awk -v name=...` and expect it to match text read from a file; compare the whole field instead.
  (Measured only by the two failures above; the cause is a guess.)

## Commit message

p3e: add a stand-in worker for runner rehearsals

tools/fake-flash.sh takes the same --brief and --preflight call as
tools/flash.sh and, instead of a worker run, sleeps, writes a report
with Summary first and Hand-over last, one note line and one usage
row in run-jobs' format, then exits FAKE_FLASH_RC. FAKE_FLASH_HANG=1
outlasts the runner's limits.
tools/tests/fake-flash-test.sh covers every mode and knob in 14 cases,
about 10 s.

## Status row

p3e done: `tools/fake-flash.sh` (same call as flash.sh, knobs, report, note line, usage row) and its
14-case test pass `tools/check.sh tools`; open: the rehearsal itself (REHEARSAL.md) runs once p3a-p3e
are committed, and run-jobs.sh's preflight still calls `tools/flash.sh` (p3d's `FLASH_CMD` wiring).

## Delete

- none
