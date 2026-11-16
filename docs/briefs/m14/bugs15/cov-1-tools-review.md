job: review of job cov-1-tools (read-only): check what it committed against the coding guidelines, the review rules and its own brief; write findings only
pub: no
stop: after it.
read: docs/briefs/m14/bugs15/cov-1-tools.md (the brief: what was asked) · docs/briefs/m14/bugs15/cov-1-tools-report.md (what the worker says it did) · docs/coding-guidelines.md · docs/review-rules.md · docs/briefs/m14/bugs15/run-findings.md if it exists · the change itself: `git diff 9a9a092c5388c1113e290e1cf75dade0a028a3d6^..9a9a092c5388c1113e290e1cf75dade0a028a3d6` if the command is allowed, otherwise read these files whole: assets/analysis_options.yaml controller_app/analysis_options.yaml controller_app/test/coverage_all_test.dart docs/briefs/m14/bugs15/cov-1-tools-report.md packages/connection/analysis_options.yaml packages/connection/test/coverage_all_test.dart packages/game_kit/analysis_options.yaml packages/game_kit/test/coverage_all_test.dart packages/metrics/analysis_options.yaml packages/metrics/test/coverage_all_test.dart packages/party_host/analysis_options.yaml packages/party_host/test/coverage_all_test.dart packages/protocol/analysis_options.yaml packages/protocol/test/coverage_all_test.dart packages/puzzle_game/analysis_options.yaml packages/puzzle_game/test/coverage_all_test.dart packages/test_game/analysis_options.yaml packages/test_game/test/coverage_all_test.dart packages/toy_look/analysis_options.yaml packages/toy_look/test/coverage_all_test.dart tools/coverage.sh tools/coverage_imports.dart tools/coverage_summary.dart tv_test_app/analysis_options.yaml tv_test_app/test/coverage_all_test.dart 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

You are the second pair of eyes on another worker's job. Claude (the designer) will read only your Summary, then verify the findings it acts on, so be exact and short: a finding Claude cannot find in the file is worse than none.
1. **Guidelines** (docs/coding-guidelines.md): go through the changed files against each rule: size and function length, names, layers and platform rules, error handling, leftovers (prints, TODOs, commented-out code, scratch files), magic numbers, clocks and timers, text and strings.
2. **Review rules** (docs/review-rules.md, parts A and B): every host setup; when kept state starts and ends; how a new state combines with the others (pause, party night, reconnect); staying in the job's folder; stopping rather than overstepping. Check the report's self-check lines against the code: is each claim true?
3. **The brief**: is every numbered item done? Is anything built that was not asked for? Is every "Decisions" entry safe, and is any decision hidden (made but not listed)?
4. **Tests** (the runner's evidence beats the report's claim; a new test that passes on the old code is a **must**): does each new behaviour have a test that would fail without it? Any test that asserts nothing, repeats another, or tests the mock? Entries about this job in run-findings.md ("passes on the old code") count as findings.
5. **Docs**: do the documents the job touched say what the code does?

in the report, in this order and nothing else:
- `## Summary` (at most 12 lines): one line with the verdict (`clean`, `small fixes` or `needs Claude`), then the counts by severity, then the three findings that matter most.
- `## Findings`: one bullet each, most severe first, in exactly this shape: `- **<must|should|could>** <file>:<line> <what is wrong, in one sentence> → <the fix, in one sentence>`.
- `## Decisions to confirm`: the job's decisions that Claude or the owner should look at, one line each with why.
- `## Could not check`.
rules: change nothing but your report · no praise, no summary of what the job did · every finding names a file and line you have read · install nothing · leave no scratch file behind
allow: docs/briefs/m14/bugs15/cov-1-tools-review-report.md
report: docs/briefs/m14/bugs15/cov-1-tools-review-report.md
