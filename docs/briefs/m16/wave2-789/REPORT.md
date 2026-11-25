# wave2-789 report (items 7-9 remainder)
Base 70bcd97a, tip 7b4ab9e6. 11 waves, 31 jobs, about 14 runner restarts. Nothing pushed, tagged or built.
(Saved by main from the driver's hand-back; the driver's Write was refused.)

## Owner decisions applied
9e closed by owner decision (A); tablet Resume colour not checked. n9e2 not built. n9e3 built (a+c): during a pause only the phones that may resume get "Resume"; others keep the menu layout; the input filter is kept.

## Owner questions (none blocking)
1. n9sr: should "Round N of M" also show on the split and phone Shape Race screens? Today the one-board painter only.
2. Q7 A gap: with no host discovered, reconnectToLastHost connects to the remembered address (connection.dart:197-199), so the pad shows and a failed connect then goes to Home. Keep, or send the phone to Home at once?
3. The Show tips row sits outside the Settings cards, in the motion column: choose card and column.
4. 60 phone-host controls are below 48 dp (host frame 48 px controls scale to 19-32 dp on phones; table in n9b3-report.md). Needs a frame-scale design decision; no fix job built.
5. TV-look top bar at 568x320 overflows 12 px (known); the chip label at 667x375 in the TV look is still cut (TV bar is 87 dp).
6. churn_revert policy: tools/churn.sh reverts generated tv_test_app files that were already dirty before a job. Should it skip files dirty at job start?

## Jobs (model, ladder, turns (cap), failure class, hand fix)
n8a haiku 1, 16, none. n9b1 sonnet 1, 65 (60), capability, apply-job 0 lines. n9e haiku 1, 18, brief (premise wrong: Resume already good; no change). n8b0 haiku 1, 21. n8c sonnet 1, 66 (50), capability, apply-job 0 lines. n9sr haiku 1, 58.
Wave 3: n8b1 sonnet 1, 36, gate (review.sh: build over 60 lines), split by hand ~12 lines. n9b2 sonnet 1, 1 logged (real ~25 min), gate (same), split by hand ~25 lines. n9b3 sonnet 1, 60 (70), none.
Wave 4: f1 haiku 1, 46. n8d2 haiku 1, 26. n8b2 sonnet 1, 75 (70), capability (work complete, checks green), apply-job 0 lines.
Wave 5: n8d1 sonnet 1, 68 (70). n8b3a haiku 1, 29, brief (marks overlay swallows the tap; found in n8b3). n8e0 haiku 1, 26 (TV-word inventory).
Wave 6: f2 haiku 1, 69 (60), brief (anchors test as briefed cannot be built), partial apply 0 lines. f3 haiku 1, 23, committed by hand after the stop. n8b3 sonnet ladder 2, 99 then 1 logged (~28 min real), brief (allow list missed ~100 Home-first test pins; marks overlay swallowed reachConnect's tap), hand: pump_app `toConnect` default 14 lines.
Wave 7: f4 sonnet 1, 75 (70), capability (work complete), apply-job 0 lines. n8e2 haiku 24, n8e3 haiku 20 (committed by hand because parked f4 was absent from the combined check).
Wave 8: n8e1 haiku 36, n8e4 haiku 15, n8e6 haiku 20 (3 strings missed, fixed by hand).
Wave 9: n8e5 haiku 28, n9e3 haiku 36, f5 haiku 26. Wave 10: f6 haiku 27, f7 haiku 15. Wave 11: n8g haiku 23 (committed by hand after an env-leak check failure, 0 lines; dead allowed-list branch removed by hand after review).
Counts: stops 14 (parked over cap 5: n9b1, n8c, n8b2, f2, f4; failed combined or review checks 6; rest stale or double-restart stops; pauses not counted). Hand-fix events 17 (apply-job 6, hand commits 6, hand edits 5). 9 Sonnet briefs of 30 jobs (30%), 10 Sonnet runs (n8b3 ran twice, ladder 2; corrected in tune4 M1 from "11 of 31 jobs (35%)", which counted runs as jobs), each within the tag rule; n8b3 and f4 over-ran because their allow lists were too small.

## Why n9b1 and n8c hit the cap yet applied with 0 lines changed
The work was done and the cap was too low. Both logs end with a finished report, format and analyze PASS and a commit draft; no loop. A new widget test over four sizes and two looks needs 60-70 turns. The runner parks any job over its cap, and the three tracked generated tv_test_app files gave result 4, so finished work was parked instead of committed; apply-job.sh copied it unchanged. Sonnet new-test jobs should get turns 70-80.

## Tooling that misbehaved
1. A restart after a hand-commit stops once and needs a second restart; a pause restart reviews the last wave and pauses again without running the next wave (3 times). thumb-wait cannot tell stale lines from new; wait-run.sh appends its RESULT line to run.log; one waiter waited 58 min on a stale line.
2. "1 turn, 0 min" logged for sessions that resumed after a timed-out background command (n9b2, n8b3): the counter reads the last resume only; real runs 25-28 min.
3. A parked over-cap job is missing from the combined check, so siblings' check fails. RUN_PAUSE_AFTER_WAVE=1 leaks into tools/tests/run-tune2-test.sh and run-wire2-test.sh. run-wire2-test's STOP-file case is flaky under -j 4.
4. churn_revert (tools/churn.sh, mine.sh) reverts generated tv_test_app files dirty before the job; site/shots, docs/design PNGs and tv_test_app generated files are rewritten by every test run.
5. A failing phone suite (~100 failures) ran 22 min without a log line; waiters reported STALLED.
6. brief-check `changes:` matches comments and unrelated files; forced literal strings and the HomeScreen -> PhoneHomeScreen rename.
Lesson candidates: (1) brief premises from an inventory helper must be checked at file:line (n9e); (2) a launch-route change starts with the test helper as its own job (n8b3); (3) cap 70-80 for Sonnet new-test jobs.

## Findings
All wave reviews verdicted in REVIEW-VERDICTS.md. Real and fixed: tips-saved-with-no-anchor gate and exit adapter (f2), test positive controls (f3, f5, f6), demo mode did not close Home (f4), connection strings (f7 and three by hand with the smoke.sh pin), dead branch in tv-word-check.sh. Minor items in docs/code-health.md (Nov 25 entry).

## Checks and metrics
Full bash tools/check.sh -j 4 on the tip: all suites 0 except tools failed once (flaky run-wire2 STOP case), then `check.sh tools` PASS (265 s). agent-cost since 22:00 Nov 24: fable $1.88, haiku $1.13, opus $4.81, sonnet $15.22, total $23.05 (includes M17 scoping research run in parallel). Driver calls ~130 + first driver 59; thumb-wait agents 19. Wall time ~6.5 h (22:14 Nov 24 to ~04:25 Nov 25).
Uncommitted on purpose: tv_test_app generated files, docs/design and site/shots PNGs (test churn), deleted STOP.md.
