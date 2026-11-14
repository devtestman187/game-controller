job: M14 bugs3 pr-party: report-only proposals for owner change requests (NO code changes)
pub: no
stop: after it.
read: docs/design/party-night.md · docs/PRD-v2.md section "Milestone 14" · the code the items name (read only what you need)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

This is a PROPOSAL job: change no file except your report. For each item below write a concise proposal: what changes (player-visible), why, options if there is a real choice (with your pick), files touched, tests, risk. Keep each proposal under 25 lines and make it text the owner can approve as written. Put each proposal under its own heading "### B-0xx". If an item conflicts with the design documents, say so and say how.

B-002 (owner: "Party Mode rounds: If only single player, no need to show the join screen between rounds.") Find where the join/lobby screen between Party Mode rounds is shown and propose skipping it when exactly one player is joined (and what happens if a new phone joins late, how a player can still add friends).

in the report: start with `## Summary` (at most 30 lines): one line per item (the pick and the risk). Then the proposals.
rules: report only; write only the report file · no code, no scratch files
allow: docs/briefs/m14/bugs3/pr-party-report.md
check: format
report: docs/briefs/m14/bugs3/pr-party-report.md
