# m16 process5 wave 1 review — claude-worker (p5a)

## Summary

Verdict: **small fixes** — 9 findings: 0 must, 1 should, 8 could.

- should: the report's `tools/check.sh tools` PASS cannot be tied to the committed files (p5a-report.md:20).
- could, and the one that matters next: the values the report lists as asserted (`num_turns` 3, the four token counts, `costUSD`) are asserted by no case (p5a-report.md:27).
- could: the stand-in's denial answer and its exit-2 input checks (report decisions 5 and 6) have no case of their own, and the self-check names the wrong cases for the args file.

## Findings

- **should** docs/briefs/m16/process5/p5a-report.md:20 the report calls the 586 s `tools/check.sh tools` PASS a run "on the final files", but run.log:12 records the job parked at 18:47 "inside its own tools check", after that 18:33 run → say which revision the PASS covers, or re-run `tools/check.sh tools` on the committed files.
- **could** docs/briefs/m16/process5/p5a-report.md:27 the report lists `num_turns` 3 and "tokens 1200 in / 80 out / 9000 cache read / 400 cache write, `costUSD` 0.0012" as values the cases assert, but the ok case (tools/tests/claude-worker-test.sh:141-144) checks field names and enum values only → add the numbers to that case or list them as filler.
- **could** tools/tests/claude-worker-test.sh:125 `has "permission_denials"` is true of every `PREFLIGHT FAILED` line (tools/flash.sh:401 prints the field name whatever the denials hold), so the denial case tests only its exit code and the stand-in's denial answer (exit 0, report decision 5) is never run directly → add a stub case asserting exit 0 and a non-empty `permission_denials`.
- **could** tools/fake-claude-worker.sh:47 the exit-2 checks the report's decision 6 names (a bad `FAKE_CLAUDE_MODE` at :48, a non-numeric `--max-turns` at :43) have no case, so a stand-in that silently defaulted would still pass the suite → add the two cases.
- **could** docs/briefs/m16/process5/p5a-report.md:155 the self-check says the args file is written by "cases 7-9, 13-15", but it is set in cases 6-12 (tools/tests/claude-worker-test.sh:102,116,123,128,133) and not in 13-15 → name those cases.
- **could** tools/fake-claude-worker.sh:74 the fallback `cap="$cap_default"` is a second copy of flash.sh's default 35 (tools/flash.sh:242) that no case runs, so the two can drift silently → exit 2 when `--max-turns` is missing, or add a case for the fallback.
- **could** tools/fake-claude-worker.sh:68 `-h` prints fixed header lines 2-25, an option the brief did not ask for and no case covers, so a header edit truncates or leaks the help → drop it or derive the header's end and add a case.
- **could** tools/tests/claude-worker-test.sh:87 the plain-flash case inherits `FLASH_MODEL` and `FLASH_MAX_TURNS` from the caller, so a shell that exports either gets a false FAIL → run it with `env -u FLASH_MODEL -u FLASH_MAX_TURNS`.
- **could** tools/fake-claude-worker.sh:111 `num_turns=$((cap + 1))` reads a zero-padded cap as octal, so `FAKE_CLAUDE_MODE=max_turns bash tools/fake-claude-worker.sh --max-turns 08` dies on "value too great for base" and prints no JSON → `$((10#$cap + 1))`.

## Decisions to confirm

- tools/fake-claude-worker.sh:111 `num_turns` = cap + 1 encodes the parallel-batch quirk (HANDEDITS.md:5 records the same observation once); any later test that reads turns from a stand-in run inherits it.
- tools/fake-claude-worker.sh:70 a denied tool exits 0 (decision 5), so a caller that trusts the CLI's exit code reads a denial as success; only flash.sh's preflight grep catches it — confirm that before another caller uses the stand-in.
- tools/fake-claude-worker.sh:117 auth answers `subtype error_during_execution` (decision 4, left open by the brief); tools/job-metrics.sh prints the subtype in its result cell, so the stand-in's choice becomes the expected value of any metrics test.
- tools/claude-worker.sh:16-29 the isolation list is stated, not tested; only a real Haiku rehearsal can show `--safe-mode` loads no CLAUDE.md, hooks or MCP servers — confirm p5b/p5c checks it.

## Could not check

- Nothing ran: the sandbox refused approval for `bash tools/tests/claude-worker-test.sh` and for `bash tools/fake-claude-worker.sh`, so every finding comes from reading, and the report's 6 s / 15-case / 586 s claims are unverified here.
- The tests-first FAIL lines and the "PASS 586 s" could not be reproduced; run.log's 18:47 parking is the only evidence about the final check.
- `docs/briefs/m16/process5/run-findings.md` does not exist, so there are no entries about this job.
- The worktree churn the self-check 4 lists (`docs/design/*.png`, `tv_test_app/windows/flutter/generated_*`) was not inspected; the commit itself holds only the four allowed files.

## Commit message

```
Review m16 process5 wave 1: claude-worker (p5a)

One should: the report's tools/check.sh PASS cannot be tied to the
committed files, since run.log:12 shows a later check still running.
Coulds: the turn, token and cost values the report calls asserted are
not, the stand-in's denial answer and exit-2 input checks have no case,
the self-check names the wrong cases for the args file, its 35-turn
fallback duplicates flash.sh, --help slices fixed header lines, the
plain-flash case inherits FLASH_MODEL, and a zero-padded cap is read
as octal.
```

## Status row

| p5a review | done: findings in docs/briefs/m16/process5/wave1-p5a-review-report.md (9: 0 must, 1 should, 8 could) | open: the check-PASS claim, the unasserted values, the stand-in's untested denial and input checks, and six small test/style fixes |

## Delete

- none
