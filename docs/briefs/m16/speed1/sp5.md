job: M16 speed1 sp5: tools/job-metrics.sh gets a wall-time column
pub: no
turns: 35
expected-min: 45
tests-first: exempt (shell tools: run the new test first and show its FAIL lines in the report)
stop: after it. Do not touch other tools or docs/dev-tools.md.
read: docs/briefs/templates/COMMON.md · tools/job-metrics.sh:1-167 (all) · tools/tests/job-metrics-test.sh (its fixtures and report helper) · docs/briefs/m16/process6/run.log (shape: `<time> start <job>`, `<time> <job> finished: result 0 (31 turns, 18 min)`, `resume <job>`)
changes: WALL · wall_min
decisions (owner, Nov 23): the table shows start-to-finish wall time next to the model minutes, because checks and waits are 35-70% of a wave.
do:
1 Write tools/tests/job-wall-test.sh first (temp batch folder with a flash-<job>.log and a run.log with timestamps): a job started 10:00:00 and finished 10:07:30 shows WALL 7.5; a job with a `resume` line counts from its LAST start or resume line; no run.log, or no start or finished line for the job, shows `-`; review logs (`-review`, `wave1-review`) show `-`.
2 tools/job-metrics.sh: new column WALL (minutes, one decimal) after MINUTES; the METRICS line gets `wall=<n>` after `min=`. Existing columns keep their meaning; update the header comment. Update tools/tests/job-metrics-test.sh only where it pins the old column list or METRICS shape.
3 Run `bash tools/tests/job-wall-test.sh` and `bash tools/tests/job-metrics-test.sh`; both must pass.
allow: tools/job-metrics.sh · tools/tests/job-wall-test.sh · tools/tests/job-metrics-test.sh · docs/briefs/m16/speed1/sp5-report.md
check: format
report: docs/briefs/m16/speed1/sp5-report.md
