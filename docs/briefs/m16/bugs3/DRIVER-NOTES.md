- 22:55 briefs b037 b038 wrap320 b036 b041 written; brief-check ok (WARN b041 4 packages); waves.txt holds wave 1 only; wave 2 line to add later: 'b036 b041'. next: commit, start runner
- 17:15 wave 1 STOPPED once (20 px floor, class c), hand-fixed score_row 0.625, committed 6e6f32a2 (b037) 58993e5a (b038) 2296ffd5 (wrap320); check.sh phone puzzle pass; tracker B-037/B-038 Fixed.
## Next action (17:20)
- run: docs/briefs/m16/bugs3, runner stopped (STOP.md removed), last run.log line: HAND-FIX b037 note
- done.txt: b037 b038 wrap320; parked: none
- do next: main session checks usage; then refresh b036.md (read the committed score_row.dart/arena_results.dart) and b041.md (puzzle_module.dart now pads on phones; allow has 4 packages, trim), append line `b036 b041` to waves.txt, brief-check, commit, start `WORKER=claude NO_PUSH=1 nohup bash tools/run-jobs.sh docs/briefs/m16/bugs3 > /dev/null 2>&1 &`. The run's review and full tools/check.sh at the end; B-036 note: banner not for Shape Race 'Left wins!' (follow-up). If it STOPs: read STOP.md failing list; pinned 20 px text tests (phone_fit_matrix_test) are the usual cause.
- open: connect_screen.dart:348 overflow (code-health); wrap320 Change width is an estimate; no tracker row for wrap320 (bugs2 B-035 follow-up, owner to check on device)
- calls so far: driver ~40, thumb-wait 1 agent (11 wait-run calls)
- 17:12 wave 2 briefs refreshed (b036 gets test_game showHud; b041 allow trimmed), brief-check ok, dry run ok. next: commit, start runner
