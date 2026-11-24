# bugs4 REVIEW (B-040): driver verdicts

Final state after the Q8 rework (owner Nov 24): the first run's design (phone-computed awards, winner line on the last round card) was replaced. Jobs: b040fit (card scales to fit), b040awards (kept only as NightState.withAwards, used by PartyNight; the last-round card no longer uses it), b040win (winner line, replaced by np1/np2), nc1 (night_end + `night` capability), nh1 (GameHost.showNightEnd), nk1 (client stream, hello lists `night`), nh2 (host sends at the reveal's end or skip), np1 (provider, "Awards coming..." on the last round, no standings or winner there), np2 (awards, final standings and true winner from the message).

Cause of B-040: measured (probe at 568x320): a night result card with 6 standings put the "Waiting for the host" line at y 341 of 320, 4 rows overflow by 2 px, and Shape Race adds a picture; the card sat in a Center with no scroll and no scale, so the line was off screen. The round result did reach the phone (host fake test: both players get one). The rest of B-040 was by design: the night's awards and final scores are host-only screens.

## Verdicts on worker findings (waves 1-6 and the first run review)
- Real, fixed by hand: night_end.dart sent points 3 for an award nobody won (now 0; phone line shows no "+0"); the award line had maxLines 1 and could cut its points (removed); the tied-phone test did not exercise the tied phone (case added). Commit: the wrap commit.
- Real, fixed in run: nc1's two exhaustive switches (client_messages.dart, host_connection.dart; class a), nh2's two reveal tests needing a host service (class c). Both logged as HAND-FIX.
- Superseded by the rework: first-run M1-M3 (awards computed on the phone), b040win winner line tests, round_results awards test (now pins last-round standings WITHOUT awards).
- Minor, to docs/code-health.md: protocol coverage_all_test.dart was edited by hand though generated (regenerate with the tool); host_server.dart is at its 380-line limit (split the capability table next time a row is added); host_connection.dart `night_end` from a phone closes with protocolError (no test); Back path of the reveal not tested for exactly one send; award line at 568x320 with a long winners list untested; client_messages comment fixed.
- Report text fixes (nc1, nh1, nh2, b040fit, b040win reports claim states that changed) are not worth edits: the code and run.log are the record.
- mine.sh reverted tv_test_app generated plugin files and docs/design PNGs outside job lists (churn, never committed by us; they were already modified before the batch). Tool proposal: revert only files the job changed. Owner may want to look at `git status` for the PNGs.
- Decision recorded: an early-ended night (End night) also sends night_end at the reveal's end, so the phone gets awards there too; its last round card has no "round == of", so it shows standings until the message arrives.

## Numbers
- Full check: `RUN_CHECK_FULL=1 CHECK_CACHE=0 bash tools/check.sh --no-cache` 13/13 green, 578 s, on the tree before the wrap hand-fixes; format and analyze green after them, and the touched tests re-run green.

## job-metrics
JOB turns/minutes (haiku): b040awards 25/4.1, b040fit 20/3.9, b040win 24/4.1, nc1 43/3.0, nh1 24/3.4, nh2 69/8.6, nk1 43/3.8, np1 46/7.4, np2 38/6.4. Runs: first run 3 jobs 29 min; rework 6 jobs 17 min of worker time over 3 restarts (2 stops).

## agent-cost
agent-cost since 2026-11-24 11:30: haiku $0.06, opus $6.29, sonnet $6.93; total $13.29 (the opus line is the main session, not this batch alone).
