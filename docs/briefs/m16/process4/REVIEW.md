# process4 review verdicts (driver, Nov 22)

Waves 1 and 2 worker reviews (wave1-review-report.md, wave2-review-report.md) checked at their file:line.
- must: p4a fixtures did not analyze. Real, fixed (comments, commit 8ebcdff6) before the review ran.
- should: p4e report/brief mismatch with the wire-test edit. Real, minor: HAND-FIX lines in run.log name the file; report left as is.
- should: flash-digest limits line and Repair a stop are stale (run-wave parks; apply-job). Real; fixed in HANDEDITS item 4 after the batch.
- should: gate seam untested. Real; p4g's run-gate-test covers it (8 cases pass).
- should: brief-check done/dropped skip has no case; apply-job folder/rename cases. Deferred to docs/code-health.md.
- could: run-limits.sh comment and run-base-test RUN_BASE_CHECK_SKIP unset: trivial, fixed by hand. Rest deferred to code-health.
- Decisions to confirm (apply-job no-op exit 1, dry dirty check, cd to root; park of result-4 churn jobs; run-stop classification): left for the owner, no change.
