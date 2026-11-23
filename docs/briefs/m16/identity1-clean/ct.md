job: M16 identity1-clean ct: claude-worker-test pins a brief's turns line; selftest unsets FLASH_WORKER
pub: no
turns: 35
expected-min: 45
tests-first: exempt (a new case for code that already exists, flash.sh 0d0f2953; the case must pass now and fail if the turns line is removed)
stop: after it. No change to tools/flash.sh or claude-worker.sh.
read: docs/briefs/templates/COMMON.md · docs/flash-lessons.md rules 20, 23 · tools/tests/claude-worker-test.sh:60-95 (run_worker, the web-brief case at 82-88 is the pattern for a brief file with --dry-run; `has`, `report`) · tools/flash.sh:240-246 (the `turns:` line raises maxturns, only above the default 35) · tools/selftest.sh:25-30 (the unset list)
changes: FLASH_WORKER
do:
1 In claude-worker-test.sh, after the web-brief case, add one case in the same style: a brief file in "$tmp" with the lines `job: turns case`, `turns: 50`, `report: docs/turns-case.md`, run `bash "$worker" --brief "$tmp/turns-brief.md" --dry-run` with PATH="$stub_path:$PATH" as the web case does, and assert exit 0 and `has "max-turns: 50"`. Name: "a brief's turns line raises the claude worker's --max-turns (50)".
2 Add a second case: a brief with `turns: 20` still gives `max-turns: 35` (the line only raises).
3 In selftest.sh line 29 add `FLASH_WORKER` to the `unset` list (same line, after RUN_CHECK_SKIP); keep the comment accurate.
4 Run exactly this bare command line: `bash tools/tests/claude-worker-test.sh`. Report the PASS count.
allow: tools/tests/claude-worker-test.sh · tools/selftest.sh · docs/briefs/m16/identity1-clean/ct-report.md
check: format
report: docs/briefs/m16/identity1-clean/ct-report.md
