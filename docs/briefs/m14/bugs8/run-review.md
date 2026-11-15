job: the run's review (read-only): everything committed in this run, read as one change, against the coding guidelines and review rules; one findings list for Claude
pub: no
stop: after it.
read: docs/briefs/m14/bugs8/STATUS.md if it exists · every `docs/briefs/m14/bugs8/*-review-report.md` (the per-job reviews) · docs/briefs/m14/bugs8/run-findings.md if it exists · the Summary block of every `docs/briefs/m14/bugs8/*-report.md` · docs/coding-guidelines.md · docs/review-rules.md · the whole change: `git diff fa3bc845df3488c7bef86af1ca3db2be26183443..11a9619d81bef0436e8746359f1983b8c4ae6c14` if the command is allowed, otherwise these files whole: docs/code-health.md docs/design/puzzles/dragon.png docs/design/puzzles/tower.png docs/design/puzzles/tractor.png packages/party_host/lib/src/best_times.dart packages/party_host/test/best_times_medium_clear_test.dart packages/puzzle_game/lib/src/tray.dart packages/puzzle_game/puzzles/dragon.json packages/puzzle_game/puzzles/tower.json packages/puzzle_game/puzzles/tractor.json packages/puzzle_game/test/hard_swap_test.dart packages/puzzle_game/test/split_layout_test.dart packages/puzzle_game/test/tray_edge_fit_test.dart packages/puzzle_game/test/tray_packing_test.dart 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

Claude (the designer) reads only your Summary first, verifies the findings it acts on, and writes ONE fix brief from your list. So: merge, de-duplicate and rank; a finding Claude cannot find in the file is worse than none.
1. **Carry over** every finding of the per-job reviews and of run-findings.md that still holds in the final code (a later job may have fixed it: check, and drop it if so).
2. **Across jobs**: what no single-job review could see: two jobs solving the same thing twice, names or concepts that disagree between jobs, a document one job wrote that a later job made wrong, files that grew past 300 lines over several jobs, dead code left by a replaced approach, a rule in docs/review-rules.md that holds per job but not for the whole.
3. **Open questions**: collect every "Questions", "Not sure about" and "Blocked" entry from the jobs' reports that nobody answered, one line each, with the safest answer you would pick.
4. **Unverified fixes**: list every fix whose cause was not measured or reproduced (a report saying so, or a fix by reasoning alone): the batch must mark these "Fixed, unverified: needs device check".
5. **Numbers**: where reports give measurements, list the ones that miss a target stated in the briefs or in STATUS.md.

in the report, in this order and nothing else:
- `## Summary` (at most 20 lines): the verdict (`clean`, `one fix batch` or `needs Claude's design`), counts by severity, the five findings that matter most, and the questions only the owner can answer.
- `## Findings`: one bullet each, most severe first: `- **<must|should|could>** <file>:<line> <what is wrong, in one sentence> → <the fix, in one sentence> (from: <job or "across jobs">)`.
- `## Open questions`: one line each with the suggested answer.
- `## Numbers against targets`.
- `## Could not check`.
rules: change nothing but your report · no praise, no retelling of what was built · every finding names a file and line you have read · install nothing · leave no scratch file behind
allow: docs/briefs/m14/bugs8/REVIEW.md
report: docs/briefs/m14/bugs8/REVIEW.md
