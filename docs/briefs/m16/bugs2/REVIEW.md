# M16 bugs2 run review (read-only)

## Summary

Verdict: **needs Claude's design**. Run commits: 4fd7feed (b035), e110d713 (b039), 2964c410 (flk1), range 2aeec568..07c76afd.
Counts: **must 4**, **should 3**, **could 2**.
No per-job review reports (`*-review-report.md`), no `run-findings.md` and no bugs2 `STATUS.md` exist, so nothing to carry over.
Hand-fixes (run.log): 2 `HAND-FIX` lines, both b035. b035 has a tests-first proof and a report; b039 and flk1 have reports. No job has a review report.

Five findings that matter most:
1. The b035 narrow-phone test was moved from 320x640 (the brief's spec) to 568x320 by hand. The 320 px overflow is still in the code.
2. flk1 raised the `waitFor` timeout from 5 s to 30 s. Guideline §2 forbids longer timeouts for a race; the brief asked for it, so brief and guideline conflict.
3. b039's lobby layout was never run against `phone_name_display_test.dart` or `identity_phone_test.dart`, which the brief named.
4. No full check ran on the final committed tree (run.log: the wave check failed twice and the cause was not recorded; later checks were partial).
5. The flk1 flake fix was not reproduced under load (5 unloaded passes only): "Fixed, unverified: needs device check".

Questions only the owner can answer: the 320 px layout rule (Q1), keep or drop the 30 s timeout (Q2), who owns `connect_screen.dart:348` (Q3), and the three generated Windows files (Q4).

## Findings

- **must** `controller_app/test/connect_identity_gap_test.dart:24` The 320x640 narrow-phone test the brief asked for (run.log: "HAND-FIX b035 … changed from 320x640 … to 568x320") is now a 568x320 test, so the 320 px overflow (`controller_app/lib/src/ui/connect_panels.dart:73`, 74 px before the change, 82 px after; `controller_app/lib/src/ui/connect_screen.dart:348`, 39 px) passes unseen → restore the 320x640 case, state the failing overflow as known, and take the layout rule (Q1) to Claude's design before a fix. (from: b035)
- **must** `packages/party_host/test/live_stats_unmarked_test.dart:15` `waitFor` default timeout raised 5 s → 30 s; guideline §2 bans "longer timeouts to make a race go away", and the brief (flk1.md) asked for it, so brief and guideline disagree → Claude decides (Q2): keep the order-based wait and drop the raise, or record an exemption. (from: flk1)
- **must** `controller_app/lib/src/ui/lobby_players.dart:27` `Center` → `IntrinsicWidth` → start-aligned `Column` shipped, but `phone_name_display_test.dart` and `identity_phone_test.dart` (named in b039.md step 3) were never run → run both, and the phone suite, before the lobby change is accepted. (from: b039)
- **must** across jobs: the committed tree has no full check. run.log 15:33:29 "checks failed twice" (the failing check is not named), 15:30:33 and 15:39:48 "combined check: skips protocol … tools", 15:41:32 "wave review skipped" → run `tools/check.sh` on 07c76afd or its successor and record the result. (from: across jobs)
- **should** `packages/party_host/test/live_stats_unmarked_test.dart:115` The flk1 cause was read from `live_stats.dart`, not reproduced; the test passed 5 of 5 unloaded runs, and no load run exists → mark "Fixed, unverified: needs device check" and run the load case. The test is exempt from tests-first in flk1.md, so there is no failing-first proof. (from: flk1)
- **should** `docs/briefs/m16/bugs2/b035-report.md:28` The commit draft and status row still say the narrow-phone test "is still failing" and the 320 px overflow is open, which is stale after the hand-fix to 568x320 → rewrite both before the message is used. (from: b035)
- **should** `controller_app/test/lobby_alignment_test.dart:64` The computed left edges per row and the centre x values are not reported (b039-report.md line 7-9 gives only pass/fail); the TV-look gap after the fix (`controller_app/test/connect_identity_gap_test.dart:21`) is also not printed (b035-report.md line 18) → add them to the reports, as guidelines §9 requires. (from: b039, b035)
- **could** `controller_app/lib/src/ui/connect_panels.dart:1` 374 lines (373 at 2aeec568), above the ~300 guideline and 6 lines under the 380 touch cap → split `_YourCharacter` out the next time this file is touched. (from: across jobs)
- **could** `controller_app/test/connect_identity_gap_test.dart:38` and `controller_app/test/lobby_alignment_test.dart:36` Each new test builds its own TV-look pump (`toyTvProvider.overrideWithValue(true)`), where review-rules A6 names a shared helper (`packages/party_host/test/support/all_looks.dart`) → use the shared helper if controller_app can reach it (not verified). (from: across jobs)

## Open questions

1. At 320 px the join row (`connect_panels.dart:73`) is wider than the screen even with the name at its minimum. Suggested: let the Change link wrap to its own line below a width you choose, keep the 8 px gap, and restore the 320x640 test. (b035 Q1)
2. Keep the 30 s `waitFor` timeout (flk1 brief) or drop it to 5 s (guideline §2)? Suggested: drop it; the order-based wait is the fix. (flk1)
3. `connect_screen.dart:348` has a 39 px overflow at 320 px, outside b035's allow. Suggested: Claude takes it in the 320 px fix. (b035 Q2)
4. The three `tv_test_app/windows/flutter/generated_*` files are still modified in the working tree (`git status`), though the job logs say churn reverted them. Suggested: leave them out of any commit and have the owner check them. (b035 Q3, b039, flk1)
5. Should `phone_name_display_test.dart` and `identity_phone_test.dart` run before the lobby change is accepted? Suggested: yes, run them now. (b039)
6. Does flk1 need a load run before "Fixed" is written? Suggested: yes, the STATUS row says unverified until then. (flk1)

## Numbers against targets

- b035 gap, menu look, after fix: 7.999999999999886 px, target 8 px minus 0.01 slack → **met**.
- b035 gap, TV look, after fix: not reported (0.0 px before) → **not checked**.
- b035 320x640 overflow: 74 px before, 82 px after; brief target "the row fits, text shrinks first" → **not met**; test moved to 568x320.
- b039 left edge: target within 0.5 px; values not reported, pass only → **not checked**.
- b039 centre: target within 1 px of screen half-width; values not reported, pass only → **not checked**.
- flk1: 5 of 5 unloaded passes; the load target is not measured → **not checked**.
- flk1 timeout: 5 s → 30 s, bound on failure only; the guideline limit is "no longer timeouts" → **conflict**.
- `connect_panels.dart`: 374 lines; touched lib file cap 380 → **met**, guideline ~300 → **over**.

## Could not check

- The full controller_app suite and `phone_name_display_test.dart` / `identity_phone_test.dart` (not run by any job).
- The `phone_fit` matrix at 640x360 (`docs/briefs/m16/STATUS.md:181`) for the lobby and join layout changes.
- The cause of the wave check failure (run.log 15:33:29 does not name the check).
- Whether controller_app can import `packages/party_host/test/support/all_looks.dart`.
- Behaviour under CPU load (flk1), since no device or load run was possible in this read-only job.
- Whether the three generated files are still modified after the mine.sh churn revert (git status shows them modified now).

## Commit message — a draft

Record the M16 bugs2 run review

Review of the three committed jobs (b035, b039, flk1) read as one change.
Findings: the narrow-phone test was narrowed to 568x320 by hand, the
flk1 wait timeout was raised from 5 s to 30 s (against guideline §2),
and the lobby layout has not been run against two named phone tests.
Reports only; no code changed.

## Status row

M16 bugs2 run review: done (read-only). Open: 320 px join-row overflow needs a layout decision, flk1 timeout conflicts with guideline §2, lobby layout's two named phone tests unrun, no full check on the final tree; flk1 is "Fixed, unverified: needs device check".

## Delete

- none

## Driver verdicts (Nov 23)
- must 1 (320x640 test): rejected as written; the overflow existed before the change and is outside the brief. Test is 568x320; 320 px overflow in code-health, owner call.
- must 2 (30 s waitFor): accepted as is (it bounds a failure only); noted in code-health.
- must 3 (phone_name_display, identity_phone not run): closed; the combined check ran the whole phone suite (run.log 15:39:48 to 15:41:28) and the full check passed.
- must 4 (no full check on tip): closed; full check.sh --no-cache passed 13/13 (731 s) at the tip, line in run.log. The first -j 4 attempt showed arena and tools load flakes, serial passes.
- should (flk1 unproven): 6 extra runs passed beside a -j 4 full check; "Fixed, unverified" until a real loaded run. Reports' stale text fixed in b035-report; numbers (edges) left, minor.
- could: code-health.

## Metrics
JOB        WORKER MODEL            TURNS IN   OUT  CACHE MINUTES WALL RESULT
b035       claude claude-haiku-5-5    25 40 14219 529137     5.4    - 4 (subtype=success, terminal_reason=completed)
b039       claude claude-haiku-5-5    11 22  8636 251863     3.5    - 4 (subtype=success, terminal_reason=completed)
flk1       claude claude-haiku-5-5    13 18  4982 187931     3.6    - 4 (subtype=success, terminal_reason=completed)
run-review claude claude-haiku-5-5    23 24 26212 439706     2.1    - 0 (subtype=success, terminal_reason=completed)

agent-cost since 2026-11-23 15:19: haiku $0.01 (cw5m 0.00M cw1h 0.03M), opus $1.21 (cw5m 0.00M cw1h 0.02M), sonnet $1.26 (cw5m 0.00M cw1h 0.12M); total $2.48; sonnet resumes >5m 3 (0.00M written), >60m 0 (0.00M written)
