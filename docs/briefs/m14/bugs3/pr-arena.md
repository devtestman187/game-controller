job: M14 bugs3 pr-arena: report-only proposals for owner change requests (NO code changes)
pub: no
stop: after it.
read: docs/design/party-night.md · docs/PRD-v2.md section "Milestone 14" · the code the items name (read only what you need)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

This is a PROPOSAL job: change no file except your report. For each item below write a concise proposal: what changes (player-visible), why, options if there is a real choice (with your pick), files touched, tests, risk. Keep each proposal under 25 lines and make it text the owner can approve as written. Put each proposal under its own heading "### B-0xx". If an item conflicts with the design documents, say so and say how.

B-005 (owner: "My player cannot pickup his own coin after it drops. This should be allowed." Bumper Round). Find the rule (a pickup lockout for the dropper?) and propose allowing the owner to pick it up again, with or without a short delay, keeping the scatter fair.
B-006 (owner: "Cat is not very frequent even in Party mode. It also needs to be more aggressive. Have settings for tuning and testing." area Bumper Round; check which cat this is). Propose how often and how aggressive, and a tuning surface (e.g. a hidden developer setting with named presets and a debug override).
B-015 (owner: "Arena mode: race needs more maps. Can we reuse bumper maps for this?"). Judge whether the Bumper maps can serve the Race mode (spawns, finish line, checkpoints) and propose which maps and what each needs.

in the report: start with `## Summary` (at most 30 lines): one line per item (the pick and the risk). Then the proposals.
rules: report only; write only the report file · no code, no scratch files
allow: docs/briefs/m14/bugs3/pr-arena-report.md
check: format
report: docs/briefs/m14/bugs3/pr-arena-report.md
