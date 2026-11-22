job: M16 process4 p4f: replay fixtures of identity1 waves 1 and 2, and the test that brief-check flags every recorded miss
pub: no
stop: after it. Fixtures and one test; no tool is changed (a bug in brief-check goes in the report).
tests-first: exempt (fixtures and a replay test of a finished tool; say so in the report).
expected-min: 30
turns: 120
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process4/PLAN.md (goal 6) · docs/briefs/m16/process4/replay/ (briefs from git history with changes: and probe: lines added, BASES.txt, expected.txt, probe-i1a.patch) · tools/brief-check.sh (p4a: usage, env BRIEF_CHECK_REF, output lines) · tools/probe-deps.sh (p4b: PROBE_BASE) · tools/tests/brief-check-test.sh (test layout)
decisions (owner, Nov 22): the replay proves the new tools would have caught identity1's misses. brief-check runs on the real history with BRIEF_CHECK_REF (no checkout); probe-deps on an old commit is slow, so the test runs it only when REPLAY_PROBE=1.
do:
1 Copy docs/briefs/m16/process4/replay/{wave1,wave1-split,wave2} to tools/tests/fixtures/replay/ (briefs, waves.txt, probe patch) and BASES.txt beside them.
2 NEW tools/tests/replay-identity1-test.sh: for each brief-check line of expected.txt run `BRIEF_CHECK_REF=<base> bash tools/brief-check.sh <fixture>` once per batch and assert a FAIL line names the file (one PASS or FAIL line per recorded miss, with the miss text). If a base sha is not in this clone, print PASS skip lines naming the reason. With REPLAY_PROBE=1 also run probe-deps on wave1 and wave1-split (PROBE_BASE=<base>) and assert the probe-deps lines of expected.txt (the layers and apply-job lines are rehearsal items: say so in a comment). Without REPLAY_PROBE, under 10 s.
allow: tools/tests/replay-identity1-test.sh · tools/tests/fixtures/replay/ · docs/briefs/m16/process4/p4f-report.md
check: tools
report: docs/briefs/m16/process4/p4f-report.md
rules: aim 50-70 turns · write only inside allow: · tools/review.sh: no FAIL on your lines.
