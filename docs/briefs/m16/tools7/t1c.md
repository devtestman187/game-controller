job: M16 tools7 t1c: load-tolerant, faster run-limits-wire, run-wave and mine tests
pub: no
turns: 35
expected-min: 45
tests-first: exempt (refactor of shell tests: each case keeps its name and assertion; report each script's seconds before and after)
stop: after it. Do not use or create a shared helper (t1a owns tools/tests/run-wire-lib.sh); keep every helper inside its own script. Touch no other file.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/tools7/context.md (goal and rules) · tools/tests/run-limits-wire-test.sh (167 lines: stubs 45-105, fixture 81-104, cases 118-167; run-gate-test's leak case reads its top `unset` block: keep it) · tools/tests/run-wave-test.sh (189 lines: sleep stub 44-51, fixture 92-115, cases 130-189) · tools/tests/mine-test.sh (233 lines: base repo 79-90, stub hang 43, timeout case 213) · docs/flash-lessons.md rules 19-21
changes: build_template · template_repo
decisions (owner, Nov 22): same as context.md; no assertion weakened.
do:
1 Time each script first (`date +%s` around `bash tools/tests/<name>`), keep the numbers for the report.
2 In run-limits-wire and run-wave: build the fixture repo once into a template folder, copy it per case with `cp -r`. In mine-test: its base repo is already built once; make the per-case copy and the stub calls cheaper only where measurement shows a cost; do not change the stub tools' behaviour.
3 Replace fixed sleeps that wait for a file or log line with a poll (0.1 s steps, generous cap, fail the case on the cap). Where a stub sleeps to simulate a hung or long job past a 1 s limit, keep the runner's kill logic exercised but sleep no longer than needed; keep the guard timeouts as before.
4 Run each of the three scripts again, then run-gate-test.sh (leak case) and run-limits-test.sh; all pass; run each of the three twice to show no flake. Report seconds before and after.
allow: tools/tests/run-limits-wire-test.sh · tools/tests/run-wave-test.sh · tools/tests/mine-test.sh · docs/briefs/m16/tools7/t1c-report.md
check: format
report: docs/briefs/m16/tools7/t1c-report.md
