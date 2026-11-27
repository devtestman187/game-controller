job: review of the jobs of wave2 (d2h d2i d2x) (read-only): check what they committed against the coding guidelines, the review rules and its own brief; write findings only
pub: no
stop: after it.
read: docs/briefs/m17/night2b/d2h.md docs/briefs/m17/night2b/d2i.md docs/briefs/m17/night2b/d2x.md (the briefs: what was asked) · docs/briefs/m17/night2b/d2h-report.md docs/briefs/m17/night2b/d2i-report.md docs/briefs/m17/night2b/d2x-report.md (what the workers say they did) · docs/coding-guidelines.md · docs/review-rules.md · docs/briefs/m17/night2b/run-findings.md if it exists · the change itself: `git diff <each of> 60a64ed0eeb63119f8df938246c09d5ee8ff371a..c6c669af978c1de9217eab81c9b05eab4b397c13` if the command is allowed, otherwise read these files whole: docs/briefs/m17/night2b/d2h-report.md docs/briefs/m17/night2b/d2i-report.md docs/briefs/m17/night2b/d2x-report.md packages/party_host/lib/src/night/night_captions.dart packages/party_host/lib/src/night/night_flow.dart packages/party_host/lib/src/night/night_flow_controller.dart packages/party_host/lib/src/night/night_flow_provider.dart packages/party_host/lib/src/night/night_setup_options.dart packages/party_host/lib/src/night/night_variant.dart packages/party_host/lib/src/ui/games_screen.dart packages/party_host/lib/src/ui/night_pick_open.dart packages/party_host/lib/src/ui/night_scoreboard_screen.dart packages/party_host/test/night_how_to_reason_test.dart packages/party_host/test/night_pick_open_test.dart packages/party_host/test/night_round_hook_test.dart packages/party_host/test/night_setup_options_test.dart 
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
allow: docs/briefs/m17/night2b/wave2-review-report.md
report: docs/briefs/m17/night2b/wave2-review-report.md
