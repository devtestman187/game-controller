job: tune4a h4b — tuning report REPORT-v3.md with at most 3 proposals, nothing applied
stop: no edit to any file but the report. No change to rules.dart, sim_rules.dart, FuseParams or settings.dart. Do not start h4c.
read: docs/briefs/templates/COMMON.md · docs/briefs/m17/city/sim-results-v3.csv · docs/briefs/m17/city/sim-tables-v3.md · docs/briefs/m17/city/REPORT-v2.md · docs/briefs/m17/tune4a/h4a-report.md · owners: "the rules report (report only, no rule changes)"; "M17b limited to the plan doc and the C4 simulator report. No rule changes applied."; Shape Race team payouts per player (winners 3 Bolts, losers 1, doubled in the last game; solo kept 5/3/2/1, places 5-8 at 1) are provisional: model as context only, never apply
changes: REPORT-v3.md (new)
model: sonnet
turns: 50
expected-min: 25
tests-first: exempt docs only
do:
1 Write docs/briefs/m17/city/REPORT-v3.md for the owner: results against the targets (winner reaches the Plaza in 9 of 10 nights; 5-game night 25-35 min, N1), then the Fable-flagged measures for 3-8 players: catch-up rate for last at the midpoint (headline, replaces "comeback"), spread, Plaza reach; repeat rate and night length are not measured by the model: say so and list them as proposals for new data. Every figure cites a CSV row as `csv:<row number>` (row 1 = first data row).
2 Answer or mark unresolved, one line each, the open Fable findings: Roadworks at 1 Bolt gives no catch-up (last at midpoint finishes not-last 51-60% with or without it; at 8 players the user ends worse off 37%); "comeback" is a weak measure; a 3-game night almost never reaches the Plaza; the tile-4 gate never binds; the 61% Plaza figure for a 5-tile road is unverified (cite the measured row or strike it).
3 At most 3 proposed rule changes (candidates: Bolt rate, Roadworks effect, tile cost at 5-8, gate cost), each with the number it moves (CSV rows) and the downside. Option A is "no change". Include a Firestore stats fields table (spread, Plaza reach rate, catch-up rate, night length, repeat rate) as a proposal, not applied. A short context note may model the Shape Race team payout as context only.
4 End with the exact question for the owner (Q-A) choosing A or one of the proposals. List the proposals in one line each at the top.
allow: docs/briefs/m17/city/REPORT-v3.md
check: format
report: docs/briefs/m17/tune4a/h4b-report.md
