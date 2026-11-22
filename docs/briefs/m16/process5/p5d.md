job: M16 process5 p5d: docs/dev-tools.md entries for claude-worker.sh, fake-claude-worker.sh, job-metrics.sh and the WORKER switch
pub: no
stop: after it. docs/dev-tools.md only.
tests-first: exempt (docs only).
expected-min: 25
turns: 80
read: docs/briefs/templates/COMMON.md · docs/dev-tools.md (the flash.sh and run-jobs.sh entries: match their style and length) · tools/claude-worker.sh · tools/fake-claude-worker.sh · tools/job-metrics.sh (their header comments; they exist from wave 1) · docs/briefs/m16/process5/p5c.md (the WORKER switch is written in the same wave: describe it from this brief) · docs/design/claude-only-model.md
changes: dev-tools
decisions (owner, Nov 22): document claude-worker.sh (use, env CLAUDE_WORKER_MODEL and CLAUDE_WORKER_MAX_TURNS, isolation achieved and not achieved exactly as its header says, preflight exit 7), fake-claude-worker.sh (modes, env), job-metrics.sh (table columns, --append, METRICS line), the runner's WORKER=flash|claude (default flash, logged as `worker: <name>` after `start at`, FLASH_CMD still overrides, METRICS lines appended at the end). Add one sentence under the flash.sh entry: FLASH_WORKER=claude. One more fact for the worker entry: `--max-turns` counts model rounds, while the CLI's num_turns (and the runner's turn cap) counts every tool call of a parallel batch, so a job can report more turns than its cap (identity1 i1g2: 161 turns under cap 150; checked Nov 22 with --max-turns 3: 1 round, 11 turns).
do:
1 Add the entries where the existing tool entries sit. Do not rewrite other entries. Keep each to 6-12 lines.
allow: docs/dev-tools.md · docs/briefs/m16/process5/p5d-report.md
check: format
report: docs/briefs/m16/process5/p5d-report.md
rules: aim 40-60 turns · write only inside allow:.
