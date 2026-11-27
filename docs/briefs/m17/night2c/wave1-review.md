job: review of the jobs of wave1 (v1a t1) (read-only): check what they committed against the coding guidelines, the review rules and its own brief; write findings only
pub: no
stop: after it.
read: docs/briefs/m17/night2c/v1a.md docs/briefs/m17/night2c/t1.md (the briefs: what was asked) · docs/briefs/m17/night2c/v1a-report.md docs/briefs/m17/night2c/t1-report.md (what the workers say they did) · docs/coding-guidelines.md · docs/review-rules.md · docs/briefs/m17/night2c/run-findings.md if it exists · the change itself: `git diff <each of> f67e74194949afc3acbb2feeb22d3ad22636992c..fb20f723dd73caadc09d6df0120c6a8ac378e73d` if the command is allowed, otherwise read these files whole: docs/briefs/m17/night2c/t1-report.md docs/briefs/m17/night2c/v1a-report.md docs/driver-kit.md packages/party_host/lib/src/night/night_pick_provider.dart packages/party_host/lib/src/night/night_vote.dart packages/party_host/test/night_pick_test.dart packages/party_host/test/night_vote_test.dart tools/agent-cost.sh tools/agent_cost.py tools/tests/agent-cost-test.sh 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

You are the second pair of eyes on the other workers' jobs of one wave (review each job against its own brief). Claude (the designer) will read only your Summary, then verify the findings it acts on, so be exact and short: a finding Claude cannot find in the file is worse than none.
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
allow: docs/briefs/m17/night2c/wave1-review-report.md
report: docs/briefs/m17/night2c/wave1-review-report.md
