# costtool report (Nov 27, tooling only, inline, no runner)
Owner decision "A": all five cost changes. Commit d5c23471 (base f38c6efb).
1. tools/verify-batch.sh: new `musts` check. A REVIEW.md line starting `must` (`- **must** ...`, `3. must: ...`) without fixed/closed/answered on it FAILs with the count and line numbers; no REVIEW.md is a SKIP. Self-test tools/tests/verify-batch-test.sh: 17 PASS, 0 FAIL (skip, 2 open, closed cases added). Note: older REVIEW.md files that list musts without a closing word would now FAIL if re-verified.
2. thumb-batch.md and docs/driver-kit.md section 14: no up-front reads; first call is one thumb-haiku context pack (at most 40 lines).
3. Hand-fix: one call (apply-job patch); bigger work becomes a worker job (thumb-batch step 4, kit section 14).
4. thumb-wait.md: returns `tail -20` of run.log only.
5. tools/sync-agents.sh ran after the agent edits: copied thumb-batch, thumb-haiku, thumb-release, thumb-triage, thumb-verify, thumb-wait, fable-review; `--check` rc 0.
Check: bash tools/check.sh All checks passed (865s, 0 cached).
Proposed lessons: 0. Open: none.
