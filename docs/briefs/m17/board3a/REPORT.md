# board3a (board-1) report: Haiku-driver trial, PAUSED for main
Tip: 5da5355d (board-line). Range: 15fab9fd..5da5355d. Result: PASS on the full check; batch NOT complete for the design: g3b rules were rebuilt twice on the owner's road model; release notes "No visible change".
Full check: All checks passed (29s, 11 cached). Logs: C:\Users\mrman\AppData\Local\Temp/thumbparty-check-20261127-001823 (re-run after g3b4).

## Commits and jobs (Haiku workers, ladder 1 unless noted)
- g3a board types (646e5a06; rework in 8c5eacbe): 11 turns, 1.3 min worker. First run result 5 (analyze info, mine.sh checked 0 files): repair note applied, ladder 2, retry green.
- g3s stubs (e4f8a0be): 21 turns, result 0. First attempt result 2 (runner snapshot failed on the absent sibling report): gate class, not the worker.
- f3a fix round (7afeeca8): 17 turns. First attempt result 5: host suite red on existing live_stats_answer_kept_test (passes alone): environment; unchanged retry green.
- g3b rules (50b963e3): superseded by the owner road model. Its 9 review findings are superseded, not verdicted.
- g3b2 rework (8c5eacbe): 22 turns; 7 review findings, all turned into main verdicts (below). First g3b attempt resumed stale job state and was refused: capability/gate class, fixed by the new job name.
- g3b3 (a52abe50): main verdicts applied. g3b4 (343a757e): kids flag, driveCost without parameters, corner names in CityRules. Its wave5 review (5 findings) was not taken into a further fix round (max 2 rounds per wave reached).

## Findings and verdicts (main)
- tools/mine.sh untracked-folder gap (must): OPEN, shared file, main to fix. City/ checked by explicit path.
- Kids preset: fixed in g3b4 (flag), but wave5 notes the flag is read by roadworksOffered's own argument: two sources. OPEN for main.
- Last-place roadworks rule on kids night: not built (no place parameter). OPEN, design-adjacent; main to confirm.
- Duplicate corner names in tests (should): OPEN, cosmetic.
- driveCost duplicate test (could): OPEN.
- rankFinal doc "players 5-8" vs corners.length (could): OPEN.
- Worker ran tools/mine.sh despite the brief ban (process): lesson for the runner: do not let a worker call a tool the brief bans.
- New tests added to existing rules_test.dart although a new file was the rule: OPEN for main (guidelines 11).

## Owner-pending (in REPORT as asked)
- Team-game payouts and places 5-8 (1 Bolt placeholder): owner-pending.
- Owner answer FINAL (Nov 26 late) used for the road model.

## Trial record (Haiku driver, gates)
- Judge (Sonnet) spawns: 6 of 6. (1) wave-1 briefs, trigger: brief before runner. (2) g3a/g3s repair advice, trigger: STOPPED. (3) run review F1-F7, trigger: REVIEW. (4) wave-2 review verdicts, trigger: REVIEW. (5) g3b brief, trigger: brief before runner. (6) g3b rework brief, trigger: brief before runner.
- Judge overrides by driver: f3a brief import from night/ overridden (batch rule). Judge had no spawn left for wave3-g3b2, wave4, wave5 review findings: main was the judge for those (trigger missed by budget, recorded).
- Waiter spawns: about 10 thumb-wait and about 5 thumb-haiku (reads and waits). Driver tool calls: about 90 (not counted exactly).
- Driver prompt size: not measured; no handoff.
- Gate misses: judge budget ran out before REVIEW verdicts on three reviews (main stepped in); one runner brief-gate stop for a missed allow path (fixed by brief edit); a stale-state resume of g3b (renamed to g3b2).
- Cost: agent-cost since 2026-11-26 21:40: fable $2.23 (cw5m 0.00M cw1h 0.08M), haiku $1.11 (cw5m 0.44M cw1h 0.91M), opus $5.41 (cw5m 0.00M cw1h 0.09M), sonnet $3.73 (cw5m 0.00M cw1h 0.39M); total $12.49; sonnet resumes >5m 6 (0.01M written), >60m 0 (0.00M written); i (mixed window with other batches; not split by agent).

## Release notes (final)
No visible change. Internal groundwork for the City Rush board (not in any game yet): the board's roads, tiles and gates, and stand-in parts for round placing and the champion rules. Please check nothing else changed.

## Process
- Runner: no background command of this batch is still running; proc-sweep 0 processes.
