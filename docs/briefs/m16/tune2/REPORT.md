# tune2 report (inline, tooling only)

Base 89f1a212. Commits: tooling commit and the report/STATUS commit on m16 (tip in the hand-back). No runner, no workers: 0 jobs, so no turns/ladder/Sonnet share to report; model, ladder and tokens now appear in run.log from the next run.

## Done (owner: "Yes. Fix those 3." plus tiering, Fable-reviewed)
1a tools/debug-leftovers.sh (BISECT, `// debug|temp|hack|bisect` markers, print/debugPrint in test files, new untracked Dart files too); runner calls `leftovers` after tests-first (tools/run-wave.sh), stops the wave.
1b driver-kit rule + template line (`tests-first: exempt` up front); no mechanical check (not reliable).
1c tools/brief-check-rules.sh: a shrinking do: line without a 48 dp touch-target test (or `touch-target: exempt <reason>`) FAILs.
2 analyze on own changed files: template do: line 4, COMMON.md, worker prompt in flash.sh. check.sh infos still fatal.
3 `RUN_PAUSE_AFTER_WAVE=1` pauses after each non-last wave (STOPPED: PAUSED, review committed); driver-kit 6b flow, REVIEW-VERDICTS.md, run-review template skips verdicted items. Fix jobs scoped by brief-check.
4 `model:` brief field (tools/flash-model.sh, haiku/sonnet to exact ids, default CLAUDE_WORKER_MODEL/haiku); brief-check FAILs unknown model and sonnet without turns:; run.log `finished` line carries model, ladder, tokens (job_line); agent_cost.py already priced by family, test added for a Sonnet worker log. Tag rule, per-tier ladder, analyze before hand-commit in driver-kit 6.
Coordinator addition: failure class per failed job (driver-kit 6) and `HAND-FIX-EVENT <job>: <n> lines changed, replaced ladder level <l>` written by apply-job.sh.
Agent def thumb-batch.md updated and synced (tools/sync-agents.sh).

## Tests
New: debug-leftovers-test, brief-check-rules-test, flash-model-test, run-tune2-test; extended agent-cost-test (sonnet headless), apply-job-test (event line).
Sizes: run-jobs.sh 380, run-steps.sh 249 (helpers live in run-wave.sh), brief-check.sh 300.
full check: All checks passed (297s, 10 cached).

## Notes
- Not done by design: no runner end-to-end run of the pause (unit-tested with stubs); wave review of the pause flow comes with the next real batch.
- Fixed, unverified: none. Findings: none (inline, no review). Proposed lessons: 0. Tracker: none.
- A mid-task `pkill` of check.sh was refused by the permission system; not retried.
