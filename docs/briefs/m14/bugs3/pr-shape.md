job: M14 bugs3 pr-shape: report-only proposals for owner change requests (NO code changes)
pub: no
stop: after it.
read: docs/design/party-night.md · docs/PRD-v2.md section "Milestone 14" · the code the items name (read only what you need)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

This is a PROPOSAL job: change no file except your report. For each item below write a concise proposal: what changes (player-visible), why, options if there is a real choice (with your pick), files touched, tests, risk. Keep each proposal under 25 lines and make it text the owner can approve as written. Put each proposal under its own heading "### B-0xx". If an item conflicts with the design documents, say so and say how.

B-009 (owner: "When selecting next puzzle, the same puzzles repeat before a new one is selected. We should do new ones before any repeat.") Propose a no-repeat-until-all-played rule for the next-puzzle choice (shuffled bag, persisted across sessions or not, interplay with difficulty and the Auto look).
B-012 (owner's feedback, Shape Race: "1. Need metrics to see how much time is spent moving character around vs placing pieces. 2. Make the actual puzzles harder. Medium should be easy. Need a harder mode with more time by default. 3. Plan for increasing difficulty levels that have more pieces, need more complicated rotations, pieces that fit together like an actual puzzle (future, maybe M16?)"; observation: a five year old completes medium puzzles in about 2 minutes, most of the time spent moving the player). Split the proposal into: (1) the metrics (what to measure, where in the stats), (2) a harder difficulty and retuned Medium (concrete numbers: pieces, time, rotation), (3) what to leave for M16.

in the report: start with `## Summary` (at most 30 lines): one line per item (the pick and the risk). Then the proposals.
rules: report only; write only the report file · no code, no scratch files
allow: docs/briefs/m14/bugs3/pr-shape-report.md
check: format
report: docs/briefs/m14/bugs3/pr-shape-report.md
