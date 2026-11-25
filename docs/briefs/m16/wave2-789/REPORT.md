# wave2-789 report (PARTIAL: batch stopped at the driver's context limit; resume from DRIVER-NOTES.md "Next action")

Base 70bcd97a. Jobs: JOBS.md. Waves 1-2 done (6 jobs), waves 3-7 not started. No full check yet, no STATUS block yet.

| Job | Model | Ladder level reached | Turns | Failure class | Hand-fix |
|---|---|---|---|---|---|
| n8a | haiku | 1 | 16 | none | no |
| n9b1 | sonnet | 1 (+ apply) | 65 (cap 60) | capability | yes (apply-job, 0 lines changed) |
| n9e | haiku | 1 | 18 | brief (premise wrong: Resume already `good`; no change) | no |
| n8b0 | haiku | 1 | 21 | none | no |
| n9sr | haiku | 1 | 58 | none | no |
| n8c | sonnet | 1 (+ apply) | 66 (cap 50) | capability | yes (apply-job, 0 lines changed) |

Stops so far: 2 (n9b1 over cap, n8c over cap). Hand fixes: 2 (both apply-job of a finished-but-over-cap job; 0 lines edited) plus 3 trivial review fixes by hand (dartdoc, rename).
Sonnet share: 2 of 6 (33%). Justification: n9b1 is a new widget measuring test at four sizes and two looks; n8c is a new widget test file plus layout at narrow sizes (both fit the tag rule); both went over their caps, so the next Sonnet new-test jobs should carry turns 70.
Tooling notes: pause flow worked (wave review committed, restart skips done jobs and re-runs tests-first and review for a hand-committed job); a STOPPED line from an earlier stop stays above the restart line, so waiters must compare timestamps; tracked tv_test_app generated files show as "outside allow" on every job (noise); debug-leftovers gate and `model:` field worked (no false alarm; brief-check FAILed `changes:` names that hit many files, narrowed by hand).
Findings: wave1 review (n8a, n9e): 1 must invalid, 3 trivial fixed, 2 minor to code-health. wave1-n9b1 review: 9 findings (1 must), verdicts pending. Wave 2 review pending.
Owner question (non-blocking): the phone's Resume is the Start pill in the player colour; plan default `good` will be applied in n9e2 unless the owner says otherwise.
Not done: n8b1, n8b2, n8b3, n8d1, n8d2, n8e sweeps, TV-word guard test, n9b2, n9b3, n9e2, fix jobs, full check, tracker/STATUS.
Calls: driver about 50, waiters 4 (6, 1, 6, 5 calls).
