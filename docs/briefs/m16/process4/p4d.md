job: M16 process4 p4d: tools/apply-job.sh, the one way to hand-apply a kept job
pub: no
stop: after it. Only the new script and its test.
tests-first: exempt (new shell tool: run the new test against a stub first and show FAIL lines; say so in the report).
expected-min: 30
turns: 120
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process4/PLAN.md (goal 4) · tools/run-steps.sh lines 15-70 (outside_files, copy_paths, apply_safe: the kept worktree is found in the flash log, line `the worktree is kept: <path>`) · tools/commit-job.sh lines 70-110 (allow parsing) · tools/churn.sh · docs/flash-digest.md (Repair a stop: the HAND-FIX line format)
decisions (owner, Nov 22): identity1's i1f hand-fix left arena_character_painter.dart untracked and other hand-fixes copied more than the allow list. This tool replaces freehand fixes.
do:
1 NEW tools/apply-job.sh <batch dir> <job> [--tree <dir>] [--only <path>...] [--dry] [--force]: tree from --tree, else the kept path in <batch>/flash-<job>.log (APPLY_LOGS overrides the log folder). Copies (binary-safe, never git add or commit) from the tree every changed, deleted and untracked (not ignored) file under the job's allow: paths and its report: path. Files changed outside allow: are listed as SKIPPED outside allow (tools/churn.sh churn named separately) and never copied; an --only path outside allow: is refused (exit 1, nothing copied). Refuses (exit 1) when a target path has uncommitted changes in the repo, unless --force. Appends one line to <batch>/run.log: `HAND-FIX <job>: apply-job.sh applied <n> files: <a>, <b>` (no other job's name before a colon). Prints the files and the reminder to run tools/review.sh and the job's tests, then commit named paths. Exit 0 applied, 1 refused, 2 bad use.
2 NEW tools/tests/apply-job-test.sh: temp git repo plus a fake kept tree: modified, new untracked and deleted files inside allow are applied; a file outside allow and a churn file are skipped and named; --only outside allow refused; dirty target refused, --force passes; --dry changes nothing and logs nothing; the run.log line is exact. Under 15 s.
allow: tools/apply-job.sh · tools/tests/apply-job-test.sh · docs/briefs/m16/process4/p4d-report.md
check: tools
report: docs/briefs/m16/process4/p4d-report.md
rules: aim 70-90 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
