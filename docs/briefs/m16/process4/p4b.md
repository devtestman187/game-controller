job: M16 process4 p4b: tools/probe-deps.sh, a stub patch analyzed in a throwaway worktree
pub: no
stop: after it. Only the new script, its test and fixtures.
tests-first: exempt (new shell tool: run the new test against a stub first and show FAIL lines; say so in the report).
expected-min: 35
turns: 120
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process4/PLAN.md (goal 2) · tools/run-base.sh (limit and kill-tree pattern) · tools/review.sh header (layers check, how it reads changed lines via git add -N) · tools/commit-job.sh lines 70-110 (allow parsing) · docs/briefs/m16/process4/replay/wave1/i1a.md and probe-i1a.patch (the real case: two new message types break two switches)
decisions (owner, Nov 22): a brief may carry one line probe: <patch> (a tiny committed patch adding the new class, enum value or constant; the path is from the repo root, else from the batch folder). For each such job: add a throwaway worktree (git worktree add --detach, base ${PROBE_BASE:-HEAD}), git apply the patch, run ${PROBE_PUB_CMD:-flutter pub get} then ${PROBE_ANALYZE_CMD:-dart analyze --fatal-infos} for the whole workspace and, when PROBE_REVIEW is not 0, ${PROBE_REVIEW_CMD:-bash tools/review.sh} after git add -N. List every file with an analyze error. FAIL when a file is in no job's allow:, or only in the allow: of a job of the SAME wave as the probe job (a dependence between jobs of one wave: move the contract to an earlier wave or merge the jobs), or only in a later wave's. A review.sh layers FAIL in a file the probe job allows is a WARN. The patch's own files are exempt. The worktree is removed always (trap, also on timeout and Ctrl-C).
do:
1 NEW tools/probe-deps.sh <batch dir>: lines FAIL / WARN / PROBE <job>: <n> error files, a RESULT last line; exit 0 ok, 1 FAIL, 2 bad use, 3 timed out or setup failed (never a pass). PROBE_MAX_MIN (default 10, unit RUN_LIMIT_UNIT_S seconds, default 60) kills the process tree. No probe: line in the batch: says so, exit 0.
2 NEW tools/tests/probe-deps-test.sh with fixtures under tools/tests/fixtures/probe-deps/: each case builds a tiny git repo in a temp folder, stub analyze and pub commands via the env, and checks: clean probe (0), a switch broken by a stub in a file no job allows (1), the same file allowed by a job of the same wave (1, dependence), allowed by the probe job (0), timeout (3) with the worktree gone, git worktree list clean after every case. Under 20 s.
allow: tools/probe-deps.sh · tools/tests/probe-deps-test.sh · tools/tests/fixtures/probe-deps/ · docs/briefs/m16/process4/p4b-report.md
check: tools
report: docs/briefs/m16/process4/p4b-report.md
rules: aim 90-110 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
