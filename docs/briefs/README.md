# Flash-worker briefs

Every job Claude sends to the flash-worker, kept as written: one file per job, `mN/s<step>-g<gate>.md`, plus the worker's plan when a G1 plan was approved (`-plan.md`), its survey (`-g0-survey.md`), and the review job for a gate (`-review.md`, findings in `-review-report.md`). The brief is the spec ([project-notes.md](../project-notes.md#how-we-work)); Claude's decisions on the worker's questions are written into the next brief.

Templates in [templates/](templates): [job.md](templates/job.md) for a gated job, [survey.md](templates/survey.md) for the read-only fact-finding before a contract (G0), [review.md](templates/review.md) for the read-only review before Claude's. Run one with `tools/flash.sh --brief <file>`: its `allow:`, `check:`, `report:` and `pub:` lines are the options, and the job runs in a worktree of its own.
