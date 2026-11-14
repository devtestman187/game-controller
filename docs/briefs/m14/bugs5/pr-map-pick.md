job: M14 bugs5 pr-map-pick: report-only proposals for owner change requests (NO code changes)
pub: no
stop: after it.
read: docs/design/party-night.md · docs/PRD-v2.md section "Milestone 14" · the code the items name (read only what you need)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

This is a PROPOSAL job: change no file except your report. Write one concise proposal (under 30 lines) under "### B-011": what changes (player-visible), why, options with your pick, files touched, tests, risk, in text the owner can approve as written.

B-011 (owner idea, Shape Race; the owner then wrote "Provide proposal"): "Shape race: need a way to pick a random map or next map after picking a specific stage." Find how the Shape Race (puzzle game) chooses its puzzle/stage today (the picker screen, "Next puzzle", rematch, the Auto choice) and propose a Random choice and a Next choice in the picker and after a round, working with the no-repeat idea in docs/briefs/m14/bugs3/pr-shape-report.md (B-009).

in the report: start with `## Summary` (at most 30 lines): one line per item (the pick and the risk). Then the proposals.
rules: report only; write only the report file · no code, no scratch files
allow: docs/briefs/m14/bugs5/pr-map-pick-report.md
check: format
report: docs/briefs/m14/bugs5/pr-map-pick-report.md
