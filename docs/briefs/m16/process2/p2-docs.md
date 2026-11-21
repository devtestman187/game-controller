job: M16 process2 docs — document mine.sh, wait-run.sh, selftest.sh and the extract in dev-tools.md and the digest
pub: no
stop: after it. Docs only.
read: docs/briefs/templates/COMMON.md · docs/dev-tools.md (the tools list) · docs/flash-digest.md · .claude/agents/thumb-batch.md · tools/mine.sh · tools/wait-run.sh · tools/selftest.sh · tools/churn.sh (headers: usage, exit codes, env knobs) · docs/worker-extract.md
decisions (owner, Nov 21): wait-run.sh is for the next batch's no-polling trial; drivers keep their loop until the owner says otherwise.
tests-first: exempt docs.

do:
1 docs/dev-tools.md: one short section per script (what, usage line, exit codes 0/1/2/3 plus 4 for wait-run, the env knobs, the self-tests and `tools/check.sh tools`), plus a line on docs/worker-extract.md.
2 docs/flash-digest.md: a "Trial: wait-run" bullet in Run (`bash tools/wait-run.sh <dir>` blocks up to 170 s, prints new lines, exits 0 DONE / 1 STOPPED / 2 STALLED or OVERRUN / 4 still running; repeat until not 4) and a line under Workers that tools/mine.sh exists. No other digest changes.
3 .claude/agents/thumb-batch.md: step 3 says "trial: use bash tools/wait-run.sh <dir> (timeout 175000) instead of the for loop; fall back to the loop if it errors".
allow: docs/dev-tools.md · docs/flash-digest.md · .claude/agents/thumb-batch.md · docs/briefs/m16/process2/p2-docs-report.md
check: format
report: docs/briefs/m16/process2/p2-docs-report.md
