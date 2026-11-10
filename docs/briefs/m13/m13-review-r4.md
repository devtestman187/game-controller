job: M13 closing review R4: everything since the R1–R3 reviews (the device-test fixes s9–s22 and the puzzle kit), before M13 closes and M14 starts. Read-only
stop: after the review. Change no file but the report, and fix nothing. Write only inside this job's folder.
read: docs/review-rules.md (parts A to D) · docs/coding-guidelines.md · docs/design/look-and-sound.md (all, with the "Decided at …" blocks) · docs/briefs/m13/STATUS.md · every brief and report in docs/briefs/m13 from s9 to s22 (s9, s10–s13, s14, s15, s15b, s16, s17, s18, s19, s19b, s20, s21, s22), each with its "Claude's review" · docs/PRD-v2.md M14 (G1–G5, G9) · docs/puzzles.md
diff: `git diff 60d148e HEAD` (60d148e is where R1–R3 were written; ignore tv_test_app/windows/flutter/generated_*, assets/audio/*.ogg, docs/design/*.png, tools/audio/final). Read the tests as well as lib: a test that would still pass if its rule broke is a finding.

do:
1. **Part A:** for each job s9–s22, is its self-check still true at HEAD (a later job may have broken an earlier one's rule)? One line each.
2. **Part B** over the diff, B1–B9, focused on:
   - the round music (`HostMusic`, `MusicLoop.forRound`, `RoundPhase`): start at "go", pause on every hold (pause menu, host away, a phone the round waits for), the 300 ms fade at results, the 120 ms cross-fade at the same share, Play again and Rematch, an app hidden mid-round, Mute and Music 0 %, a joined phone never playing it, the TV versus a host phone;
   - the stale view end (`endView(end, of:)`): every caller passes the start it ended, and no path ends a view a newer start replaced; the fakes match the server;
   - the worker's stand point and carry side (s14, worker_frames/worker_moments): a snapshot that repeats the game time, a piece dropped and picked up in one frame;
   - the board painter: since s20 a locked piece takes the nearest outline of its kind; look for any other place that finds a piece's target, hint or slot by position alone (mirror painter, the hint glow, the ✓ placement, the split screen);
   - the sky behind the game (s19b `toyStillSkyAbove`) with s22's stars: is the marker true wherever a `ToyBackground` is behind a game, on the TV, a host phone and a joined phone, and does anything draw the stars twice or not at all;
   - the host focus (s21): `HostFocusScope`'s Theme, the ring on every screen, a thumb then a pad press;
   - the puzzle kit: the rule book against the tests it should replace (the tray overlap in `rules_test.dart` and the phone sizes in `controller_app/test/puzzle_size_test.dart` are still outside it: `tools/puzzle.sh check` passed a sun those failed), the schema against the parser, `tools/puzzle.sh new` on a fresh clone;
   - limits: every file over 400 lines and function over 60 in the diff (`tools/audio/pop_kit.dart` is known at 663).
3. **The combination table (A3)** for the round music (TV host / phone host / joined × playing / paused / away / results / Play again × Mute / Music 0 %) and the sky (Sunny / Night × effects on / off × shader / fallback × a game behind or not): "tested by <test name>", or "not tested" and what the code does.
4. **Part C**, only what would cost much more to fix later than now, weighed against M14: points and the cat in Shape Race's snapshot (G1, G3), the night's scoreboard between rounds with its own music hold (G2), the Arena's Bumper Round with its own sounds and round music at three tempos (G9, docs/briefs/m14/a1-arena-sounds.md), results on joined phones.
5. Run `tools/review.sh` on the range and copy every FAIL.
format: docs/review-rules.md part D, at most 160 lines. Findings most severe first; each `must` with the test that would show it.
check:
report: docs/briefs/m13/m13-review-r4-report.md
allow: docs/briefs/m13/m13-review-r4-report.md
