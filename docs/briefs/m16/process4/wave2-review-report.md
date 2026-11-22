# Wave 2 review (p4c, p4d): findings

## Summary

small fixes.
0 must · 4 should · 5 could.
- **should** docs/flash-digest.md:31 still states the old limits rule (a job stops the run at its limit; the turn cap stops before the checks), which run-wave.sh inverts.
- **should** tools/run-jobs.sh:204 the gate seam (decision 3) has no test anywhere; deleting it fails nothing.
- **should** docs/flash-digest.md:37 is still the freehand "Repair a stop" section, while tools/apply-job.sh:4 says the tool is documented there.

## Findings

- **should** docs/flash-digest.md:31 — the limits line says "a job stops at its brief's `expected-min:` x1.5 ... and a job over its turn cap (120, ...) stops before the checks", while tools/run-wave.sh:27-51 parks the job (siblings continue) and accepts an over-cap job with result 0 under a WARN → rewrite the line to the parked/WARN rule (p4c's `allow:` did not include this doc, so it is Claude's or a doc job's edit).
- **should** tools/run-jobs.sh:204 — `gate_step` and the `run-gate.sh` sourcing at :97 are new behaviour with no test: no file under tools/tests builds a fixture `run-gate.sh`, so removing the seam would fail no case → add a case to tools/tests/run-jobs-split-test.sh with a fixture run-gate.sh whose `brief_gate` refuses, asserting `--dry-run` prints its message and exits 1 and the start stops with `STOPPED: brief gate: ...`.
- **should** docs/flash-digest.md:37 — "Repair a stop" still tells the reader to "hand-apply from the kept worktree" and never names tools/apply-job.sh, although tools/apply-job.sh:4 claims "Documented in docs/flash-digest.md, 'Repair a stop'", so the one-way tool the owner asked for has no doc entry → add one line naming `tools/apply-job.sh <batch> <job>` (with `--only`, `--dry`, `--force`) to that section.
- **should** docs/briefs/m16/process4/p4c-report.md:1 — neither report carries the part A self-check (six lines, one per rule, each with its test), p4c's pass list names run-wave, run-jobs-split, run-limits-wire, process3-fix1 and run-base but not run-wire-test, whose case 11 it edited, and neither records the brief's `check: tools` result, so the claims cannot be checked against the report alone → add the six self-check lines, the run-wire-test result and the check result to both reports.
- **could** tools/tests/process3-fix1-test.sh:157 — the case's elapsed bound was raised from 10 to 25 s, equal to the 25 s `timeout` on its own runner call at :131, so the bound can no longer fail on its own (the case finishes in about 10 s) → keep the bound below the timeout.
- **could** tools/tests/run-wave-test.sh:16 — the header says "the whole script runs in about 45 s" while the brief asks for under 20 s and case 1 asserts its own 20 s bound, so one of the two numbers is wrong → time the script and either correct the header or bring it under the brief's budget.
- **could** tools/tests/apply-job-test.sh:46 — every `allow:` entry is a file, so `covers`' folder branch (tools/apply-job.sh:111) and the rename handling at :150-155 are never exercised, although real briefs allow folders and jobs rename files → add a case with an allowed folder under `lib/` and one renamed file.
- **could** tools/run-limits.sh:5 — its comment names tools/run-steps.sh and tools/run-review.sh as the runner's helpers, now three files (run-wave.sh is sourced after it) → add run-wave.sh to that line.
- **could** tools/tests/run-base-test.sh:19 — the shared nine-name `unset` list leaves out RUN_BASE_CHECK_SKIP, which the runner honours at tools/run-jobs.sh:287, so a caller exporting it skips the very check every run-base case tests → add it beside RUN_BASE_CHECK_MAX_MIN in the six test files.

## Decisions to confirm

- tools/apply-job.sh:194 refuses (exit 1) when the tree changed nothing under the job's allow:, so a no-op apply reads as an error; the brief's exit table has no entry for "nothing to do".
- tools/apply-job.sh:196 runs the dirty-target check in `--dry` too, so a dry listing can be refused where the brief only asks a dry run to print and change nothing.
- tools/apply-job.sh:38 `cd`s to the repo root, so `<batch dir>`, `--tree` and `--only` resolve from there and not from the caller's directory; the test relies on it and the header does not say it.
- tools/run-wave.sh:59 parks a job over its cap whatever its result, so a result-4 job whose outside files are all churn (tools/run-steps.sh `apply_safe` would rescue it) is parked as well; decision 2 says "any other result", so this follows the letter of the brief.
- tools/run-jobs.sh:355 changes the stop cause to "jobs that failed or passed their limit (parked, not committed)"; tools/run-stop.sh:56 still classifies it by matching "jobs that failed", which happens to work but no test pins it.

## Could not check

- No test was run: shell execution was refused here, so every PASS, the brief's 20 s and 15 s budgets and the run-wave-test header's 45 s are unverified; the runner did run both hand-fix tests-first proofs (docs/briefs/m16/process4/run.log, 13:29:44 and 13:29:46), so "passes on the old code" is not at issue for either new test.
- No docs/briefs/m16/process4/run-findings.md exists, so there is no runner entry about these two jobs to weigh.
- tools/run-gate.sh does not exist yet (p4g's), so the seam's contract with `brief_gate` is unchecked against a real implementation.
- The turn counts and minutes in run.log come from `~/.thumbparty/flash-usage.tsv`, which is not in the repo.

## Commit message

```
docs: wave 2 review of p4c and p4d (findings only)

Judge the hand-finished p4c (parked jobs, cap WARN, run-wave.sh, gate seam) and p4d
(apply-job.sh) against their briefs and the guidelines. No must; four should: the stale
limits line in flash-digest, the untested gate seam, the missing apply-job doc entry, and
the reports' missing self-check and check results. Five could, mostly test coverage.
```

## Status row

m16 process4 wave 2 reviewed (p4c, p4d): 0 must, 4 should, 5 could; open: flash-digest.md:31 and :37, a gate-seam test, the two reports' self-check.

## Delete

- none
