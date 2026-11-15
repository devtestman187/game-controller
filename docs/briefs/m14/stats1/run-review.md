job: the run's review (read-only): everything committed in this run, read as one change, against the coding guidelines and review rules; one findings list for Claude
pub: no
stop: after it.
read: docs/briefs/m14/stats1/STATUS.md if it exists · every `docs/briefs/m14/stats1/*-review-report.md` (the per-job reviews) · docs/briefs/m14/stats1/run-findings.md if it exists · the Summary block of every `docs/briefs/m14/stats1/*-report.md` · docs/coding-guidelines.md · docs/review-rules.md · the whole change: `git diff 3566fe85c8f4be312e0a36ae4f0a9b3d03c60431..01380052a31d26cb3374506da6ebf00ad8310a7b` if the command is allowed, otherwise these files whole: controller_app/lib/src/host/phone_host.dart controller_app/test/phone_host_stats_lifecycle_test.dart docs/code-health.md docs/design/m12-report.md docs/dev-tools.md packages/metrics/lib/src/report.dart packages/metrics/lib/src/report_rounds.dart packages/metrics/lib/src/session.dart packages/metrics/lib/src/session_clean.dart packages/metrics/test/active_time_test.dart packages/metrics/test/csv_app_comma_test.dart packages/metrics/test/csv_app_version_test.dart packages/metrics/test/metrics_test.dart packages/metrics/test/report_games_test.dart packages/metrics/test/report_rates_test.dart packages/metrics/test/report_two_hosts_test.dart packages/metrics/test/round_frames_test.dart packages/metrics/test/round_offset_test.dart packages/metrics/test/round_winner_csv_test.dart packages/metrics/test/view_report_test.dart packages/party_host/lib/src/live_stats.dart packages/party_host/lib/src/session_recorder.dart packages/party_host/lib/src/testing/fake_stats.dart packages/party_host/test/live_stats_fixes_test.dart packages/party_host/test/round_offset_recorder_test.dart packages/party_host/test/round_stats_test.dart packages/test_game/lib/src/arena_session.dart packages/test_game/test/robot_win_record_test.dart 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

Claude (the designer) reads only your Summary first, verifies the findings it acts on, and writes ONE fix brief from your list. So: merge, de-duplicate and rank; a finding Claude cannot find in the file is worse than none.
1. **Carry over** every finding of the per-job reviews and of run-findings.md that still holds in the final code (a later job may have fixed it: check, and drop it if so).
2. **Across jobs**: what no single-job review could see: two jobs solving the same thing twice, names or concepts that disagree between jobs, a document one job wrote that a later job made wrong, files that grew past 300 lines over several jobs, dead code left by a replaced approach, a rule in docs/review-rules.md that holds per job but not for the whole.
3. **Open questions**: collect every "Questions", "Not sure about" and "Blocked" entry from the jobs' reports that nobody answered, one line each, with the safest answer you would pick.
4. **Unverified fixes**: list every fix whose cause was not measured or reproduced (a report saying so, or a fix by reasoning alone): the batch must mark these "Fixed, unverified: needs device check".
5. **Numbers**: where reports give measurements, list the ones that miss a target stated in the briefs or in STATUS.md.

6. **Fix-job sizing**: for each finding give its file, and note which ones would be pinned by controller_app (phone) tests, so Claude can split the fixes into jobs of 3 findings or fewer with no shared files, in one wave (phone-pinned ones get `phone` in `check:`).

in the report, in this order and nothing else:
- `## Summary` (at most 20 lines): the verdict (`clean`, `one fix batch` or `needs Claude's design`), counts by severity, the five findings that matter most, and the questions only the owner can answer.
- `## Findings`: one bullet each, most severe first: `- **<must|should|could>** <file>:<line> <what is wrong, in one sentence> → <the fix, in one sentence> (from: <job or "across jobs">)`.
- `## Open questions`: one line each with the suggested answer.
- `## Numbers against targets`.
- `## Could not check`.
rules: change nothing but your report · no praise, no retelling of what was built · every finding names a file and line you have read · install nothing · leave no scratch file behind
allow: docs/briefs/m14/stats1/REVIEW.md
report: docs/briefs/m14/stats1/REVIEW.md
