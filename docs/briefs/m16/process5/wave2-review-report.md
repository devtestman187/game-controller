# m16 process5 wave 2 review — p5c and p5d

## Summary

Verdict: **needs Claude** — 4 findings: 1 must, 0 should, 3 could.

- must: `docs/dev-tools.md:550` (with `:542`, `:552`, `:589`) documents the runner's `WORKER` switch, its `worker:` line and
  its end-of-run `METRICS` append, and `tools/run-jobs.sh` has none of them (p5c never landed).
- could: `docs/dev-tools.md:564` drops two claims of the claude-worker header while `p5d-report.md:32` says none was dropped.
- could: `docs/dev-tools.md:577` leaves three of the fake CLI's exit-2 cases out; `p5d-report.md:5` counts 8-9 lines for
  12-line entries.
- p5c has nothing to review: no commit, no report, and its two allow-listed files are unchanged.

## Findings

- **must** docs/dev-tools.md:550 the entry documents `WORKER=flash|claude` — the `worker: <name>` line after `start at`, `FLASH_CMD` defaulting to `tools/claude-worker.sh`, exit 2 for another value, and the METRICS append at `:552`/`:589` — but `tools/run-jobs.sh` has no `WORKER` anywhere (`grep WORKER tools/run-jobs.sh` is empty, its last commit is f458237e) and no `tools/job-metrics.sh` call, because p5c was parked (STOP.md, run.log 20:25), so the page tells a reader to run a switch that silently does nothing → land p5c (or hand-apply its allowed files) before this section ships, or hold the four `WORKER` bullets out of the page until it lands.
- **could** docs/dev-tools.md:564 the achieved-isolation bullet drops "so nothing resumes later" (tools/claude-worker.sh:19) and `managed-settings.json` (tools/claude-worker.sh:24) from the header's two lists, which p5d-report.md:32 claims was a compression that kept every claim → add the two clauses back, or soften the report's claim.
- **could** docs/dev-tools.md:577 the exit-code bullet gives exit 2 only for a bad mode and a non-whole `--max-turns`, while tools/fake-claude-worker.sh:58, :62 and :82 also exit 2 for a missing option value and an unwritable `FAKE_CLAUDE_ARGS_FILE` → say "2 for bad use (a bad mode, a non-whole `--max-turns`, a missing option value, an unwritable args file)".
- **could** docs/briefs/m16/process5/p5d-report.md:5 "four entries (8-9 lines each" undercounts two of them: the claude-worker entry is docs/dev-tools.md:554-565 and the job-metrics one :579-590, 12 lines each (the brief allowed 6-12) → say 8-12, or count the raw lines added.

## Decisions to confirm

- docs/briefs/m16/process5/p5d-report.md:26 — a feature not in the tree is written into the manual's body with only a Hand-over note; confirm the section stays (p5c hand-applied next) or is reverted from `docs/dev-tools.md`.
- docs/dev-tools.md:546 the two fences name the live batch `docs/briefs/m16/process5`; that matches the page's other examples (`:226`, `:508`), so it is safe, but the example is a batch that will be deleted with this milestone.
- docs/dev-tools.md:563 the "161 turns under cap 150" and "`--max-turns 3`: 1 round, 11 turns" figures come from the brief; they were not re-measured here.

## Could not check

- p5c: it left no commit and no `p5c-report.md`; `tools/run-jobs.sh` and `tools/tests/run-worker-switch-test.sh` are unchanged (the test file does not exist), and its `flash-p5c.log` is not in the batch folder, so only run.log's 67-minute park line describes it.
- No `docs/briefs/m16/process5/run-findings.md`, so there are no runner findings about this wave.
- The report's `tools/check.sh format` PASS was not re-run: a markdown-only change is outside that check, so it can show nothing either way.
- The three new anchor links were slugged by hand with GitHub's heading rule, not rendered on the site.

## Commit message

```
Review m16 process5 wave 2: p5d dev-tools entries

p5d's four new entries are measured against claude-worker.sh,
fake-claude-worker.sh, job-metrics.sh and flash.sh, and against its
own brief. One must: the WORKER entry (and the "the runner does this"
aside) documents the runner switch that p5c never landed, so the page
describes a feature the tree lacks. Three coulds: two claude-worker
header claims dropped, three fake-CLI exit-2 cases missing, and the
report's line count. p5c has nothing to review.
```

## Status row

M16 process5 wave 2 review: p5d reviewed (1 must, 3 could); open: land or hand-apply p5c, then re-check the WORKER entry and drop it if the runner is not to have it.

## Delete

- none
