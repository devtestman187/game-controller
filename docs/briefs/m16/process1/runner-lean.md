job: M16 process1 runner-lean — tools/run-jobs.sh skips a redundant wave review and lints brief report: lines
pub: no
stop: after it. No other runner behaviour changes.
read: docs/briefs/templates/COMMON.md · tools/run-jobs.sh (the header comment :1-58; wave_review :234; the wave loop :370-425; the final review :430; the dry-run block :132-140) · docs/dev-tools.md:398 (the runner's description) · docs/flash-digest.md (Brief and Run sections)
decisions (owner, Nov 21): "skip the per-wave review when that wave is the whole run (the run review covers it); preflight lint that every brief's `report:` line is exactly one bare path (stop before wave 1 with a clear message otherwise)".
tests-first: exempt a shell tool with no test harness; verify with --dry-run on a temp folder and `bash -n`.

do:
1 Wave review skip: in wave_review, when the plan has exactly one wave (${#WAVES[@]} -eq 1) and review is on, set WREV to empty and log once `wave review skipped: wave 1 is the whole run, the run review covers it`. Also leave it on for runs with 2+ waves. Apply the same in the hand-fixed branch (~:378).
2 Lint: before the first wave (after the dry-run block and before the flash preflight), loop over every job named in waves.txt that is not done or dropped; for each brief `$B/<job>.md` read its `report:` line(s). A brief with no `report:` line, two of them, or one whose value after `report:` is not a single token (no spaces, nothing after the path, no backticks or quotes) is a finding. If any: note `STOPPED: brief lint: <job>: report: line must be exactly one bare path (got: <text>)` for each, then exit 1 without starting any job (use the existing stop/save pattern; nothing running yet). Run the lint in --dry-run too and print `LINT FAIL <job>: ...` lines there (exit 0).
3 Update the header comment (lines 4-58) and docs/dev-tools.md:398 with one sentence each for the two changes; keep the header block within its `sed -n '2,58p'` help range (extend that range if the header grows).
4 Verify by hand on a scratch copy of a batch folder (a good brief, a bad `report: a.md b.md` brief, a one-wave waves.txt); report the command lines and outputs. Do not run real jobs.
5 Keep `bash -n tools/run-jobs.sh` clean and the file under 520 lines; keep functions short.
UI: not affected.
allow: tools/run-jobs.sh · docs/dev-tools.md · docs/briefs/m16/process1/runner-lean-report.md
check: format
report: docs/briefs/m16/process1/runner-lean-report.md
