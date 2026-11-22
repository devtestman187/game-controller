job: M16 process5 p5c: the runner's WORKER switch (flash|claude), logged at start, and metrics at the end
pub: no
stop: after it. tools/run-jobs.sh and one new test; no docs (p5d), no change to run-limits.sh.
tests-first: exempt (runner change in shell: the new test runs against the old run-jobs.sh first and must show FAIL lines; say so in the report).
expected-min: 45
turns: 120
read: docs/briefs/templates/COMMON.md · tools/run-jobs.sh (header lines 70-135 and helpers, the start near line 259, the end near line 363; every `${FLASH_CMD:-tools/flash.sh}`) · tools/run-review.sh (lines 60-115, uses FLASH_CMD) · tools/tests/run-wire-test.sh (fake repo and stub FLASH_CMD to copy) · tools/job-metrics.sh (p5b, same wave: `bash tools/job-metrics.sh <dir> --append`)
changes: WORKER · FLASH_CMD
decisions (owner, Nov 22): WORKER=flash|claude, default flash. flash: unchanged in every way. claude: FLASH_CMD defaults to tools/claude-worker.sh (an explicit FLASH_CMD still wins). Any other value stops the run with exit 2 and `WORKER must be flash or claude, got <v>`. Run-limits floors stay as they are.
do:
1 tools/run-jobs.sh: resolve WORKER once, before the first `${FLASH_CMD:-...}` use, so run-review.sh's calls see the same command (set FLASH_CMD itself when WORKER=claude and it is empty; do not edit run-review.sh). Right after the `start at` line add `note "worker: $WORKER"`. A dry run does not log it. Header comment: one paragraph on WORKER.
2 Before the final `RESULT: DONE` line (and on a STOPPED end too if one clean single place exists; else DONE only) run `bash tools/job-metrics.sh "$B" --append` when tools/job-metrics.sh exists, ignoring its failure; the run's result must not change because of it. A fixture without the script: no change.
3 NEW tools/tests/run-worker-switch-test.sh: (a) WORKER unset: run.log has `worker: flash` and the stub FLASH_CMD ran; (b) WORKER=claude with no FLASH_CMD: run.log says `worker: claude` and the preflight call is `tools/claude-worker.sh` (a stub copied there); (c) WORKER=claude with an explicit FLASH_CMD uses that; (d) WORKER=bad exits 2; (e) a finished run has METRICS lines (a stub job-metrics.sh); no job-metrics.sh: no error. Under 60 s.
allow: tools/run-jobs.sh · tools/tests/run-worker-switch-test.sh · docs/briefs/m16/process5/p5c-report.md
check: tools
report: docs/briefs/m16/process5/p5c-report.md
rules: aim 70-100 turns · write only inside allow: · tools/review.sh: no FAIL on your lines · if an existing tools/tests/run-*-test.sh fails because of the added `worker:` line, say which under Blocked (do not edit it).
