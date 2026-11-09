job: M13 full review R1: the look and the games. toy_look, puzzle_game's view and painters, test_game's view and painters, game_kit. Read-only
stop: after the review. Change no file but the report, and fix nothing. Write only inside this job's folder.
read: docs/review-rules.md (parts A to D: the rules for this review) · docs/coding-guidelines.md · docs/design/look-and-sound.md (all, with the "Decided at step N" blocks) · docs/PRD-v2.md L1–L6 and T15 · docs/briefs/m13/STATUS.md and the step briefs and reports it lists
diff: `git diff d06f88a HEAD -- packages/toy_look packages/puzzle_game packages/test_game packages/game_kit` (M13 was cut from m12 at d06f88a). Read the tests as well as lib: a test that would still pass if its rule broke is a finding.

do:
1. **Part A:** for each M13 job in your area, is its self-check true?
2. **Part B** over the diff, B1–B8, focused on:
   - same picture everywhere: a painter's output depends only on the snapshot, the box and the ToyLook, and motion is worked out from snapshot time (design 7);
   - the shader and Canvas fallbacks drawing the same shapes and colours;
   - effects off and reduce-motion stopping every motion;
   - the rule boundary: no rules file imports toy_look, painting or material;
   - sizes from `_pxPerUnit` and the look's scale, not from screen pixels;
   - the contrast rules (4.5:1 text, 3:1 controls) in both palettes;
   - the shader programs' lifetime (no dispose, warm-up).
3. **The combination table (A3)** for every state your area touches (palette × effects × shader loaded or not × TV or phone sizes × reduce-motion). For each pair: "tested by <test name>", or "not tested" and what the code does.
4. **Part C:** only for your area, and only what would cost much more to fix later than now. Weigh it against M14 (docs/PRD-v2.md G1–G8: points pop-ups, the cat, the scoreboard, characters chosen by players).
5. **PRD coverage:** for L1, L2, L4 and L6, and T15's warning and hint glow, say whether each sentence is done, with the file or test that shows it, or what's missing.
6. Run `tools/review.sh` on the range and copy every FAIL.
format: docs/review-rules.md part D, at most 140 lines.
check:
report: docs/briefs/m13/m13-review-r1-report.md
allow: docs/briefs/m13/m13-review-r1-report.md
