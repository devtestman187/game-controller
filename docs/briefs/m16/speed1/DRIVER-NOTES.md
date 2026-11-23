# speed1 driver notes
- 11:07 STEP 0 baseline (tip 86237258, serial full check.sh, Defender exclusions on): All checks passed 670 s (real 11m11s). format 6, analyze 69, protocol 8, connection 16, metrics 6, kit 9, look 12, arena 34, puzzle 148, host 91, phone 67, tv 18, tools 186. (previous run 596 s)
- Item 4b (over-cap accept) already exists in run-wave.sh turn_cap (result 0 + report); sp4 only proves it with a test. fq6/fpad parked because they had no report.
- Item 6 done by hand, commit 0db2ac5b (flash.sh worker check = mine.sh only; MINE_TIMEOUT 300; flash-prompt-test 19 pass).
- Plan: wave 1 sp1 sp2 sp5; wave 2 sp3 sp4 sp6 (sp3 needs sp1+sp2, sp4 needs sp2).
- 11:50 wave1: sp1 committed by runner; sp2 (stray tmp file, result 4) and sp5 (43 turns vs cap 35, my brief cap too low: lesson 8) hand-applied via apply-job.sh, tests pass, committed ba35a997 3fdc97c3. class: other/limit. Restarting for wave 2.
- 12:35 wave2: sp4 sp6 committed by runner (f5965c0f 9cf192a9). sp3 parked (result 4, haiku went off-track after 1 turn; its code worked, test counts wrong): hand-fixed via apply-job.sh + test count fixes, no-git-key guard, failfast test CHECK_CACHE=0, release docs --no-cache; commit 3a15cabf. Restarting for run review.
