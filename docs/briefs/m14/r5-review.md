job: M14 r5: the full review of M14 (the worker's pass first; Claude verifies)
pub: no
stop: after it.
read: docs/review-rules.md (all parts) · docs/design/party-night.md · docs/PRD-v2.md Milestone 14 and its acceptance tests · every docs/briefs/m14/*-report.md and its "Decisions" · the diff `git diff refs/heads/m13...HEAD` · docs/coding-guidelines.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Review all of M14 against docs/review-rules.md: correctness bugs first, then the PRD's acceptance tests (which pass, which can only be checked on a device), the comfort rules (G5) on every new effect, protocol compatibility with older builds, sizes, and every worker "Decision" that looks wrong or risky. Change no code: findings only, each with file:line, what goes wrong and a suggested fix, ranked most severe first, plus a device-test list for the owner.

in the report: findings (ranked), the acceptance-tests table, decisions to revisit, the device-test list.
rules: change no file but the report · install nothing
allow: docs/briefs/m14/r5-review-report.md
check: format analyze
report: docs/briefs/m14/r5-review-report.md
