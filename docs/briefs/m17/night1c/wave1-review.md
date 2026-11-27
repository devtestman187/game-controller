job: review of the jobs of wave1 (n1h n1f e0d) (read-only): check what they committed against the coding guidelines, the review rules and its own brief; write findings only
pub: no
stop: after it.
read: docs/briefs/m17/night1c/n1h.md docs/briefs/m17/night1c/n1f.md docs/briefs/m17/night1c/e0d.md (the briefs: what was asked) · docs/briefs/m17/night1c/n1h-report.md docs/briefs/m17/night1c/n1f-report.md docs/briefs/m17/night1c/e0d-report.md (what the workers say they did) · docs/coding-guidelines.md · docs/review-rules.md · docs/briefs/m17/night1c/run-findings.md if it exists · the change itself: `git diff <each of> f1e0af2f3aabe6cb0afe9d5c04a158859d61fac1..e91bf9e721a7fb4b277644cdc9bcf33d41d88881` if the command is allowed, otherwise read these files whole: docs/briefs/m17/night1c/e0d-report.md docs/briefs/m17/night1c/n1f-report.md docs/briefs/m17/night1c/n1h-report.md packages/party_host/lib/src/night/night_flow_controller.dart packages/party_host/lib/src/night/night_flow_provider.dart packages/party_host/lib/src/night/night_settings.dart packages/party_host/lib/src/ui/player_badge.dart packages/party_host/lib/src/ui/player_badge_ring.dart packages/party_host/test/night_flow_controller_test.dart packages/party_host/test/night_flow_provider_test.dart packages/party_host/test/night_settings_test.dart packages/party_host/test/player_badge_ring_test.dart packages/party_host/test/support/night_harness.dart 
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
allow: docs/briefs/m17/night1c/wave1-review-report.md
report: docs/briefs/m17/night1c/wave1-review-report.md
