# M16 speed1 sp6 report: brief-check WARNs a test-only allow:

## Summary

brief-check.sh now WARNs at brief time when a job's allow: holds only `*_test.dart` files (and its
report) and the brief has no `tests-first: exempt` line. The WARN is `WARN testonly <job>: its
allow: holds only test files and no tests-first: exempt line`. It never FAILs; the exit code is
unchanged (0 when only WARNs). The new code lives in tools/brief-check-testonly.sh, sourced by
tools/brief-check.sh; brief-check.sh is 298 lines (cap 300).

Tests first: tools/tests/brief-check-testonly-test.sh was written before the code and run against
the old tool. Its FAIL lines then:

    FAIL a test-only allow: with no tests-first: exempt line WARNs, naming the job, and exits 0
        | RESULT: ok: 1 job(s), 0 WARN
    FAIL two jobs: only the test-only job WARNs, the result counts one WARN
        | RESULT: ok: 2 job(s), 0 WARN
    6 case(s), 2 failed

Values the expectations use: case 1 expects exit 0 and `RESULT: ok: 1 job(s), 1 WARN`; case 2
(exempt line) expects `RESULT: ok: 1 job(s), 0 WARN`; case 6 expects `RESULT: ok: 2 job(s), 1 WARN`
with the WARN only on job-a.

After the change:

- `bash tools/tests/brief-check-testonly-test.sh`: 6 case(s), 0 failed.
- `bash tools/tests/brief-check-test.sh`: RESULT: ok: 8 case(s) passed (the existing suite).
- `tools/mine.sh`: RESULT: ok: 0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested (no
  .dart file changed, so nothing for it to format or test).

## Files changed

- tools/brief-check-testonly.sh (new): `testonly_warn <job> <brief>`. Returns early when the brief's
  `tests-first:` starts with `exempt`. Otherwise it counts the allow: entries: `*-report.md` is
  skipped, `*_test.dart` counts as a test, any other entry returns with no WARN. It WARNs only when
  at least one test file is present.
- tools/brief-check.sh: 3 lines added. A comment, `[ -f tools/brief-check-testonly.sh ] && . ...`
  before the wave checks, and one `declare -F testonly_warn ... && testonly_warn "$j" "$B/$j.md"`
  call per job in the existing loop.
- tools/tests/brief-check-testonly-test.sh (new): 6 cases, fixture batches written to a temp folder:
  test-only allow WARNs and exits 0; the exempt line gives none; a lib file plus a test file gives
  none; a shell-tool job gives none; a report-only allow gives none; two jobs give one WARN, on the
  test-only job.
- docs/briefs/m16/speed1/sp6-report.md (this file).

## Questions

1. tools/mine.sh's churn revert restored three generated files under tv_test_app/windows/flutter
   (generated_plugin_registrant.cc, generated_plugin_registrant.h, generated_plugins.cmake) to HEAD.
   They were modified before this job started (git status at the start). I could not keep those
   edits (no git writes allowed), so they are no longer modified. If they were needed, a regenerate
   is the way back.
2. The brief says "sources it when present", so a missing tools/brief-check-testonly.sh silently
   turns the WARN off. I followed the brief; say if the file should be required instead.
3. A folder entry in allow: (for example `packages/p/test`) is not counted as a test file, so such a
   job gets no WARN. That was my reading of "only `*_test.dart` files".

## Suggestions

- The rule list in tools/brief-check.sh's header (lines 13-24) does not yet mention the testonly
  WARN. The file is at 298 lines, so the header line for it needs room: a job that splits the
  script would be the place, or the help range (`sed -n '2,33p'`) would need to grow with it.
- mine.sh's churn revert can silently discard uncommitted generated-file changes in a shared
  worktree. Worth a look in a later job.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

brief-check: WARN when a job's allow: holds only test files

A job whose allow: lists only *_test.dart files (and its report) has no lib change for the
runner to prove tests-first against, so brief-check.sh now WARNs at brief time, naming the job.
The WARN is skipped when the brief has a tests-first: exempt line, and a lib file, a shell-tool
job or a report-only allow: gives none. It never FAILs; the exit code is unchanged. The check
lives in tools/brief-check-testonly.sh, sourced by brief-check.sh, to keep that file under 300
lines. Covered by tools/tests/brief-check-testonly-test.sh (6 cases; 2 FAILed before the change).

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 speed1 sp6 done: brief-check WARNs a test-only allow: without a tests-first: exempt line (never a FAIL; both brief-check suites pass). Open: the testonly WARN is not yet in the brief-check.sh header rule list (file at 298 of 300 lines).

## Delete

- none
