job: M16 tools7 t1b: load-tolerant, faster run-gate, wait-run, run-worker-switch and process3-fix1 tests
pub: no
turns: 35
expected-min: 45
tests-first: exempt (refactor of shell tests: each case keeps its name and assertion; report each script's seconds before and after)
stop: after it. Do not use or create a shared helper (t1a owns tools/tests/run-wire-lib.sh); keep every fixture helper inside its own script. Touch no other file.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/tools7/context.md (goal and rules) · tools/tests/run-gate-test.sh (252 lines: stubs 45-93, fixture 93-120, cases 140-252; keep the leak case 218-250 working) · tools/tests/wait-run-test.sh (288 lines: sleeps at 228 and 270, the timeout 3 case at 227) · tools/tests/run-worker-switch-test.sh (181 lines: fixture 63-112) · tools/tests/process3-fix1-test.sh (207 lines: stubs 50-135, wave-limit case 144-160) · docs/flash-lessons.md rules 19-21
changes: build_template · template_repo
decisions (owner, Nov 22): same as context.md; no assertion weakened.
do:
1 Baselines (seconds, measured under load Nov 23, put them in the report): run-gate 56 · wait-run 57 · run-worker-switch 59 · process3-fix1 42. Run a script ONLY as the bare command `bash tools/tests/run-gate-test.sh` (exact file name incl. `-test`; no `time`, `date`, `cd`, pipes or redirects: those are refused by the allow-list and cost the earlier attempt every run). The script prints PASS/FAIL lines only; judge speed by the sleeps and process starts you removed; the driver times the final runs.
2 In each of the four scripts, build the fixture repo (git init, config, base commit) once into a template folder and copy it per case with `cp -r`; per-case work is only the case's own briefs and knobs.
3 Replace fixed sleeps that wait for a file or log line with a poll (0.1 s steps, generous cap, fail the case on the cap). Where a stub sleeps to simulate a long job, shorten it only to the smallest value that still passes the case's own limit logic; keep the guard timeouts as long as before.
4 Run each of the four scripts (bare commands, see 1), then selftest-limits-test.sh and run-jobs-split-test.sh; all pass; run each of the four twice to show no flake. The earlier t1b attempt (report t1b-report.md of the first run) was deleted; ignore it.
allow: tools/tests/run-gate-test.sh · tools/tests/wait-run-test.sh · tools/tests/run-worker-switch-test.sh · tools/tests/process3-fix1-test.sh · docs/briefs/m16/tools7/t1b-report.md
check: format
report: docs/briefs/m16/tools7/t1b-report.md
