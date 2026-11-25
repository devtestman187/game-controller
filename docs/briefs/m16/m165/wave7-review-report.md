## Summary

small fixes
Counts: must 1 · should 1 · could 4
1. The report has no review-rules part A self-check (c4-report.md:16).
2. Two `!` casts on a nullable mirror result with no proof on the line before (test:96-97).
3. The place() test compares place() with itself and cannot fail (test:85-93; the report says so too).

## Findings

- **must** docs/briefs/m16/m165/c4-report.md:16 The report has no part A self-check (every host setup, kept state, how the state combines, folder, stop, every look), which review-rules A requires of every job → add the six one-line answers, each with its test: the change is tests only, so host setups and kept state are "not affected" (mirrorPlace returns null unless `LayoutTarget.phones`, camera.dart:241), and the combination line names what is not tested.
- **should** packages/puzzle_game/test/hud_place_right_controls_test.dart:96 `mirrorWith(const [])!.hud.rect` and :97 `mirrorWith([spot])!` cast a nullable result with no line proving it is set (guidelines §2, type escapes) → take the free mirror into a local, `if (free == null) fail('no mirror');`, then read `free.hud.rect` without `!`.
- **could** packages/puzzle_game/test/hud_place_right_controls_test.dart:85-93 The test calls `place()` before and after a `mirrorWith` call; `place()` takes no hudRects, so it cannot fail unless its signature changes → keep it as the brief asks and name it as a guard against side effects, or drop it, as the report offers.
- **could** packages/puzzle_game/test/hud_place_right_controls_test.dart:86-87 `before` and `world` are the same `PuzzleCamera.place(...)` call written twice → use one variable for both.
- **could** packages/puzzle_game/test/hud_place_right_controls_test.dart:76 and :88 The board-centre-plus-hand rect is computed twice in the same group → extract one local helper in the group (for example `Rect overBoard()`) and use it in both tests.
- **could** docs/briefs/m16/m165/c4-report.md:68 The commit subject is 72 characters; the draft asks for under 72 → use `test: pin that mirror and place() ignore right-hand controls (B-044)` (68 characters).
- **could** docs/code-health.md:333 The B-044 "no test shows place() or the mirror fit unchanged by hudRects" item is still open in the file → close it when code-health.md is next edited (outside this job's allow).

## Decisions to confirm

- The six tests pass on the base and the brief exempts them from tests-first. They pin behaviour already in camera.dart:228-301, so they guard against a later regression and cannot show a fix; confirm that is what the owner wants.
- Every mirror assertion uses `phone169` (667 x 375) only, and the single control size `handPx` (40). The brief names this box; `iphone` and `phone15` are not covered.
- The worker asserts `free` is non-null instead of the brief's "null in both counts as identical". That is stricter and is correct, but it is a choice the brief did not ask for.
- The clock-area test (test:95-98) checks overlap only, not that the moved area stays in the box. The brief did not ask for it.

## Could not check

- The six tests passing, and `tools/mine.sh` output ("OK 6 tests"): I did not run the suite (read-only review); the report's claim stands unverified.
- Whether test:95-98 moves the area in the gap branch or the corner branch of `mirrorPlace` (camera.dart:270-284): I did not trace the layout, so I cannot say which branch the test exercises.
- Format and `dart analyze` results: not run. I checked that no line in the test file is over 120 columns (none is).
- The `docs/briefs/templates/COMMON.md` template the c4 brief names: not read, so its report-shape requirements are unchecked.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test: pin that mirror and place() ignore right-hand controls (B-044)

Review of m165 c4 (wave 7) only: no code change. Findings: the report needs
the part A self-check; two test casts need a proof on the line before; the
place() test cannot fail and duplicates a call. The subject is trimmed to fit
the 72-character limit.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

m165 wave7 review (c4): done — 1 must, 1 should, 4 could findings written; open: worker to add the part A self-check and fix the two test casts; the B-044 item in code-health.md:333 to close.

## Delete

- none
