## Summary

Verdict: `small fixes`.
- must 1, should 1, could 3.
- The runner logged the new cache-state test as passing on the old code (the one thing this brief's tests-first line already exempted); it needs Claude's confirmation, not a rewrite.
- The report's self-check A2 says the cache "ends on `dispose`", but `BoardCache` has no `dispose` and neither view `State` overrides one.
- The two bare numbers the report raises as its own questions (board_hud's `_barHeight / 4`, phone_hud's `/ 1000`) sit in files this job touched and the library now has a constant for each.

## Findings

- **must** packages/puzzle_game/test/board_cache_state_test.dart:37 `run-findings.md` records this test as passing on the old code (the job's base commit), so on the tree it proves nothing about the key's hint, ready or glow fields → keep the brief's tests-first exemption, but have Claude redo the failure check (the worker's key-field edit was uncommitted) before the test counts as proof.
- **should** docs/briefs/m14/cleanup1/c2-board-report.md:67 Self-check A2 says the cache "ends on `dispose`", but view.dart:68 has no `dispose` override and board_cache.dart:95 has no `dispose` method either → say the cache lives as long as the view's `State` and its pictures are left to the collector, or add the dispose the line promises.
- **could** packages/puzzle_game/lib/src/board_hud.dart:85 The board's bar still insets its fill with a bare `_barHeight / 4` while the same inset is now `_barFillInsetShare` (phone_hud.dart:76, same library) → use `_barHeight * _barFillInsetShare`.
- **could** packages/puzzle_game/lib/src/phone_hud.dart:65 `_clock` still divides by a bare `1000` while the same library now has `_msPerSecond` (board_hud.dart:17) → use `_msPerSecond`, as board_hud.dart's clock does.
- **could** packages/puzzle_game/test/board_cache_state_test.dart:37 The test's body runs lines 38-99 (62 lines), over the brief's 60-line function limit → move the `draw` closure and the snapshot setup to top-level helpers in the same file.

## Decisions to confirm

- "One cache, a painter per frame" instead of the brief's "one cached painter": safe, since `PuzzlePainter` holds its snapshot (puzzle_painter.dart:35), but it is the test's one deviation from the brief's words.
- `_barFillInsetShare = 0.25` used as `track.height * share` rather than `track.height / 4`: exactly the same value (0.25 is exact in both binary and decimal), so no behaviour change.
- Both `/ 1000`s of board_hud.dart changed though the brief named only line 23: same file, same conversion, safe.
- The glow's age in the key (the report's suggestion 2: about 150 recordings in the celebration's 2500 ms): the report calls it no regression against the old every-frame rebuild, which matches celebration.dart:29 and :97; the change it suggests is a design one and belongs in a brief.

## Could not check

- The committed diff and its boundaries: `git diff 3fcbb8c…94fa336` and `git -C` were refused in this sandbox, so I compared the named files' current content with the report and could not see whether any file the report does not name changed.
- The worker's temporary removal of `StaticBoardKey`'s hint, ready and glow fields and the failure it reports (edit restored, not committed).
- The claim "the `puzzle` suite, 403 tests pass": I ran no suite; run-findings.md records no suite failure.
- Self-check A4's `git status` claim, for the same git reason.

## Commit message

Review the c2-board test, annotation and named constants

Checked c2-board against the coding guidelines, the review rules and its
brief: the four items are in and nothing changes behaviour, and the new
cache-state test would fail without the key's hint, ready and glow
fields (by the worker's own check, not committed). Findings: the
runner's log shows the test passing on the old code, which the brief
exempted; the report's A2 line claims a dispose the cache does not have;
and two bare numbers remain in the HUD files this job touched.

## Status row

- M14 cleanup1 c2 reviewed: no blockers, the four brief items in, no behaviour change; open: 1 must (the runner's "passes on the old code", brief-exempted) and 4 should/could nits for a later job.

## Delete

- none
