# speed1 driver notes
- 11:07 STEP 0 baseline (tip 86237258, serial full check.sh, Defender exclusions on): All checks passed 670 s (real 11m11s). format 6, analyze 69, protocol 8, connection 16, metrics 6, kit 9, look 12, arena 34, puzzle 148, host 91, phone 67, tv 18, tools 186. (previous run 596 s)
- Item 4b (over-cap accept) already exists in run-wave.sh turn_cap (result 0 + report); sp4 only proves it with a test. fq6/fpad parked because they had no report.
- Item 6 done by hand, commit 0db2ac5b (flash.sh worker check = mine.sh only; MINE_TIMEOUT 300; flash-prompt-test 19 pass).
- Plan: wave 1 sp1 sp2 sp5; wave 2 sp3 sp4 sp6 (sp3 needs sp1+sp2, sp4 needs sp2).
- 11:50 wave1: sp1 committed by runner; sp2 (stray tmp file, result 4) and sp5 (43 turns vs cap 35, my brief cap too low: lesson 8) hand-applied via apply-job.sh, tests pass, committed ba35a997 3fdc97c3. class: other/limit. Restarting for wave 2.
- 12:35 wave2: sp4 sp6 committed by runner (f5965c0f 9cf192a9). sp3 parked (result 4, haiku went off-track after 1 turn; its code worked, test counts wrong): hand-fixed via apply-job.sh + test count fixes, no-git-key guard, failfast test CHECK_CACHE=0, release docs --no-cache; commit 3a15cabf. Restarting for run review.

## Timing table (this PC, 16 cores, Defender exclusions on; seconds)
| run | total | notes |
| --- | --- | --- |
| STEP 0 baseline, serial, tip 86237258 | 670 (real 671) | puzzle 148, host 91, phone 67, tools 186, analyze 69 |
| serial `--no-cache`, after speed1 | 737 (real 12m17) | analyze 11, puzzle 145, host 113, phone 70, tools 293 (tools suite grew: 4 new test scripts, check-cache-test about 250 s alone) |
| `-j 4`, cache cold | 493 (real 8m13) | puzzle 332, host 257 FAIL (live_stats_unmarked_test, passes serial), phone 216, tools 356; CPU/disk contention, no 4x scaling |
| `-j 4`, cache warm, only host rerun (the retry case) | 125 | 10 CACHED, host 92 alone |
| runner-style affected-only, toy_look change, `-j 4` | 259 (real 4m20) | ran kit look arena puzzle host phone tv; skipped protocol connection metrics tools |
Wave 1 wall: 11:22-11:40 (18 min incl. combined check 10 min); wave 2: 11:44-12:13 (29 min). Check share still large; the affected-only combined check is not yet proven in a real runner wave (sp4 landed in wave 2).
Lesson candidates: (1) a hand-fix brief cap: `turns: 35` too low for a tools job with a new test file (sp5 43, sp4 47): use 60 (rule 8 already says so, I wrote 35 for sp5/sp6); (2) a test counting stub calls must say whether format and analyze are included: run with wanted names or count `ran` only; (3) a cache or parallel feature needs a test that fails when the feature is off (five check-cache cases passed without a cache).
Hand-fixes: sp2 (stray tmp file, result 4), sp5 (turn cap), sp3 (Haiku ended after 1 turn, test counts, no-git key guard). Ladder level 4 for sp3 (my own edits about 25 lines), level 3 for sp2/sp5 (apply-job only).
