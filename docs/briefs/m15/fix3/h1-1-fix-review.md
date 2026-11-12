job: review of job h1-1-fix (read-only): check what it committed against the coding guidelines, the review rules and its own brief; write findings only
pub: no
stop: after it.
read: docs/briefs/m15/fix3/h1-1-fix.md (the brief: what was asked) · docs/briefs/m15/fix3/h1-1-fix-report.md (what the worker says it did) · docs/coding-guidelines.md · docs/review-rules.md · docs/briefs/m15/fix3/run-findings.md if it exists · the change itself: `git diff 8c3079199da43eaa2165eda011f328af20d690b5..4407e41838d581fd4ae0afdb7be2fd694ed7a37c` if the command is allowed, otherwise read these files whole: docs/automation.md docs/briefs/m15/fix1/REVIEW.md docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md docs/briefs/m15/fix3/h1-1-fix-report.md docs/dev-tools.md packages/party_host/lib/src/automation/automation_body.dart packages/party_host/test/automation_api_test.dart packages/party_host/test/automation_server_test.dart packages/party_host/test/automation_start_error_test.dart streaming/README.md streaming/bench.sh streaming/player/reporter.js tools/stream.sh tv_test_app/test/stream_tool_test.dart 
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
allow: docs/briefs/m15/fix3/h1-1-fix-review-report.md
report: docs/briefs/m15/fix3/h1-1-fix-review-report.md
