job: M14 bugs6 b015-routes: draw the two race routes for the owner to approve (B-015). NO map ships from this job
pub: no
stop: after it. The owner approves the pictures first; land no change in packages/ or docs/design/maps/.
read: packages/test_game/maps/block-castle.json · toy-factory.json · map.schema.json · packages/test_game/test/support/map_sheet.dart and map_files.dart · tools/level.sh (check, render) · docs/levels.md Arena part · the map rules for a race in packages/test_game (start column, 1.6 marble width, hazards)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
tests-first: exempt pictures and a report only; no code or test lands

Owner: "Yes, produce the pictures first so I can review." Proposal: two of the four Bumper maps carry a Race by adding a race section.
 - Block Castle: "race": {"start": [0.075, 0.5], "goal": [0.4625, 0.444, 0.5375, 0.556], "swapSides": true} (in through a castle gate, across the courtyard past the left cannonball, into the keep through a gate; symmetric goal).
 - Toy Factory: "race": {"start": [0.1, 0.5], "goal": [0.88, 0.14, 0.97, 0.24], "swapSides": true} (over the belt loop, round the two walls, up the east side into a finish bay with the crate hazard on its rim).
 Pinball and Spinning Tops are not made races (post spacing under 1.6 marbles; a finish inside the carousel's sweep).
do:
1 For each map, put the race section in a TEMPORARY edit of the map file, run the map rule book on it (tools/level.sh check) and any race-play test that exists. If a rule fails, adjust the numbers minimally and say what and why.
2 Render a picture of each candidate race: the map sheet with the four start slots, the goal and the route as a clear arrow (both directions, since swapSides is true), saved as PNG at docs/briefs/m14/bugs6/b015-routes/block-castle-race.png and toy-factory-race.png. If the sheet code does not draw the race, produce the picture by a means that leaves no code in the repo (a temporary test you delete, or an SVG written by hand beside the PNG); say how.
3 Save the final candidate race sections as docs/briefs/m14/bugs6/b015-routes/<map>.race.json so a later job can paste them in.
4 REVERT every temporary change: at the end packages/ and docs/design/maps/ must be identical to the start (the runner stops on any stray file). Say in the report that you did.
5 The report lists the rule-book and play-check result for each map and what the owner should look at (the risk: an open arena makes a thin race; all four starts share one x).
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): what was built, the numbers that matter, decisions, questions, anything not done, and what the owner should try on a device. Then Self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it. Do not claim a test passes unless you ran it in this job and saw it; write "not run" otherwise. If a cause is unmeasured, say "needs device check".
rules: aim for 80-150 turns · write only inside allow: · packages/ and docs/design/maps/ unchanged at the end
allow: docs/briefs/m14/bugs6/b015-routes-report.md · docs/briefs/m14/bugs6/b015-routes
check: format
report: docs/briefs/m14/bugs6/b015-routes-report.md
