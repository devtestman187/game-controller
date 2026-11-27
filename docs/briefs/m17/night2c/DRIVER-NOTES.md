- 09:45 wave1: v1a, t1 committed; c1 parked at turn cap (class capability). next: ladder 2, turns 50, restart
- 10:15 wave1 done: v1a 645cfbca, t1 fb20f723, c1 a8ebf10a (c1 needed ladder 2, class capability: 36 turns over cap 35). Wave 1 verdicts in REVIEW-VERDICTS.md (f1 added to wave 3). The c1 wave review (wave1-c1-review.md) has no report: cover c1 in the end-of-run review.
- Base check waited on the side line's heavy lock and hit RUN_BASE_CHECK_MAX_MIN=5: restart with RUN_BASE_CHECK_MAX_MIN=30.

## Next action (10:16)
- run: docs/briefs/m17/night2c, tip a29fe54a (+ commit of this note), runner stopped (PAUSED after wave 1), last run.log line: "STOPPED: PAUSED after wave 1"
- done.txt: v1a t1 c1; parked/dropped: none. Epoch for agent-cost: 1795792539 (batch start about 09:15)
- do next: `date +%s` then `RUN_BASE_CHECK_MAX_MIN=30 RUN_PAUSE_AFTER_WAVE=1 MAX_JOBS=2 WORKER=claude NO_PUSH=1 nohup bash tools/run-jobs.sh docs/briefs/m17/night2c > /dev/null 2>&1 &` and thumb-wait with since=<epoch>. Waves left: 2 (v2 t2 d1), 3 (v1b v1c f1). After each wave: verdict the review in REVIEW-VERDICTS.md.
- open: wave 2 v2 touches 21 test files (sonnet, 80 turns); v1c is the big UI job. At the end: REPORT.md (batch-report.sh, job-metrics, agent-cost --since 1795792539 --agents --line, proc-sweep), RELEASE-NOTES.md final (draft in the folder, 476 chars), batch-close.sh --run-check, STATUS Resume line, tracker none. Timing default for the Vote is NOT owner-confirmed: say so. c2 finding (no code): the host phone's own player gets nothing at a build stop: shop_demo_screen.dart:76-79 keeps only players with !p.local && !p.simulated; the only ChoiceRound is built at shop_demo_screen.dart:90 (round) with OldPhoneChoices at :~104; the host device has no choices UI path.
- compat note: the owner's brief had "hazard rule" in driver-kit; none found, d1 adds the compat policy bullet instead.
- calls so far: driver ~28, waiters 4 (about 35 polls)
