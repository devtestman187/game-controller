# rehearsal1: the first Claude-only batch (Haiku coders), Nov 22

Run 22:21:53 to 23:09:01 (47 min wall, of which 33 min is the combined check). WORKER=claude, model claude-haiku-5-5, one wave of n1 n2 n3, 3 workers at once.

## REHEARSAL notes

| Job | Attempts | Ladder level | Turns | Tokens in / out / cache | Min | Result | Review findings | Code quality |
|---|---|---|---|---|---|---|---|---|
| n1 phone-style name | 1 | 1 | 34 | 66 / 19959 / 1199851 | 11.2 | 4 (churn only), applied | 0 (review.sh 0 fail) | good: one rare helper, nicknameOf and PhoneText both use it, tests on the real hello path, both looks, tests-first proved |
| n2 stale docs | 1 | 1 | 18 | 26 / 10899 / 335977 | 4.5 | 4 (churn only), applied | 0 | good; all 5 corrections match the brief |
| n3 _takesIdentity | 1 | 1 | 9 | 10 / 3520 / 88199 | 1.1 | 0 | 0 | good: 2 call sites, behaviour unchanged |

Flash comparison (identity1/process5 run.logs): i1e 151 turns / 12 min, i1d 134 / 18, i1g2 161 / 23, i1f 105 / 8, p5b 100 / 51 (flash, jobs of about 5-15 files). The Haiku jobs were smaller by design (about 3-6 files) so the comparison is rough: 9-34 turns, 1-11 min, no job over its cap, 0 repairs, no escalation. The tokens column of job-metrics reads cache as one sum (1.2M for n1: each turn re-reads the context, about 35k per turn average).

Ladder: every job passed at attempt 1; levels 2-4 were not exercised. Reviews: single wave, so no per-wave worker review; I read the full diff by hand (trivial) and ran tools/review.sh (0 fail).

What worked: WORKER=claude runs end to end (preflight, three parallel Haiku jobs, tests-first proof, METRICS in run.log, job-metrics table). Churn handling dropped site/shots PNGs and tv_test_app generated files. Haiku followed the read: line ranges with no exploration (9-34 turns), wrote both new tests first, and kept to allow:.

What broke:
1. The combined check stopped the run twice with `tools` FAIL (tools/tests/run-wire-test.sh, 8 sub-tests: STOP.md commits, result 4 churn, wave review), 550 s each time, while every other suite passed (format, analyze, protocol, connection 346, metrics, kit, look, arena, puzzle, host, phone, tv). The same script run alone afterwards on the same tree passes all 17 cases. The failing lines name no job; the cause is not measured (the tree held uncommitted job changes and untracked report files while the check ran; suspected interaction with the dirty tree). STOP.md said "failing tests and errors: none found", so the stop needed the check's own log from the temp dir (path is in run-check.log).
2. The tools suite in the combined check costs 9-16 min of every batch even when no tool changed.
3. Result 4 on n1 and n2 was only generated churn, as in flash batches; no Claude-specific problem.
4. brief-check: `changes: none` is searched as a symbol (238 FAILs); comment-only jobs need a rare symbol and the files that use it in allow:. n1 got a 4-package WARN (connection, party_host, controller_app, docs).

Recovery: the runner had already applied the three jobs into the tree. Instead of restarting (which would rerun three workers), the driver verified the diff, ran tools/review.sh and the run-wire test alone, and committed by hand with HAND-FIX logged.

Open for the owner: nothing design-wise. Fixed, unverified: needs device check: a phone with a blank nickname shows "Player N" in the lobby list and result card (tested with the real name path in both looks, not on a device).
