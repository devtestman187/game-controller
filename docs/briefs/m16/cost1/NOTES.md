# cost1: reducing Sonnet usage (owner yes, Nov 23)

Done by the main session by hand (small tools and docs; a Sonnet driver reading the docs would have cost more than writing them).

- a. `tools/agent-cost.sh` (+ `tools/agent_cost.py`, `tools/tests/agent-cost-test.sh`, 12 cases): per-model tokens and API-price estimate from the transcripts, dedup by message id + requestId, 5m/1h cache-write split, Sonnet resumes over 5/60 min. First real run, Nov 23 (whole day): opus main $22.73, sonnet sub $22.79 (4.37M cache written, all 5m), haiku $0.69; total $46.21; 29 Sonnet resumes over 5 min wrote 3.15M. 36 Haiku calls had a prompt over 100K (5x price).
- b. `docs/driver-kit.md` (about 3.5K tokens): brief format, runner start and env vars, limits, waiting, ladder, repair, DRIVER-NOTES format with a "Next action" block, wrap, tracker, standing rules, report. thumb-batch reads it instead of the digest, flash-lessons, framework and dev-tools.
- c. thumb-release on Haiku with a 7-step checklist (lib review by `git diff --stat <base>..HEAD -- packages controller_app/lib tv_test_app/lib` keeping `/lib/` paths and stating the count; uncached check; release.sh; build watch). `tools/sync-agents.sh` (+ test) written (it was planned in claude-only-model.md, never built) and run: all five thumb-* agents copied to ~/.claude/agents. Changed agents load at session start.
- d. Measured first on bug wave A (see below).
