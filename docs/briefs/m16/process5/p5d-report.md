# p5d report: dev-tools.md entries for the claude worker and its tools

## Summary

Docs only. `docs/dev-tools.md` gained a new top-level section, **The claude worker: tools/claude-worker.sh**, with four entries (8-9 lines each, after the flash.sh and run-jobs.sh entries' style: a short intro, a command fence, bold-lead bullets):

- **The runner's worker (tools/run-jobs.sh): WORKER=flash|claude** — default flash, an explicit `FLASH_CMD` wins, any other value exits 2, `worker: <name>` in `run.log` after `start at` (none on a dry run), and the METRICS lines the runner appends before the last `RESULT:` line (never changing the run's result).
- **tools/claude-worker.sh** — flash.sh with `FLASH_WORKER=claude` (it execs flash.sh); `CLAUDE_WORKER_MODEL` (`claude-haiku-5-5`, exact id) and `CLAUDE_WORKER_MAX_TURNS` (35); no `--web`; flash.sh's exit codes and 7 for a failed `--preflight`; isolation achieved and not achieved, compressed from the header without adding or dropping a claim.
- **tools/fake-claude-worker.sh** — the stand-in CLI, `FAKE_CLAUDE_MODE` (ok, denial, max_turns, auth) and `FAKE_CLAUDE_ARGS_FILE`, its exit codes 0/1 as the CLI's and 2 for bad use.
- **tools/job-metrics.sh** — the table columns (JOB, WORKER, MODEL, TURNS, IN, OUT, CACHE, MINUTES, RESULT), `-` for a missing field, the `worker:` line winning over the model, `--append`'s `METRICS ...` line and its idempotence, exit 0/2.

Values documented as given in the brief: `--max-turns` counts model rounds while `num_turns` (and the runner's turn cap) counts every tool call of a parallel batch, so identity1 i1g2 reported 161 turns under cap 150; checked Nov 22 with `--max-turns 3`: 1 round, 11 turns.

One sentence (`- **FLASH_WORKER=claude** ...`) was added under the flash.sh entry, with a link to the new section. No other entry was changed, and the top script table was left alone (it has no flash.sh or run-jobs.sh row either).

## Checks

- `tools/check.sh format` — PASS (11 s), run twice: after the first insert and after the small wording fixes. No Dart file changed, so it only confirms the tree as it was.

## Self-check (review-rules part A)

1. Host setups: none applicable — docs job, no runtime behaviour changed.
2. Kept state: none applicable; the only state described is the new `worker:` line (after `start at`) and the METRICS lines, both quoted from p5c's brief.
3. Interaction with pause menu, host away, etc.: none applicable (no UI or game state involved).
4. Stayed inside `allow:` — only `docs/dev-tools.md` and this report changed.
5. Stopped nowhere: no file outside `allow:` was needed. The one thing I could not verify (p5c has not landed in this tree yet: `tools/run-jobs.sh` still has no `WORKER`) is written from p5c's decisions, as the brief instructs.
6. Looks: no look-sized widget and no pixel height is involved; no menu or TV look changed.

## Decisions

- **Placement.** The flash.sh and run-jobs.sh entries sit as prose inside "DeepSeek Flash helper", but that section is about DeepSeek and the claude worker is not; a new top-level section after it (before "Moving development to another computer") keeps the DeepSeek text intact and puts the four related entries together. The WORKER switch is its own subsection there because it selects this worker for the whole run.
- **Length.** The claude-worker entry's isolation bullets are compressed from the script header, not paraphrased: the achieved/not-achieved split and every claim are the header's.
- **Links.** Section-internal anchors follow the page's existing style (`#toolsjob-metricssh`, as `#toolschecksh`); `[design/claude-only-model.md](design/claude-only-model.md)` follows the page's relative-link style.

## Hand-over

Nothing open. When p5c lands, check that its `note "worker: $WORKER"` text and the METRICS append position match the WORKER entry; if p5c appends on a STOPPED end only differently, that bullet is the one line to adjust. `tools/tests/job-metrics-test.sh` (linked from the job-metrics entry) and `tools/tests/claude-worker-test.sh` are both in the tree.

## Commit message

```
docs(dev-tools): claude worker, WORKER switch and job-metrics.sh

dev-tools.md gains a section on running a batch on the Claude
subscription login: the runner's WORKER=flash|claude (default flash,
logged as a `worker:` line, FLASH_CMD still winning, METRICS lines
appended at the end), tools/claude-worker.sh (its two env vars, what it
isolates and does not, the round-versus-tool-call turn count, exit 7
from --preflight), tools/fake-claude-worker.sh and tools/job-metrics.sh.
The flash.sh entry gains the FLASH_WORKER=claude sentence that points
at them; no other entry changes.
```

## Status row

M16 process5 p5d: dev-tools.md documents the claude worker, its fake, job-metrics.sh and the runner's WORKER switch; open: the WORKER text matches p5c's brief, to re-check when p5c lands.

## Delete

- none
