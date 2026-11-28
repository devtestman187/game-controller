## Summary

needs Claude
Counts: must 0 · should 2 · could 1
1. f1c stopped with no code change, on a real allow-list gap: `_JoinBody` and `_Sides` live in join_screen_widgets.dart, which f1c.md does not allow. The worker's claim is true (checked at join_screen_widgets.dart:162-195 and join_screen.dart:352).
2. f1c skipped work that did not depend on the gap: the maxPopupsFor change in points.dart and puzzle_points.dart, and its points test. The report does not say why.
3. The report has no `## Summary` and no `## Hand-over`, which COMMON.md requires.

## Findings

- **should** docs/briefs/m17/race1a/f1c-report.md:1 The report has no `## Summary` block and no `## Hand-over`, both required by the template (docs/briefs/templates/COMMON.md:6), and run-findings.md records this → add a `## Summary` (at most 30 lines, within the first 40) and a `## Hand-over` section.
- **should** packages/puzzle_game/lib/src/puzzle_points.dart:32 The `_award` cap still uses `PuzzlePoints.maxPopups` alone, and the job did not touch it although item 2 does not depend on join_screen_widgets.dart → make the change in item 2 (cap by `PuzzlePoints.maxPopupsFor(settings.maxPerSide)`) or write in the report why it was left out.
- **could** docs/briefs/m17/race1a/f1c-report.md:5 The "Why" section says the whole job is blocked, but it does not say which items (1 panel `seats` parameter, 2 points, 3 tests) depend on the blocker → list each item as done, blocked or independent, so Claude can split the job.

## Decisions to confirm

- Adding join_screen_widgets.dart to the allow list (a `seats` field on `_JoinBody`, passed to `_Sides`), or choosing one of the two workarounds the worker lists. The worker was right to stop on this: it changes which files the job may touch.
- The brief names `JoinSidePanel`, but the classes are `_Sides` (join_side_panel.dart:34) and `_SidePanel` (join_side_panel.dart:83), both private. The worker's assumption (put `seats` on both) is reasonable; confirm it.
- Whether the job should be split: item 2 (points) and its test can run now, and the panel `seats` parameter with default 2 can land before the wiring.

## Could not check

- No tests or analyzer were run: the job changed no code, and the review only read files and the git diff of the report.
- The brief's line numbers are close but not exact (join_screen.dart:55-60 is at :57-59). Not a finding against the job.
