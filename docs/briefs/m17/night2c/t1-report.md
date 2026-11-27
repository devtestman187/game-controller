# night2c t1 report: agent-cost per-agent split and the driver REPORT fields

## Summary

- `tools/agent_cost.py`: new `--agents` flag. After the normal output it prints one row per subagent transcript (agent type and description from `.meta.json`, calls, dollars by model, sorted by dollars), a row for headless runs when there are any, and a last row `main transcripts`. The rows sum to the total (`rows sum $...`).
- Same flag prints the driver REPORT line: `driver: calls N, largest context K tokens, longest wait M min`. Main transcripts only (subagents and headless runs excluded).
- `--line` output and the table are unchanged; the new output only appears with `--agents`.
- `tools/agent-cost.sh`: usage line and header note for `--agents`.
- `tools/tests/agent-cost-test.sh`: 10 new cases in a separate fixture root (so the existing expected values stay as they were). Written first: on the base 8 of them FAIL, after the change 31 of 31 PASS.
- `docs/driver-kit.md` section 12: the report list now has call count, largest context and any wait over about 55 min, from `tools/agent-cost.sh --since <time> --agents` (the `driver:` line).
- Decisions:
  1. Headless runs (the `flash-*.log` runs) get their own row, so the rows sum to the total. The brief named only the main row; without this row the sum would be short whenever logs are in range.
  2. The driver line is printed only with `--agents`, not added to `--line`, to keep the `--line` format unchanged (the brief's stop rule).
  3. The dollar cells in the agent rows use 4 decimals; 2 decimals hides the split of small agents.
  4. The longest wait is always printed in minutes (longest gap between two consecutive main calls, per main transcript). The 55-minute threshold is left to the reader of the report.
  5. The `--since` example in the driver-kit text is `<time>`, not `<epoch>`: the tool does not accept epoch seconds (ISO, `today`, or `30m` / `2h` / `1d`).
- Checks: `tools/tests/agent-cost-test.sh` 31 PASS, 0 FAIL. `tools/mine.sh` ok (format, analyze, party_host tests 72 OK).

## Files changed

- `tools/agent_cost.py`: `agent_name()` (agent type + description); `print_agents()` (rows, rows sum, driver line); `--agents` argument; per-owner and driver accumulation in the call loop (the cost value is computed once, `d`, with the same float sum as before).
- `tools/agent-cost.sh`: usage line `[--agents]` (wrapped to a second line to keep 120 columns) and a 6-line header note on the rows and the driver line.
- `tools/tests/agent-cost-test.sh`: header note; 10 new cases at the end (fixture root `$tmp/agents`, two subagent transcripts with `.meta.json`, one main transcript, plus the existing headless logs for the headless row).
- `docs/driver-kit.md`: section 12 report list gets the driver fields and the command.

## Computed test values

Fixture (opus $4/$20, sonnet $2/$10, haiku $0.10/$0.50 per 1M; cache read 0.05x for opus and sonnet, 0.1x for haiku):

| Owner | Calls | Calculation | Dollars |
|---|---|---|---|
| main transcripts | 3 | m1 0.044 (4000 + 40000 / 1e6), m2 0.040 (20000 out + 20000 read), m3 0.180 (20000 in + 160000 cw1h) | 0.2640 (opus) |
| thumb-haiku Evidence pack | 2 | haiku 0.0006 (100 + 500), sonnet 0.0100 (10000 out) | 0.0106 |
| thumb-build Wave 2 build | 2 | sonnet 0.1000 (10000 out), opus 0.0200 (1000 out) | 0.1200 |
| headless worker runs (existing logs) | 2 | haiku 0.0236, sonnet 0.3720 | 0.3956 |

- Rows (non-headless) sum: 0.2640 + 0.0106 + 0.1200 = 0.3946, the `rows sum $0.3946` line. With the headless runs: 0.7902.
- Driver: 3 main calls; largest context = m2, 100000 tokens (cache read; m3 is 25000, m1 is 1000); gaps 10 min (10:00 to 10:10) and 70 min (10:10 to 11:20), so `longest wait 70 min`.
- Without the flag: the test checks no `driver:` or `rows sum` line and `total $0.39`.

## Self-check (review-rules part A)

1. Host setups: n/a, a tool with no host. Covered by the selftest only.
2. Kept state: none; each run reads the transcripts once and keeps nothing. The test `agents-off-unchanged` shows nothing new is printed without the flag.
3. Combinations: n/a for the game; `--match` and `--line` still apply to the rows (the match filter runs before the accumulation).
4. Stayed inside allow: yes; `git status` shows only the four allowed files from this job (plus the party_host files that were already modified before the job started; not touched by me).
5. Stop: nothing stopped.
6. Looks: n/a.

## Not verified

- The no-flag output is not compared byte-for-byte against the base file. I tried, but writing a base copy outside the worktree and running the tool on real transcripts both needed approval. The diff shows the no-flag path only gains a local variable `d` (same float sum). The selftest checks the absence of the new lines, not byte identity.
- `tools/mine.sh` reported "4 file(s) formatted" and ran the party_host tests (72 OK). Those party_host files were already modified before this job; I can't tell from the output whether the format step rewrote them.
- `main()` in `agent_cost.py` was already longer than the 40-line guideline; I added about 8 lines to it and did not split it (not asked).

## Questions

1. Should the longest-wait field print only when a wait is over 55 minutes (otherwise `none over 55 min`)? Now it always prints the longest gap.
2. Should the driver line also go into `--line` (the batch report's one-line form)? It would change the `--line` format, so I did not.
3. Should `job-metrics` print the driver fields? It is outside this job's allow list.

## Suggestions

- Add `--agents` to the batch report step (`tools/batch-report.sh`) so the REPORT fields come out without a manual run.

## Commit message — a draft

agent-cost: per-agent split and driver REPORT line (--agents)

With --agents, agent-cost prints one row per subagent transcript (agent type and
description from its .meta.json, dollars by model), a row for headless runs, and a
main row; the rows sum to the total. It also prints the driver REPORT line (main
call count, largest context, longest wait) for the batch report. Without the flag
the output is unchanged. Selftest gains 10 cases in their own fixture root.

## Status row

- night2c t1: agent-cost `--agents` (per-agent rows that sum to the total, driver REPORT line) and driver-kit section 12 report fields are done, selftest 31/31. Open: no check of the no-flag output byte-for-byte against the base; a decision on the 55-minute threshold and on putting the driver line in `--line`.

## Delete

- none
