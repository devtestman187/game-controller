# seatfit review (Nov 27)
Range 1fa286c9..HEAD. `bash tools/review.sh --base 1fa286c9`: 0 fail, 1 note.
- NOTE size join_side_panel.dart 321 lines (lib limit 400, aim 300): minor, closed: nothing to do now; code-health not needed (the file was 307 before).
- Verifier finding "FittedBox scale-down has no floor": verified at join_side_panel.dart:159-172. Measured real scale (test join_side_fit_test.dart, every lobby stage, 13 cases): lowest 0.894 (4 a side, 800x360, nine phones waiting), highest 1.0; all 0.894-0.94 at 640x360 and 800x360, 0.899 at 960x540, 1.0 for the host-phone case. None is below 0.75, so no design question. A test assertion pins it at 0.84 or better. closed (fixed in 7805684f).
- Finding: the first test only checked the settled state; the overflow was transient (long waiting line before the last phone joined). fixed: the test now checks every stage.
- Finding: _NotJoined has no maxLines, so many waiting names wrap and push the sides' room down. minor, code-health.
- No must findings open.
