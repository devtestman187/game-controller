job: M16 process3 p3e: stand-in worker tools/fake-flash.sh for an end-to-end rehearsal
pub: no
stop: after it. A new script and its test only.
tests-first: exempt (new shell tool: its test runs first against no script and must FAIL; say so in the report).
expected-min: 20
read: docs/briefs/templates/COMMON.md · tools/run-jobs.sh lines 255-300 (how a job is started: `tools/flash.sh --brief <brief>`, log, exit code, report file, usage) · tools/commit-job.sh (what a job's commit needs) · docs/briefs/templates/job.md · tools/tests/run-stop-test.sh (fixture style)
decisions (owner, Nov 22): "the runner can run a dummy batch with a stand-in for flash that sleeps briefly and writes a fake result, for an end-to-end rehearsal". The runner side (FLASH_CMD) is p3d's.
do:
1 NEW tools/fake-flash.sh, same call as flash.sh (`--brief <brief>`, also `--preflight`, exit 0). It reads the brief's `report:` and first `allow:` path, sleeps FAKE_FLASH_SLEEP_S (default 2), writes the report with a `## Summary` and `## Hand-over` block, appends one line to the file FAKE_FLASH_NOTE_FILE (the allow: path's folder gets nothing else), writes one usage row (turns FAKE_FLASH_TURNS, default 10) to FLASH_USAGE_LOG, and exits FAKE_FLASH_RC (default 0). With FAKE_FLASH_HANG=1 it sleeps 1 hour (to test the limits). Nothing outside the brief's own paths.
2 NEW tools/tests/fake-flash-test.sh: each mode in a temp folder, sleeps of 1 s, under 15 s total.
allow: tools/fake-flash.sh · tools/tests/fake-flash-test.sh · docs/briefs/m16/process3/p3e-report.md
check: tools
report: docs/briefs/m16/process3/p3e-report.md
rules: aim 35-50 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
