job: M16 process2 wire — the runner writes STOP.md, auto-applies churn, has a lock and a time limit
pub: no
stop: after it. run-jobs.sh stays under 340 lines; new logic goes into the sourced files or tools/run-stop.sh.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process2/script-rules.md · tools/run-jobs.sh · tools/run-steps.sh · tools/run-review.sh · tools/run-stop.sh (header) · tools/churn.sh · tools/tests/run-jobs-split-test.sh · docs/briefs/m16/*/run.log (grep -h "STOPPED" for the causes seen)
decisions (owner, Nov 21): "the runner writes STOP.md on any stop (cause, failing tests, last log lines, suggested repair); auto-apply known generated churn instead of stopping"; "if a run is taking an abnormally long time, report or exit so an agent can investigate".
tests-first: exempt shell tooling; tests extend tools/tests/run-jobs-split-test.sh and a new tools/tests/run-wire-test.sh (stub tools/flash.sh, check.sh, run-stop.sh via a temp repo).

do:
1 stop(), check_stop and the brief-lint exit call `bash tools/run-stop.sh "$B" "$WORK" "<cause>" [flash log]` first and add $B/STOP.md to the paths save() commits; the next start removes STOP.md. A failing run-stop.sh never changes the runner's exit.
2 Churn: build CHURN_OUTSIDE and the unchurn paths from tools/churn.sh (one source). From the causes in the old run.logs, add the generated paths that caused result-4 stops (for example s7-results.json) to churn.sh; a result-4 job whose only outside files are churn is applied, never a stop (log it).
3 Lock: a lock file in $WORK holding the pid; a second runner on the same batch exits 2 with `RESULT: refused, a run is active (pid N)`; a stale lock is replaced; trap removes it. Time limit: RUN_MAX_MIN (default 360): past it, STOPPED: TIMEOUT via stop (STOP.md class timeout). Runner exit codes stay 0/1/2 as documented.
4 tools/tests/run-wire-test.sh: STOP.md written on a check failure stop, on the stop file and on lint; churn-only result 4 applied; lock refused; stale lock replaced; RUN_MAX_MIN=0 times out; and the dry run unchanged.
5 Header comment and docs/dev-tools.md: one sentence each.
allow: tools/run-jobs.sh · tools/run-steps.sh · tools/run-review.sh · tools/churn.sh · tools/tests/run-wire-test.sh · tools/tests/run-jobs-split-test.sh · docs/dev-tools.md · docs/briefs/m16/process2/p2-wire-report.md
check: format
report: docs/briefs/m16/process2/p2-wire-report.md
