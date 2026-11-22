# REHEARSAL-RESULT (process4, Nov 22)

PASS 1 `bash tools/check.sh tools` (inside the full check, 553 s) and `RUN_CHECK_MAX_MIN=3 bash tools/check.sh tools` (556 s)
PASS 2a replay wave1 brief-check: FAIL names client_messages.dart, host_connection.dart, codec.dart, m9_test.dart (exit 1)
PASS 2b replay wave2 brief-check: FAIL names phone_metrics_test.dart and m9_test.dart (exit 1; also 17 hits for `Capability.view` per job: noisy)
PASS 2c replay probe-deps wave1: client_messages.dart and host_connection.dart FAIL (after fixing a bug: dart analyze's exit 3 was read as a timeout); no worktree left
PASS 2d replay wave1-split: dependence FAIL on i1a2 in the same wave
PASS 2e layers: WARN layers on arena_roster.dart (after fixing a bug: review.sh's padded columns hid the file name). The probe used a one-line patch on the wave 2 base, not i1f's real diff, so the WARN text differs from the recorded miss
PASS 3a one job parked (r2), r1 and r3 committed, STOPPED names r2, done.txt r1 r3
PASS 3b `WARN: job r1 used 121 turns, over its cap of 120 ... accepted`, committed, DONE
PASS 3c apply-job brought the untracked r1-note.txt and the report, SKIPPED outside.txt, HAND-FIX line in run.log
PASS 3d brief-check refuses an overlap: dry run exit 1, the start `STOPPED: brief gate: brief-check failed: ...`; BRIEF_CHECK_SKIP=rehearsal starts with the WARN; a `changes:` hit allowed only in a later wave FAILs (dry run exit 1) and starts with BRIEF_CHECK_SKIP
PASS 3e estimate floor: run_expected_min of an f-brief with expected-min 5 = 25; RUN_MAX_MIN=45 logged for a one-job run
PASS rules item: i1g.md has `changes: _ScoreBar · PlayerView.character` and `probe: docs/briefs/m16/identity1/probe-i1g.patch` (an optional PlayerView.character stub). brief-check first FAILed 41 files for broad items and then found `_ScoreBar` defined in score_row_parts.dart, outside allow: added to allow. brief-check and probe-deps on identity1 now pass (0 error files). i1g was NOT run.
Not done: the Sonnet driver dry-run of REHEARSAL's last rule item (the writer was this driver).
