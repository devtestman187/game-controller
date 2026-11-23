# process5 review verdicts (driver, Nov 22)

Wave reviews: wave1-review-report.md (p5b, 7 findings), wave1-p5a-review-report.md (p5a, 9 findings). The run-level REVIEW.md was not produced by the runner (it stopped with p5c parked); p5c has no worker report (parked at its limit in its closing phase; applied by hand, test 6/6, review.sh 0 fail).

p5b: should 1 (tests-first FAIL lines not shown): minor, the suite-level FAIL stands; code-health. should 2 (a `worker:` line in run.log relabels every row, p5c now logs one per run): minor, code-health (scope by timestamp). could: terminal_reason case, --help fixed range, unchecked nousage line, false 120-column claim: code-health. LC_ALL=C on the minutes awk: FIXED (job-metrics.sh:97).
p5a: should (report's check PASS not tied to the committed files): minor, the final `tools/check.sh tools` of this batch covers the tip. could: unasserted report values, denial and exit-2 cases of the stand-in, args-file case numbering, fallback cap duplicate, -h range: code-health. FIXED: octal cap (`10#$cap`), plain-flash case without FLASH_MODEL/FLASH_MAX_TURNS.
Decisions: the METRICS dash for a missing result is kept; the JSON log is often present (flash.sh leaves it at $log), so subtype shows in the result column; metrics are appended only at DONE. The stand-in's denial answers exit 0 on purpose (only flash.sh's preflight grep catches it); auth keeps subtype error_during_execution.
Not checked by anything yet: that --safe-mode really loads no CLAUDE.md, hooks or MCP servers (the real preflight is the only evidence).
Hand-fix of p5c beyond the apply: runner size gate (run-jobs.sh was 391 lines, limit 380): comments shortened to 380; --help range follows the header.
