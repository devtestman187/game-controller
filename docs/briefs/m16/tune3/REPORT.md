# Report: m16 tune3 (inline batch, no runner; tools and test guards only)
Range 47ce2222..1783beb2. Nothing pushed, tagged or built. Sources: docs/briefs/m16/wave2-789 (run.log, REPORT.md, REVIEW-VERDICTS.md). Order kept as Fable reviewed it. (Saved by main from the driver's hand-back; the driver's Write was refused.)

## Commits and jobs
| job | commit | what | reproduced first? |
|---|---|---|---|
| 1 | d048fa68 | tools/tests/run-stops-test.sh: rc-4 churn over/under cap, over-cap verify, parked diff, pause restart, resumed-turns WARN, two waiter cases | red on base: 3 cases (rc-4 plus cap, unverified over-cap accept, parked diff in combined check) |
| 2 | 8ec8db02 | 3 tv_test_app generated plugin files untracked and gitignored; four PNG-writing test helpers write only with UPDATE_GOLDENS; churn_snapshot in churn.sh used by mine.sh and the runner's unchurn | mine-test case: pre-dirty churn kept |
| 3 | 1b7dde6c | run-wave.sh finished_job handles rc-4 churn (apply_safe) before turn_cap; an over-cap job with result 0 and a report goes through cap_verify (brief's check plus its new tests) before the WARN accept; failure parks | run-stops cases 1, 3 |
| 4 | 1b7dde6c | park_tree saves a parked job's allow files and report as parked-JOB.patch and removes them from the tree | run-stops case 4 |
| 5 | bbd15b6d | check-par.sh HEARTBEAT every CHECK_HEARTBEAT_S (default 300 s); run-tune2/run-wire/run-wire2 tests unset RUN_*; wire2 STOP review stub sleeps 20 s | check-par-test 10-11 |
| 6 | e80aaa55 | tools/batch-report.sh, tools/batch-close.sh, batch-tools-test (5 cases); usage_wall WARN for "1 turns, 0 min" rows of 5+ min jobs | run-stops 5b |
| 7 | none | pause restart and stale waiter did not reproduce | - |
| 8 | 8b96f193, 0280d351 | thumb-batch.md: countable hand-back (2 waves or 3 restarts, or ~100K), "delegate every log read", names batch-report/batch-close; sync-agents ran (7 copies, --check clean); brief-check changes: ignores comment-only mentions; template and driver-kit: Sonnet new-test jobs turns: 80 | brief-check-test 5b |
Close-out commit 1783beb2: run.log full check line (by batch-close.sh), tune3 STATUS.md line, DRIVER-NOTES. No worker jobs, no hand-fix events.

## Decisions taken (flag if wrong)
- PNGs under docs/design and site/shots stay tracked (site/index.html serves site/shots; docs/design are references). Their tests write only with UPDATE_GOLDENS=1 and keep render and size assertions. Refresh: `UPDATE_GOLDENS=1 flutter test <file>`.
- Generated tv_test_app/windows/flutter/generated_* untracked (git rm --cached) and ignored; flutter pub get regenerates them; nothing in check.sh, release.sh, site or CI reads them from git.
- churn_revert/unchurn never revert a churn path already dirty at the snapshot.
- cap_verify runs the brief's check: line on the combined tree plus the job's allowed *_test.dart files; a sibling's break could park an over-cap job (accepted).
- Parked-diff removal covers allow: paths and the report only.

## Not reproduced
- Pause restart: run-stops case 5 passes on base; the three wave2-789 repeats coincide with hand-fixed jobs (handfix_recheck path) and pending reviews, not modelled.
- 58-minute stale waiter: wait-run.sh already ignores STOPPED lines before the last start-at line; no code appends RESULT to run.log; cause not found, needs the waiter transcript.
- run-wire2 STOP flake: passed under -j 4 twice and 4 times alone; hardened anyway. Side finding: inside a background `( ... ) &` its INT case always fails (background shells ignore SIGINT); check.sh does not do that.
- "Restart after a hand-commit stops once" not looked at.
- Stop count: wave2-789 run.log has 11 STOPPED lines (3 are pauses) and 12 restarts, not 14 (`bash tools/batch-report.sh docs/briefs/m16/wave2-789 --out -`).
- Result 4 on 29 of 30 wave2-789 jobs was the generated plugin files and PNG churn.

## Checks
`tools/check.sh -j 4 tools` PASS (307 s) on the tip. A full `check.sh -j 4` passed all other suites; its tools suite hit the selftest lock held by an earlier full run, so tools ran alone. Sharp edge: a failed check.sh run does not kill its other suites, so an immediate second run clashes on the selftest lock.

## Metrics
agent-cost since 04:20 Nov 25: total $6.80 (sonnet $4.21, opus $2.07, fable $0.48, haiku $0.02; includes the session's other agents). Driver ~110 calls, ~1 h 15 min.

## Fixed, unverified
Over-cap, churn-first and parked-diff paths are proven on stub fixtures only; the first real wave that parks a job will show real behaviour. The saved patch lands as parked-JOB.patch.
