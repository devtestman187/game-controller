## Summary

Verdict: **one fix batch**.
Counts: 1 must, 3 should, 6 could.
The run is one job (`unmarked-drop`, ca2306af) plus a review job that never wrote its report
(run.log:9). The code does what the owner asked and the tests are real (both new files fail on the
old code, run.log:6-7); what is wrong is around it, not in it.

The five that matter:
1. `docs/protocol.md:207` still states the opposite of the code ("a file saved before this build …
   uploads as it was saved"); no job could fix it, the brief said no docs.
2. The rewritten `uploadable_old_players_test.dart` is now a near-verbatim copy of a case in the new
   `uploadable_unmarked_test.dart` (same fixture, same assertions).
3. `live_stats.dart` is at exactly 380 lines with the drop rule spread over three places, while
   code-health:112 asks for the upload-queue split "at the next stats job" — this was that job.
4. The wave1 review (its brief is in the folder) never ran, so this is the change's first review.
5. Two code-health entries give `live_stats.dart` 380 and 369 lines and neither records this job.

Questions only the owner can answer: whether a dropped session must be visible in the Stats screen,
and whether to run the missing wave1 review or treat this pass as it.

## Findings

Sizing: files per finding are in the bullet. Jobs of ≤3 with no shared file — A: protocol.md +
code-health.md (doc only); B: the `live_stats.dart` split (alone, it rewrites the lines the others
touch); C: the skip-write batching + prune + log (same file); D: the two test files. **No finding is
pinned by controller_app (phone) tests**, so no `phone` in `check:`; `format analyze metrics host`
covers A–D, `phone` is unaffected (528 tests pass on this tree).

- **must** docs/protocol.md:207 still says "A file saved before this build, with no `share` on any player, uploads as it was saved", which the code now forbids (live_stats.dart:321 drops it) → replace that sentence with "a file saved before this build, with no `share` on any player, is never uploaded; it stays on the device" (from: across jobs)
- **should** packages/metrics/test/uploadable_old_players_test.dart:36 is a near-verbatim duplicate of uploadable_unmarked_test.dart:35 (same players a/b, same two rounds, same frames, same assertions; `oldFile()`'s `schema: 1` equals `summarySchema`) → delete the file, or keep it as the case nobody covers: a summary with no `players` key or a non-list `players`, so the drop rule is pinned for hand-edited and broken files too (from: unmarked-drop)
- **should** packages/party_host/lib/src/live_stats.dart:308-357 — the drop rule now sits in three places (315, 321-324, 353-354) and the file ends at exactly the 380-line cap that code-health:112 says to split at the next stats job → move the upload queue (pending, skip, retry) into its own `src/session_upload_queue.dart` in a brief that allows a new lib file (from: across jobs)
- **should** docs/briefs/m14/sentry2/run-findings.md:1 — the wave1 review wrote no report, so the run's only job had no second pair of eyes until this pass; its brief sits unused in the folder → accept this review as covering it and note the gap in STATUS, or run the brief (from: across jobs)
- **could** packages/party_host/lib/src/live_stats.dart:321-324 writes one `setStringList` of the whole growing list per dropped file (N writes of N ids on the first pass after an upgrade) and nothing ever prunes an id → collect the dropped ids and write once after the loop, and drop an id from the list once its file is gone (from: unmarked-drop)
- **could** packages/party_host/lib/src/live_stats.dart:321 drops a session with no trace: no `_log` line, so a tester cannot tell a dropped old file from a failed upload → log one line with how many files were dropped (from: unmarked-drop)
- **could** packages/party_host/lib/src/stats_state.dart:20 documents `waiting` as "finished sessions waiting to be uploaded" without saying a session with no share marks never counts and dropped ids are left out → add that sentence (from: unmarked-drop)
- **could** packages/party_host/test/live_stats_unmarked_test.dart:119 has no case where every player answered `share: false` (must still upload, with round totals only) and none with consent off (no skip written), though the report's self-check 2 claims the second → add the two cases to the new file (from: unmarked-drop)
- **could** packages/party_host/test/live_stats_unmarked_test.dart:116 spells the private prefs keys `skippedSessions` (and :121 `uploadedSessions`) as literals; code-health:136 tracks the same debt for `statsConsent` → add accessors in `party_host`'s testing library when that item is done (from: unmarked-drop)
- **could** docs/code-health.md:112 and :174 disagree on `live_stats.dart` (380 vs 369 lines) and neither records this job's growth back to 380 → merge the two into one entry with the current size and the split (from: across jobs)

Hand-fixes: `run.log` has no `HAND-FIX` line, so there is nothing to list; both jobs' tests-first
proof exists (run.log:6-7) and the only job has a report (unmarked-drop-report.md).

## Open questions

1. Must a dropped session be visible on the Stats screen? Suggested: yes, one plain line ("Kept on this device, not shared") in a later UI job.
2. Prune `skippedSessions` now or with the delete path? Suggested: with the delete path; record it in code-health so it is not forgotten.
3. Should a drop be logged? Suggested: yes, one aggregated `_log` line — a tester will ask why nothing uploaded.
4. Split `live_stats.dart` next? Suggested: yes, first stats job of the next wave, with the new lib file allowed.
5. The missing wave1 review: run it or fold it into this one? Suggested: fold it in (this review read the same change) and fix the runner step.
6. `live_stats_share_test`'s player-order failure, seen once: `unorderedEquals`? Suggested: yes when it reappears, but the fix needs a failing reason first — it did not fail in the 586-test run here.

## Numbers against targets

- `packages/party_host/lib/src/live_stats.dart`: 380 lines — the cap code-health:112 sets, against the ~300 aim (guidelines §3); no headroom left. Misses the target.
- `packages/metrics/lib/src/uploadable.dart`: 67 lines, in target. `hasShareMarks` is 2 lines, documented.
- metrics 172 tests PASS, host 586 PASS (report says the same; I re-ran them), phone 528 PASS (not in the job's `check:`), format PASS, analyze PASS on this tree.
- Tests-first: both new files fail on the old code (run.log:6-7). No fix in the batch is a fix by reasoning alone — every behaviour changed has a test that failed before it. Unverified: nothing; the `live_stats_share_test` flake is the only unmeasured claim.

## Could not check

- No `docs/briefs/m14/sentry2/STATUS.md` exists, so the run's status row below is drafted for one.
- No `*-review-report.md` in the run: the per-job review item of this brief has nothing to carry.
- The `live_stats_share_test` order flake: not reproduced (host suite passed once here).
- The working tree carries uncommitted churn from the runner's own commands (`site/shots/*.png`, `docs/design/m13-tablet-board.png`, `tv_test_app/windows/flutter/generated_*`); none of it is in the run's commits, so it is not judged here.

## Commit message

```
runner: the run's review of sentry2

Read the run's one job (unmarked-drop, ca2306af) as a single change against the coding guidelines,
the review rules and its brief, and recorded one findings list for Claude: 1 must, 3 should, 6 could.
The must is protocol.md:207, which still describes the old upload of unmarked files; no job could
reach it. The rest: a rewritten test that now duplicates a new one, the live_stats upload queue at
its line cap, the review that never ran, and the skippedSessions bookkeeping.
```

## Status row

- **M14 sentry2 (unmarked-drop, run review):** done — sessions with no share mark are never uploaded and are listed in `skippedSessions`, pinned by tests that failed on the old code; open: `docs/protocol.md:207`, the duplicate `uploadable_old_players_test`, the `live_stats.dart` queue split, pruning `skippedSessions`, a Stats-screen note for a dropped session, and the missing wave1 review.

## Delete

- none
