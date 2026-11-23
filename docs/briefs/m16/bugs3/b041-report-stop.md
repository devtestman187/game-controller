# B-041 report: a tablet plays Shape Race like a phone

Status: **stopped** at the fit check (brief step 1), before any lib change.
The brief's stop rule applies: "a fit problem at tablet sizes is a STOP for the report".

## Summary

- **Tests first (done):** `controller_app/test/tablet_shape_race_test.dart` (new file). It holds 4 tests:
  - one geometry test per iPad size (1366x1024, 1180x820, 1024x1366), with the stick pad;
  - two joined-tablet widget tests (1180x820 and 820x1180), which check `FrameView.wholeMatch` is false and `MatchView.camera` is the phone's own side;
  - one host-tablet widget test (1180x820), which checks the own player's `MatchView.camera` is the left side.
- **Run before the lib fix:** the three widget tests fail on the current code, as intended. Before the fix `FrameView.wholeMatch` is `true` (joined) and the host camera is the whole match. The fit test fails at 1180x820 only.
- **Fit (measured, the stop):** with `leftPadRects(box, mode: PadMode.sticks, mm: iPadPxPerMm)` and `PuzzleCamera.mirrorPlace(..., split: true, text: raceText(boat), padRects: pad)` on the boat puzzle:
  - 1366x1024: mirror present, own board larger than the mirror, mirror inside the box and clear of the pad. PASS.
  - 1024x1366: same checks. PASS.
  - **1180x820: `mirrorPlace` returns `null`.** The other side has no mirror at all on this size with the stick pad.
- **Why I stopped instead of making the wiring change:** 1180x820 is the owner's iPad landscape size. Dropping the tablet override (brief step 2) would make that tablet show only its own side, with no mirror of the other side. Today it shows the whole match. That is a regression on the owner's own device, so I did not ship it.
- **Not changed:** `host_overrides.dart`, `joined_view.dart`, `tablet_board_test.dart`, `host_own_player_test.dart`, `joined_view_test.dart`, `tablet_and_feedback_test.dart`, `docs/design/m12-opponent-mirror.md`. No pinned test asserted that a tablet draws both sides, so step 3 had nothing to fix. The solo-boat fit test in `tablet_board_test.dart` is unaffected and I did not touch it.

## Decisions

- Mirror test text uses `raceText` (the start-of-round HUD `You 0/n · Right 0/n`) as the mirror's measurement text. This is the same convention as `mirror_pad_test.dart`. The real HUD may differ a little in width, but a null at 1180x820 is well short of that margin. Not verified against the live HUD string.
- The joined-tablet widget test drives a real `shape_race` view (`viewStart` with `teams {test: left, other: right}`, `layout: phones`) and a `PuzzleMatch` snapshot. The player id `test` is the fake identity from `support/fakes.dart`.
- The host test uses the one-player `soloRound`, so it checks the camera only. A two-player host match needs a second joiner, and the join-screen flow for a second side was not traced in this job.
- `mine.sh` formatted the new test file once (churn revert ran for generated files only).

## Computed values

- Own board vs mirror width: asserted `own.width > mirror.width` and the same for height, at 1366x1024 and 1024x1366 (both pass). Exact numbers were not printed; the assertion is the relation.
- At 1180x820 the mirror is `null`, so no numbers exist for the mirror.
- No expectation in the new file uses a hard-coded pixel value; all are relations or `PuzzleCamera` constants (`mirrorGapPx`, `iPadPxPerMm`).

## Checks

- `tools/mine.sh` (run twice): format OK; analyze PASS after 3 fixes (unused import, two redundant arguments); tests FAIL with exactly the 4 intended tests:
  1. the mirror fit at 1180x820 (`Expected: not null, Actual: <null>`);
  2. joined 1180x820: `wholeMatch` expected false, was true;
  3. joined 820x1180: same;
  4. host 1180x820: camera expected `side(left)`, was `whole`.
- Test 2 and 3 never reached their camera assertion (the `wholeMatch` line failed first), so the camera check is unverified.
- `tools/check.sh` not run (the script runs it after me).

## Questions

1. **Owner decision needed (the stop):** at 1180x820 with the stick pad the other side's mirror does not fit, so dropping the tablet override would hide the other side on the owner's iPad. Options:
   a. keep the tablet override only at sizes where the mirror does not fit (a size rule in `host_overrides.dart`);
   b. let the mirror be smaller or move the stick pad at that size (a change in `packages/puzzle_game` camera code, outside this job's allow list);
   c. accept no mirror at 1180x820 (the other side is not shown there).
   I recommend (a) as the smallest change that keeps today's behaviour at 1180x820, or (b) if the owner wants the phone rule on every tablet.
2. Should the 1180x820 geometry test and the three widget tests stay red in the tree until the owner picks, or should they move to a follow-up job? They are the evidence of the stop; I left them red and did not weaken them.
3. Does the owner accept the stick-pad measurement at 1180x820 as the test case, or should the test also use the d-pad and gyro modes? The fresh-install tablet opens in stick mode, so I tested that one.

## Suggestions

- Once the owner picks an option, the joined-tablet and host tests should pass after the wiring change, and the rule 6 edit in `docs/design/m12-opponent-mirror.md` can follow (remove the tablet clause; note B-041, Nov 23).
- `party_host/test/puzzle_screen_test.dart:194` overrides `wholeMatchProvider` to `true`. It is outside this job's allow list and still valid after the provider stays.

## Commit message — a draft

Test: pin a tablet's Shape Race camera and mirror fit (B-041)

Adds tablet_shape_race_test.dart (tests first, B-041). The tablet
joined and host widget tests fail on the current code: a tablet draws the
whole match, not its own side. The fit test shows the other side's mirror
is null at 1180x820 with the stick pad, so the tablet override is not
dropped yet. The lib change waits for an owner decision (see report).

## Status row

B-041: stopped at the fit check; tests-first done (4 tests, 3 wiring red + 1 fit red at 1180x820); lib change not made; owner to pick how a tablet at 1180x820 shows the other side's mirror.

## Delete

- none
