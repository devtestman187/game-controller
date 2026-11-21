# Wave 4 (S9m) review — the phone-fit matrix

## Summary
**needs Claude** — 1 must, 1 should, 2 could.
- must: every case is drawn in a full-device `HostFrame`, but the controller app's host screens sit in `HostFrameGate` under a 52 px bar, so the 640x360 phone host scales 0.57037 and its 20 frame px type is 11.41 dp, not the 13.33 dp the report claims.
- should: the ways-on check only requires one listed key to be found, so a screen that loses one of several buttons (e.g. `joinBack`) still passes the gate.
- could: the name-fit check opens the night's final scores, not the between-rounds scoreboard the brief names.
- Checks: `phone_fit_matrix_test` 81 pass on the tip; `dart format --set-exit-if-changed` and `dart analyze` clean on the two new files; the runner log says the job's `format analyze host` passed (run.log:122). Not run: the full host suite.

## Findings
- **must** packages/party_host/test/support/phone_fit_matrix_support.dart:141 draws every case in a full-device `HostFrame`, but the controller app puts the host subtree in `HostFrameGate` (controller_app/lib/src/host/host_frame_gate.dart:42) below `topBarHeightPx` 52, whose frame is 1122.1x540 (scale 0.57037) at 640x360 and 1349.2x540 (0.63148) at 852x393 — so the phone host's 20 frame px type is 11.41 dp and 12.63 dp, below the owner's 13 dp floor and not the 13.33 dp s9m-report.md:17 reports with "both host apps' hostFrameBuilder" (s9m-report.md:8; only tv_test_app uses it) → measure the gate's bar-reduced room (or add a phone-host case per size) and state in the report which frame the five sizes are.
- **should** packages/party_host/test/phone_fit_matrix_test.dart:125-133 only requires one of a screen's listed keys to be found and then checks the found ones, so a screen that loses one of two buttons keeps the gate green while the report's table says its ways on are verified → assert each screen's required key(s) present, with the puzzle results' `nextPuzzle`/`rematch`/`playAgain`/`replay` as one-of groups.
- **could** packages/party_host/test/phone_fit_matrix_test.dart:50 runs the name-fit check on `night-final` (final scores), not the between-rounds scoreboard the brief names (s9m.md:8) → use the mid-night scoreboard or say in the report that it shares `ScoreRow` and the final's 32 px winner row is the stricter case.
- **could** packages/party_host/test/support/phone_fit_matrix_support.dart:227-346 copies the option-C test's openers, `playRounds` and `_roundStats` (phone_fit_support.dart:119-190) a third time, so a change to the night setup must be made in three places → note it as tech debt, or let a later brief move the openers into the shared support (this brief forbade editing it).

## Decisions to confirm
- The frame the gate measures (must above): keep the full-device frame the owner's "20 frame px = 13.33 dp" assumes, or measure the phone host's gate where the same type is 11.41 dp at 640x360; the answer decides whether S9m is green for "Play on this phone" and "Show on this device".
- The `PHONE_FIT` switch (the report's question 1): the writer accepts `--dart-define=PHONE_FIT=true` as well as `PHONE_FIT=1` (test:142); it still writes only after all 80 cases, so accept the extra switch or ask for the variable only.
- The two clipping observations (the report's questions 2 and 3): the six-player start-card names (84 px slots) and "Bumper Round"/"Change teams" are recorded in s9-matrix.json's `clipped` list but asserted nowhere; keep them as findings or make clipping a gate criterion.
- The ways-on gap (should above): decide whether the final gate must fail when one of a screen's named buttons is missing.
- The 6-player puzzle-results case joins 4 of 6 (2v2, the most Shape Race seats) as the brief allows; every night screen and the Arena take six.

## Could not check
- The phone host's measured dp: computed from `HostFrameGate`'s room and `topBarHeightPx`, not run; a `party_host` test cannot import `controller_app`.
- The full `tools/check.sh host` and the whole party_host suite: I ran only `test/phone_fit_matrix_test.dart`, `dart format` and `dart analyze` on the two new files.
- The rest of s9-matrix.json beyond the records I sampled (80 cases, 70 without scrollables, 10 picker guard lists at extent 0, 0 errors, 0 off-screen found buttons, 40/30/10 at 20/22/23.4 frame px); the 4-player 126 px start slot is not in the file and I did not re-measure it.
- No run-findings.md exists. run.log:123's "fails on the old code" is only the new support file not being copied (run-jobs.sh:183 copies the test file alone) while the lib is unchanged, so it is not evidence either way; the brief exempts a measurement test over built code, so I count no finding.

## Commit message

Review wave4 S9m: the matrix measures a full-device frame

Reviewed S9m against its brief, the guidelines and review-rules; all 81
tests pass and the report's numbers match s9-matrix.json. Findings: the
matrix draws a full-device HostFrame, not the phone host's bar-reduced
frame (20 frame px is 11.41 dp at 640x360, below the 13 dp floor); the
ways-on check passes when one listed button is missing; and the name-fit
check runs on the final scores rather than the scoreboard.

## Status row

S9m reviewed (wave 4): the phone-fit matrix is in, 81 tests pass and its numbers match s9-matrix.json — open: it measures a full-device frame, not the phone host's bar-reduced frame (11.41 dp at 640x360, below the 13 dp floor), the ways-on check misses a lost button, and the name-fit check runs on the final scores.

## Delete

- none
