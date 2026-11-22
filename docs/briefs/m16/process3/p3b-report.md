# M16 process3 p3b — check.sh fails fast, selftest.sh per-script limits

## Summary

`tools/check.sh` now stops after a failed `format` or `analyze` when `CHECK_FAIL_FAST=1` (or
`--fail-fast`): every check after it prints `SKIPPED <suite> (<check> failed)`, none of them runs, and
the run exits 1. Off by default, so today's callers see the same output. `CHECK_DART` and
`CHECK_FLUTTER` (default `dart` and `flutter`) name the commands, so a self-test stubs the toolchain;
`--list` is byte-identical with and without the flag (13 rows).

`tools/selftest.sh` now takes `SELFTEST_TIMEOUTS` — `basename=seconds` pairs, comma separated, default
`run-wire-test.sh=240` — and `SELFTEST_TIMEOUT` (120) stays the limit for every script the list doesn't
name. The `TIMEOUT:` line and the per-script TIMEOUT line name the limit that ran out; the RESULT line
says "their limit" instead of repeating one number. Malformed entries are bad input (exit 3).

Two new self-tests: `tools/tests/check-failfast-test.sh` (9 cases, 8 s) and
`tools/tests/selftest-limits-test.sh` (7 cases, 12 s), both stub or fixture-driven and under 20 s.

Tests-first proof (each new script run against the old tool through `tools/selftest.sh`, FAIL lines
below): check-failfast-test 0 of 9 cases passed (76 s); selftest-limits-test 1 of 7 (20 s). After the
change: `tools/check.sh tools` PASS (278 s), `RESULT: ok: 9 script(s) passed (277s)`,
`tools/review.sh`: 0 fail, 0 note.

Decisions:
1. **Fail-fast covers every later check, not only the suites.** The decision says "skip the test suites
   and report", and `tools` is a suite too; order puts format and analyze first, so nothing that could
   pass unnoticed is hidden. A suite that fails by itself never triggers skipping (case 5).
2. **The reason names the check:** `SKIPPED protocol (analyze failed)` / `(format failed)`, exactly as
   the brief wrote it, so a log reader sees which one went red.
3. **The hooks are `CHECK_DART`/`CHECK_FLUTTER`, the brief's names**, and the commands are swapped by a
   small `run_cmd` (first word only), keeping the checks table readable and `--list` unchanged. The stub
   path is quoted inside the `eval`, so a temp path with spaces still works.
4. **Bad `CHECK_FAIL_FAST` is bad input (exit 2)**, not a silent "off": p3c will set `1`, and a typo
   should not quietly turn the feature off.
5. **`SELFTEST_TIMEOUTS` is validated up front** (an entry without `=`, an empty name, non-digits, 0)
   and an empty value restores the default, matching how `SELFTEST_TIMEOUT` handles an empty value.

## Files changed

- `tools/check.sh` (163 lines): header documents `--fail-fast`, `CHECK_FAIL_FAST`, `CHECK_DART`,
  `CHECK_FLUTTER` (help range now 2-20); `dart_cmd`/`flutter_cmd` and the `fail_fast` env parse (0/1,
  else exit 2) before the checks table; `run_cmd` swaps the first word for the hooks; `-f | --fail-fast`
  in the option loop; the PATH check tests `$dart_cmd`/`$flutter_cmd`; the loop prints
  `SKIPPED <name> (<check> failed)` for each wanted check after a failed format or analyze.
- `tools/selftest.sh` (164 lines): header documents `SELFTEST_TIMEOUTS` (help range now 2-20);
  `timeouts`, the parse/validate loop, `limit_for`; the loop computes `script_limit` per script and uses
  it for `timeout(1)` and the `TIMEOUT:` line; the RESULT TIMEOUT line says "their limit".
- `tools/tests/check-failfast-test.sh` (new, 151 lines): stub `dart`/`flutter` log each call and exit
  with `STUB_FORMAT_RC`/`STUB_ANALYZE_RC`/`STUB_TEST_RC`; 9 cases.
- `tools/tests/selftest-limits-test.sh` (new, 122 lines): fixtures that sleep 2 s and that hang; 7 cases.
- `docs/briefs/m16/process3/p3b-report.md`: this report.

## The 9 check-failfast cases, and the values each asserts

| case | expectation computed |
| --- | --- |
| `--fail-fast`, analyze rc 1 (`format analyze protocol metrics`) | exit 1; `FAIL  analyze`; `SKIPPED protocol (analyze failed)`; `SKIPPED metrics (analyze failed)`; no `PASS  protocol/metrics`; stub calls format 1, test 0; last line `1 failed: analyze` |
| `CHECK_FAIL_FAST=1`, same | exit 1; `SKIPPED protocol (analyze failed)`; test calls 0 |
| no flag, analyze rc 1 | exit 1; no `SKIPPED` line; `PASS protocol` and `PASS metrics`; test calls 2 |
| `--fail-fast`, format rc 1 | exit 1; `FAIL  format`; `SKIPPED analyze (format failed)`; `SKIPPED protocol (format failed)`; analyze calls 0, test calls 0 |
| `--fail-fast`, test rc 1 | exit 1; no `SKIPPED`; `FAIL protocol` and `FAIL metrics` both present; test calls 2 (a suite failure stops nothing) |
| `--fail-fast`, all rc 0 | exit 0; no `SKIPPED`; last line `All checks passed`; test calls 1 |
| `--list` vs `--fail-fast --list` | `cmp` identical, 13 rows, stub log empty (no check ran) |
| `CHECK_DART=<tmp>/no-such-dart` | exit 2; line `<path> isn't on the PATH (set CHECK_DART or CHECK_FLUTTER).` |
| `CHECK_FAIL_FAST=maybe` | exit 2; `CHECK_FAIL_FAST must be 0 or 1, got 'maybe'` |

## The 7 selftest-limits cases, and the values each asserts

| case | expectation computed |
| --- | --- |
| `quick-test.sh=9`, `SELFTEST_TIMEOUT=1`, script sleeps 2 s | exit 0; `PASS ... quick-test.sh (2s)`; RESULT ok; elapsed 2 s (< 6) |
| `slow-test.sh=2`, `SELFTEST_TIMEOUT=6`, script hangs | exit 2; `TIMEOUT <script>`; `TIMEOUT: ... exceeded 2s`; RESULT TIMEOUT; elapsed 2 s (< 5, so the per-script limit ran, not 6) |
| `other-test.sh=30`, `SELFTEST_TIMEOUT=1`, script hangs | exit 2; `exceeded 1s`; RESULT TIMEOUT; elapsed 1 s (< 5) |
| `other-test.sh=1,quick-test.sh=9`, `SELFTEST_TIMEOUT=1`, 2 scripts | exit 0; `PASS ... quick-test.sh`; `RESULT: ok: 2 script(s) passed`; elapsed 2 s |
| `quick-test.sh` (no `=`) | exit 3; `RESULT: BAD INPUT:`; message `name=seconds` |
| `quick-test.sh=soon` | exit 3; message `must be whole seconds` |
| `quick-test.sh=0` | exit 3; message `at least 1 second` |

## Before the change (each new script on the old tools)

`tools/check.sh --verbose tools` on the unchanged `check.sh`/`selftest.sh`:
`RESULT: FAILED: 2 of 9 script(s) failed (7 passed, 335s)`.

- `FAIL  tools/tests/check-failfast-test.sh (76s)` — all 9 cases:
  `--fail-fast: a failed analyze prints SKIPPED ...`, `CHECK_FAIL_FAST=1 skips like --fail-fast ...`,
  `off by default: a failed analyze still runs every remaining suite`, `--fail-fast: a failed format skips ...`,
  `--fail-fast stops only after format or analyze ...`, `--fail-fast with everything passing ...`,
  `--list prints the same 13 rows with or without --fail-fast ...`, `a missing CHECK_DART command is bad input`,
  `CHECK_FAIL_FAST other than 0 or 1 is bad input`.
- `FAIL  tools/tests/selftest-limits-test.sh (20s)` — 6 of 7:
  `a listed script gets its own limit`, `a listed script is stopped at its own limit, and the TIMEOUT line names it (7s)`,
  `a comma-separated list matches the right basename`, `an entry without = is bad input`,
  `an entry whose seconds aren't whole is bad input`, `an entry with 0 seconds is bad input`. The seventh
  (`an unlisted script still uses SELFTEST_TIMEOUT=1`) passes on the old tool too: it guards the unchanged
  default.

The first post-change run of check-failfast-test exposed two wrong assertions of mine (it counted the
`PASS  format` line as "a suite ran", and quoted the stub path in the PATH message grep); both are fixed
in the file above, and the run after that is the green one reported here.

Run-wire-test duration in these runs: 119 s, 118 s, 133 s — above the old 120 s default twice in a row
in the same session, which is the owner's reason for the 240 s entry; it passes under the new default.

## Self-check (review-rules part A)

1. Host setup shapes: not applicable — shell tools, no host, phone or session code.
2. Kept state: the only state a check.sh run keeps is its log folder under the temp root (the self-test
   points `TMPDIR` inside its own temp folder, removed by its trap); selftest's lock and temp folder are
   covered by the existing selftest-test cases, unchanged.
3. Pause menu / host away / results: not applicable (no runtime state).
4. Stayed inside `allow:` (the five files listed above) and the job folder.
5. Stopped where the brief said: no edit to `docs/dev-tools.md`, `tools/run-steps.sh` or `tools/run-base.sh`
   (the two callers p3c and p3f own the turn-on).
6. Every look: not applicable — no widget, no look-sized anything.

## Checks I ran

- `tools/check.sh tools` — PASS, 278 s (`RESULT: ok: 9 script(s) passed (277s)`); per script:
  check-failfast 8 s, flash-prompt 2 s, mine 29 s, run-jobs-split 10 s, run-stop 23 s, run-wire 133 s,
  selftest-limits 12 s, selftest-test 11 s, wait-run 47 s.
- `tools/check.sh --verbose tools` before the change — FAIL (proof above).
- `tools/review.sh` — 0 fail, 0 note.
- `tools/mine.sh` — `RESULT: ok: 0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested`
  (no Dart file touched); it reverted 3 generated churn files.
- `bash -n` on the four scripts — ok; `tools/check.sh --help`, `--list` (13 rows) and
  `tools/selftest.sh -h` show the new text.

## Questions

1. **docs/dev-tools.md is stale now**: its `tools/check.sh` section still says exit 2 is "an unknown check
   name or a missing tool" and lists neither `--fail-fast`/`CHECK_FAIL_FAST` nor the command hooks; the
   `tools/selftest.sh` section lists only `SELFTEST_TIMEOUT`. The file is outside this job's `allow:`;
   a docs job should add a bullet for `CHECK_FAIL_FAST`, `CHECK_DART`/`CHECK_FLUTTER` and `SELFTEST_TIMEOUTS`.
2. **p3c/p3f contract:** set `CHECK_FAIL_FAST=1` exactly (any other value but 0 exits 2), and read exit 1
   plus the `SKIPPED` lines; the `N failed:` summary line still names only the checks that failed.
3. **Two env conventions**: `tools/mine.sh` uses `DART`/`FLUTTER`; `check.sh` now uses
   `CHECK_DART`/`CHECK_FLUTTER` because the brief named them. Worth unifying in a later job.

## Suggestions

- Let `tools/check.sh --fail-fast` keep running the `tools` check when only a Dart suite failed — not
  needed for the decision (only format/analyze skip), just noting that a red analyze now hides the shell
  tools' own verdict too.
- If a later caller needs to disable the `run-wire-test.sh` entry, allow `SELFTEST_TIMEOUTS=name=` to mean
  "use SELFTEST_TIMEOUT"; today an empty `seconds` is bad input.

## Commit message

```
Fail-fast check.sh and per-script limits for selftest.sh

check.sh gains --fail-fast / CHECK_FAIL_FAST=1: when format or analyze fails,
each later check prints SKIPPED <suite> (<check> failed), none runs, exit 1;
off by default. CHECK_DART/CHECK_FLUTTER name the commands so tests can stub
them, and --list output is unchanged.
selftest.sh gains SELFTEST_TIMEOUTS (basename=seconds, default
run-wire-test.sh=240); SELFTEST_TIMEOUT stays the default and the TIMEOUT line
names the limit used.
New tools/tests/check-failfast-test.sh (9 cases) and selftest-limits-test.sh
(7 cases) fail on the old tools; tools/check.sh tools passes in 278 s.
```

## Status row

| M16 process3 p3b | done: check.sh fail-fast (`CHECK_FAIL_FAST=1`/`--fail-fast`, `SKIPPED` lines, `CHECK_DART`/`CHECK_FLUTTER` hooks, `--list` unchanged) and selftest.sh per-script limits (`SELFTEST_TIMEOUTS`, default run-wire-test.sh=240, TIMEOUT line names the limit), with 2 new self-tests; `tools/check.sh tools` PASS (278 s) | open: docs/dev-tools.md not updated (outside allow:) and p3c/p3f still have to set `CHECK_FAIL_FAST=1` |

## Delete

- none
