job: the run's review (read-only): everything committed in this run, read as one change, against the coding guidelines and review rules; one findings list for Claude
pub: no
stop: after it.
read: docs/briefs/m15/fix2/STATUS.md if it exists · every `docs/briefs/m15/fix2/*-review-report.md` (the per-job reviews) · docs/briefs/m15/fix2/run-findings.md if it exists · the Summary block of every `docs/briefs/m15/fix2/*-report.md` · docs/coding-guidelines.md · docs/review-rules.md · the whole change: `git diff 08f22cd83681c5a1d0c6fbef3f4154dd5f28e13a..9bbba208991fe08aa6bcb11b39229a6492f97e23` if the command is allowed, otherwise these files whole: docs/automation.md docs/dev-tools.md docs/flash-framework.md packages/party_host/lib/src/automation/automation_body.dart packages/party_host/lib/src/automation/automation_providers.dart packages/party_host/lib/src/automation/automation_server.dart packages/party_host/lib/src/automation/host_automation.dart packages/party_host/lib/src/text/host_text.dart packages/party_host/lib/src/ui/stats_screen.dart packages/party_host/test/automation_server_test.dart packages/party_host/test/automation_start_error_test.dart packages/party_host/test/stats_screen_test.dart streaming/README.md streaming/bench.sh streaming/player/player.js streaming/player/relay_test.py streaming/player/reporter.js streaming/player/serve.py streaming/player/stats.js tools/flash.sh tools/run-jobs.sh tools/stream.sh tv_test_app/test/stream_tool_test.dart 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

Claude (the designer) reads only your Summary first, verifies the findings it acts on, and writes ONE fix brief from your list. So: merge, de-duplicate and rank; a finding Claude cannot find in the file is worse than none.
1. **Carry over** every finding of the per-job reviews and of run-findings.md that still holds in the final code (a later job may have fixed it: check, and drop it if so).
2. **Across jobs**: what no single-job review could see: two jobs solving the same thing twice, names or concepts that disagree between jobs, a document one job wrote that a later job made wrong, files that grew past 300 lines over several jobs, dead code left by a replaced approach, a rule in docs/review-rules.md that holds per job but not for the whole.
3. **Open questions**: collect every "Questions", "Not sure about" and "Blocked" entry from the jobs' reports that nobody answered, one line each, with the safest answer you would pick.
4. **Numbers**: where reports give measurements, list the ones that miss a target stated in the briefs or in STATUS.md.

in the report, in this order and nothing else:
- `## Summary` (at most 20 lines): the verdict (`clean`, `one fix batch` or `needs Claude's design`), counts by severity, the five findings that matter most, and the questions only the owner can answer.
- `## Findings`: one bullet each, most severe first: `- **<must|should|could>** <file>:<line> <what is wrong, in one sentence> → <the fix, in one sentence> (from: <job or "across jobs">)`.
- `## Open questions`: one line each with the suggested answer.
- `## Numbers against targets`.
- `## Could not check`.
rules: change nothing but your report · no praise, no retelling of what was built · every finding names a file and line you have read · install nothing · leave no scratch file behind
allow: docs/briefs/m15/fix2/REVIEW.md
report: docs/briefs/m15/fix2/REVIEW.md
