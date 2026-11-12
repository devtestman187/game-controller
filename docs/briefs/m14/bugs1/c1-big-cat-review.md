job: review of job c1-big-cat (read-only): check what it committed against the coding guidelines, the review rules and its own brief; write findings only
pub: no
stop: after it.
read: docs/briefs/m14/bugs1/c1-big-cat.md (the brief: what was asked) · docs/briefs/m14/bugs1/c1-big-cat-report.md (what the worker says it did) · docs/coding-guidelines.md · docs/review-rules.md · docs/briefs/m14/bugs1/run-findings.md if it exists · the change itself: `git diff 1c296ec723d2a90a0c3da61096038eeda679e115..415dd0e7c0195e51fa92846a077c1a2e6f9aa72a` if the command is allowed, otherwise read these files whole: docs/briefs/m14/bugs1/c1-big-cat-report.md docs/design/m14-cat-peek-night.png docs/design/m14-cat-peek-sunny.png docs/design/m14-cat-swat-night.png docs/design/m14-cat-swat-sunny.png packages/puzzle_game/lib/puzzle_game.dart packages/puzzle_game/lib/src/cat_head.dart packages/puzzle_game/lib/src/cat_moments.dart packages/puzzle_game/lib/src/cat_paint.dart packages/puzzle_game/lib/src/cat_paw.dart packages/puzzle_game/lib/src/cat_pose.dart packages/puzzle_game/lib/src/cat_view.dart packages/puzzle_game/lib/src/match_painter.dart packages/puzzle_game/lib/src/mirror_painter.dart packages/puzzle_game/lib/src/puzzle_painter.dart packages/puzzle_game/lib/src/view.dart packages/puzzle_game/test/cat_peek_test.dart packages/puzzle_game/test/cat_pictures_test.dart packages/puzzle_game/test/cat_swat_test.dart 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

You are the second pair of eyes on another worker's job. Claude (the designer) will read only your Summary, then verify the findings it acts on, so be exact and short: a finding Claude cannot find in the file is worse than none.
1. **Guidelines** (docs/coding-guidelines.md): go through the changed files against each rule: size and function length, names, layers and platform rules, error handling, leftovers (prints, TODOs, commented-out code, scratch files), magic numbers, clocks and timers, text and strings.
2. **Review rules** (docs/review-rules.md, parts A and B): every host setup; when kept state starts and ends; how a new state combines with the others (pause, party night, reconnect); staying in the job's folder; stopping rather than overstepping. Check the report's self-check lines against the code: is each claim true?
3. **The brief**: is every numbered item done? Is anything built that was not asked for? Is every "Decisions" entry safe, and is any decision hidden (made but not listed)?
4. **Tests**: does each new behaviour have a test that would fail without it? Any test that asserts nothing, repeats another, or tests the mock? Entries about this job in run-findings.md ("passes on the old code") count as findings.
5. **Docs**: do the documents the job touched say what the code does?

in the report, in this order and nothing else:
- `## Summary` (at most 12 lines): one line with the verdict (`clean`, `small fixes` or `needs Claude`), then the counts by severity, then the three findings that matter most.
- `## Findings`: one bullet each, most severe first, in exactly this shape: `- **<must|should|could>** <file>:<line> <what is wrong, in one sentence> → <the fix, in one sentence>`.
- `## Decisions to confirm`: the job's decisions that Claude or the owner should look at, one line each with why.
- `## Could not check`.
rules: change nothing but your report · no praise, no summary of what the job did · every finding names a file and line you have read · install nothing · leave no scratch file behind
allow: docs/briefs/m14/bugs1/c1-big-cat-review-report.md
report: docs/briefs/m14/bugs1/c1-big-cat-review-report.md
