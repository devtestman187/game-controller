# seatfit report (Nov 27)
Inline batch (no runner, no worker jobs; driver wrote it directly). Range 1fa286c9..HEAD, code tip be5a4c0d.
- Job 1: see DIAGNOSIS.md. Waiting-phones line _NotJoined (join_screen_widgets.dart:35-51, added at :201 only when watching is non-empty) takes the height; the side row floor of 38 px (join_side_panel.dart:122-130) leaves 4 seats needing 196 px.
- Job 2: join_side_panel.dart: FittedBox scaleDown of the side card when seats need more than the room. ToyCard untouched. Tap target stays the whole card (scale about 0.97 at worst measured room).
- Job 3: test/join_side_fit_test.dart, 12 cases (1-4 a side x 3 sizes), failed 12/12 on the old code (5-6 px RenderFlex overflow at toy_card.dart:129), passes after. Only the menu look is covered.
- Job 4: badge not clipped (rect and text inside the screen at all 3 sizes); the red stripe is Flutter's DEBUG banner from the test harness MaterialApp. One-line fix in test/support/host_harness.dart (shipped apps already hide it). Nothing logged in code-health.
- Job 5: docs/code-health.md (pausewire notes, line 363) and STATUS.md known-gap line. Notes location found by grep, no Haiku helper.
- Notes: owner's 36 px overflow did not reproduce (5-6 px); it needs a longer waiting line (names wrapping), and the fix covers it by scaling. The _NotJoined line still has no maxLines: minor, in code-health? not added.
- check.sh: All checks passed (see run.log). Findings: none open. Fixed, unverified on a device: the lobby with phones waiting at 4 a side (please check).
- Proposed lessons: 0. Calls: driver about 25, no waiters. Release notes: unchanged (no tester-visible text beyond "4 a side lobby no longer overflows on small screens").
## proc-sweep
proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
no background command of mine is still running

## Verify round (fixes after the independent verify)
- run.log now exists with the `full check:` line (batch-close.sh --run-check): `tail -1 run.log`. Code tip 4a486954.
- REVIEW.md written (tools/review.sh: 0 fail, 1 note).
- Real scale the side card gets from the FittedBox, measured at every lobby stage (nobody joined, after each join, settled) in join_side_fit_test.dart. The pre-fix overflow was transient (the waiting line wrapping while many phones wait), so the settled state alone shows scale 1.0.
  - 640x360: 0.899 (1-4 a side). 800x360: 0.939 (1-3 a side), 0.894 (4 a side, nine phones waiting). 960x540: 0.899. Host phone plays (own player, 640x360): 1.0.
  - Min 0.894, max 1.0; none below 0.75, so no design question. The test fails below 0.84 (lowest measured minus 0.05, rounded down).
- The test file's first version missed the transient stage; the new one covers it and the host-phone variant (13 cases).
