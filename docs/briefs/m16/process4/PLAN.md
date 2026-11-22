# M16 process4 plan (tools batch): DRAFT, not run

Source: owner approval of Nov 22 and the briefs analysis (identity1 misses: wave overlap, a new file outside allow, `changes:` hits in tests, a switch broken by a stub, limits that killed whole waves). Only tools/ and tests; no app code. Replay material from git history is in `replay/` (briefs, probe patch, BASES.txt, expected.txt).

## Goals
1 `tools/brief-check.sh` (wave overlap, new file outside allow, allow size WARN, `changes:` hits outside every allow); wired into `run-jobs.sh --dry-run` and the start (refuses; `BRIEF_CHECK_SKIP=<reason>` overrides, logged).
2 `tools/probe-deps.sh` (a `probe:` stub patch, throwaway worktree, workspace `dart analyze` and review.sh layers, error files must be in some allow; same-wave dependence is a FAIL). Run by the driver, not wired into the runner (it needs minutes and `pub get`).
3 Runner: a stopped job parks alone, siblings finish and are kept; over-cap job with its own checks passing is accepted with WARN (flash.sh `--max-turns 150` stays); estimate floors (max of brief and usage median, f<n> at least 25, run backstop floor 45).
4 `tools/apply-job.sh` replaces freehand hand-fixes.
5 Self-tests for all (`bash tools/check.sh tools`); env leak fixed in the wire tests.
6 Replay of identity1 waves 1 and 2.

## Waves
| Wave | Job | Scope | Owned files | Min | Allow |
|---|---|---|---|---|---|
| 1 | p4a | brief-check + test + fixtures | brief-check.sh, test, fixtures dir | 35 | 4 entries, 1 package |
| 1 | p4b | probe-deps + test + fixtures | probe-deps.sh, test, fixtures dir | 35 | 4 |
| 1 | p4e | estimate floors | run-limits.sh, run-limits-test.sh | 30 | 3 |
| 2 | p4c | poll loop to run-wave.sh, siblings kept, cap WARN, gate seam, env unsets | run-jobs.sh, run-wave.sh (new), 6 tests | 40 | 9 |
| 2 | p4d | apply-job | apply-job.sh, test | 30 | 3 |
| 2 | p4f | replay fixtures and test | test, fixtures dir | 30 | 3 |
| 3 | p4g | brief-check gate (run-gate.sh) with BRIEF_CHECK_SKIP, env-leak regression test | run-gate.sh, test | 25 | 3 |

Owner split (Nov 22): p4g is wave 3 because run-jobs.sh and the wire tests belong to p4c alone; p4c leaves a seam (run-gate.sh sourced if present) and does the env unsets itself, p4g adds the gate and the leak regression test. A brief-check `changes:` hit allowed only by a later wave is a FAIL. Total by wave maximum 35 + 40 + 25 = 100 min, plus the combined check (about 12 min) and the run review: about 1 h 40 min. No two jobs of a wave share a file; selftest.sh is not edited (it globs `tools/tests/*-test.sh`; fixtures live in subfolders it does not glob). Wave 2 needs wave 1 (p4c calls brief-check.sh and the floors, p4f runs brief-check). p4c is the riskiest (moves the poll loop to run-wave.sh to get under the 400-line pin; 40 min estimate, 120 turns; the brief says env leak last). Nothing here edits flash.sh, `.claude/**`, release.sh or wsl-*.sh.

Replay choices: brief-check searches a git ref (`BRIEF_CHECK_REF`), so the replay needs no checkout; probe-deps on old commits is slow and runs only in REHEARSAL (`REPLAY_PROBE=1`). The wave-1b dependence (i1b on i1a2's compile fix) is reproduced by `replay/wave1-split` (i1a2 in the same wave as i1a). The untracked arena_character_painter.dart is covered by apply-job.sh and a probe layers WARN, as rehearsal items.

## What the driver does by hand
See HANDEDITS.md: protected or owner files (`.claude/agents/thumb-batch.md` step 1, optional `thumb-haiku.md`, `docs/briefs/templates/job.md`, COMMON.md, flash-digest.md, dev-tools.md). New driver routine from this batch on: write briefs with `changes:` and `probe:` lines, run `brief-check.sh` and `probe-deps.sh` BEFORE committing briefs, use `apply-job.sh` for every hand-fix, order shared-type changes contract-first (the type or message in an earlier wave, its users later).

## Where Haiku runs
Judgment (brief writing, stop diagnosis, review verdicts, commit decisions) stays with Sonnet. Every mechanical step goes to a Haiku agent whose report is data:
1 brief-check.sh and probe-deps.sh: run, return only the flagged files (FAIL/WARN lines).
2 The waiter: `thumb-wait` (exists).
3 After a stop: an evidence pack in one file `<dir>/EVIDENCE.md` (run.log tail, the job's report Summary, failing test names, files touched outside allow) of about 30 lines; Sonnet diagnoses from that, not raw logs.
4 An approved hand-fix: run `apply-job.sh`, confirm the logged HAND-FIX file list, run review.sh and the job's tests, report.
5 Churn restore, git status, the full check in the background and its wait; report pass/fail with failing suite names.
6 First-pass triage of REVIEW.md findings: confirm each file:line exists, quote 5 lines around it; Sonnet only rules.
7 Batch end: run.log metrics extract (turns, minutes, stops, hand-fixes, like metrics.md) and the DRIVER-NOTES append.
8 REHEARSAL.md's mechanical items, one PASS/FAIL line each.
A fixed `thumb-haiku` agent (Bash, Read; never edits repo code, commits, pushes or stops runs) is proposed in HANDEDITS item 5, because drivers fell back to general-purpose Haiku when `thumb-wait` was missing (agents load at session start). Expected saving: about 40-60 driver calls per batch (process3 used 211, mostly polling and log reading) and the driver's context stays under 100k.
