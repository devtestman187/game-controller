# m165 wave2 review: c0a (B-044 contract 1 of 2, commit 296b4ffd)

## Summary

- Verdict: small fixes
- Counts: must 0, should 3, could 0
- 1. The mirror path does not get `hudRects`: `mirrorPlace` computes its own HUD with `hudPlace` and the decision list does not say so (packages/puzzle_game/lib/src/camera.dart:255).
- 2. `hudPlace` now takes 8 parameters against the 5 the guidelines allow (packages/puzzle_game/lib/src/camera.dart:299-308).
- 3. The commit subject has a literal `Subject: ` prefix copied from the report draft (296b4ffd; docs/briefs/m16/m165/c0a-report.md:67).

## Findings

- **should** packages/puzzle_game/lib/src/camera.dart:255 `mirrorPlace` calls `hudPlace` without `hudRects` (also camera.dart:270, match_view.dart:163, phone_hud.dart:103), so once b1 sets `hudRects` the mirror-case HUD and its gap fit (camera.dart:274) still ignore them; the report lists only the phone_hud mirror branch as a decision → list the mirror path as open for b1 in the status row, or thread `hudRects` through `mirrorPlace` in b1.
- **should** packages/puzzle_game/lib/src/camera.dart:299 `hudPlace` has 8 parameters (layout, camera, box, text, mirror, padRects, split, hudRects) against the 5 the guidelines allow; the job added the 8th (it had 7) → record it as an accepted exception or bundle the placement inputs into a value object in b1.
- **should** docs/briefs/m16/m165/c0a-report.md:67 the draft subject starts `Subject: `, and that label is in the commit: `git log -1 --format=%s 296b4ffd` prints `Subject: puzzle_game: pass hudRects through the draw chain to hudPlace (B-044)` → drop the `Subject: ` prefix from the subject (history rewrite, so Claude or the owner decides).

## Decisions to confirm

- The mirror path (camera.dart:255 and :270, match_view.dart:163, phone_hud.dart:103) keeps padRects-only: the brief said to pass `hudRects` "the same way" next to every `padRects`, and the report's decision covers only the phone_hud mirror branch. Why: this is the gap b1 will hit first.
- `puzzle_module.dart:148-150` builds the `padRects` the views get and does not pass `hudRects` (outside `allow:`). Why: the default `const []` means no host changes until b1.
- `hudPlace` at 8 parameters (camera.dart:299). Why: the guideline cap is 5; the report asks the same as Question 1.
- The report carries the three closing sections the task asks for (Commit message, Status row, Delete) in addition to the brief's four. Why: the brief says "nothing else", the task says to end with those three; both are followed.

## Could not check

- Test results: I did not run the tests (read-only job). I verified that run.log:77 records `hud_rects_plumbing_test.dart fails on the old code`, but I did not find the `mine.sh` output (`OK 14 tests`, `20 tests`, `2 undefined_named_parameter`) in run.log, so those counts are the report's claim only.
- Analyzer output for the changed files: not in run.log; not re-run.
- `docs/briefs/m16/m165/run-findings.md` does not exist, so there are no "passes on the old code" entries about c0a.
- Checked and true: the line counts in c0a-report.md (camera 359, phone_hud 233, match_painter 241, match_view 220, play_view 224); `iphone` is `Size(852, 393)` (packages/puzzle_game/test/support/mirror_helpers.dart:19); no lines over 120 columns in the changed hunks; no print, TODO or BISECT in the changed files; the diff touches only the allowed files.
- Whether the mirror path should take `hudRects` now or in b1 is a design question for Claude; I have not judged it.

## Commit message — a draft

Review of m165 wave2 c0a: findings only, no code change

Record the review of commit 296b4ffd (puzzle_game: hudRects through the draw chain).
Findings: the mirror path (mirrorPlace, match_view, phone_hud) still ignores
hudRects and the decision list covers only one branch; hudPlace takes 8
parameters against the limit of 5; the commit subject carries a "Subject: " prefix.
No code, test or allowed document changed.

## Status row

m165 wave2 review of c0a: done, verdict small fixes (0 must, 3 should). Open: decide the mirror-path gap for b1, the 8-parameter hudPlace, and the "Subject: " prefix on 296b4ffd.

## Delete

- none
