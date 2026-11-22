job: M16 process4 p4e: estimate floors (usage median, fix jobs, run backstop)
pub: no
stop: after it. Only tools/run-limits.sh and its unit test.
tests-first: exempt (shell tool: extend the test first and show FAIL lines against the old tool; say so in the report).
expected-min: 30
turns: 120
read: docs/briefs/templates/COMMON.md · tools/run-limits.sh (whole file) · tools/tests/run-limits-test.sh (fixtures to copy) · docs/briefs/m16/process3/run.log (p3f estimated 15 and hit 22, f1 30 and hit 45) · docs/briefs/m16/identity1/run.log (i1e2 and f1: estimate 15, took 20+)
decisions (owner, Nov 22): the estimate is a floor, not the brief's word alone: run_expected_min = max(the brief's expected-min:, the median of the job's usage rows); a job whose brief basename matches ^f[0-9]+$ is at least RUN_FIX_FLOOR_MIN (25). The run backstop also has a floor, RUN_BACKSTOP_FLOOR_MIN (45), so a one-job run is not cut at 20 min. A median under a minute still counts as none. All knobs go through run_number and are named in the header.
do:
1 Extend tools/tests/run-limits-test.sh first: brief 20 and median 30 gives 30; brief 40 and median 10 gives 40; no brief line, median 12 gives 12; f2 with brief 10 gives 25; f2 with brief 40 gives 40; a non-fix name is not floored; backstop of one 15-min job gives 45 (the floor) and of three 40-min jobs gives 150; the helpers print minutes whatever RUN_LIMIT_UNIT_S is.
2 Implement in tools/run-limits.sh; update its header comment (how to read each helper). Keep every existing case passing.
allow: tools/run-limits.sh · tools/tests/run-limits-test.sh · docs/briefs/m16/process4/p4e-report.md
check: tools
report: docs/briefs/m16/process4/p4e-report.md
rules: aim 60-80 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
