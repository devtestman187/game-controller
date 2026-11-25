job: the run's review (read-only): everything committed in this run, read as one change, against the coding guidelines and review rules; one findings list for Claude
pub: no
stop: after it.
read: docs/briefs/m16/wave2-789/STATUS.md if it exists · every `docs/briefs/m16/wave2-789/*-review-report.md` (the per-job reviews) · docs/briefs/m16/wave2-789/run-findings.md if it exists · the Summary block of every `docs/briefs/m16/wave2-789/*-report.md` · docs/coding-guidelines.md · docs/review-rules.md · the whole change: `git diff c492f58bf89329b9670a56c01e8fc5cb30612cca..1f6fe3754a4b4147038c7e9d072c1db69bba11f9` if the command is allowed, otherwise these files whole: controller_app/lib/src/home/coach_marks.dart controller_app/lib/src/home/home_contract.dart controller_app/lib/src/home/home_prefs.dart controller_app/lib/src/home/home_text.dart controller_app/lib/src/home/home_view.dart controller_app/lib/src/home/launch_consent.dart controller_app/lib/src/home/phone_home_screen.dart controller_app/lib/src/host/host_launch.dart controller_app/lib/src/ui/bar_connection.dart controller_app/lib/src/ui/connect_panels.dart controller_app/lib/src/ui/settings_screen.dart controller_app/lib/src/ui/settings_tips_row.dart controller_app/test/coach_marks_test.dart controller_app/test/connect_identity_gap_test.dart controller_app/test/connect_narrow_test.dart controller_app/test/connection_chip_test.dart controller_app/test/home_contract_test.dart controller_app/test/home_prefs_test.dart controller_app/test/home_view_test.dart controller_app/test/identity_change_link_test.dart controller_app/test/join_badge_test.dart controller_app/test/launch_consent_test.dart controller_app/test/phone_home_marks_test.dart controller_app/test/phone_home_screen_test.dart controller_app/test/settings_tips_test.dart controller_app/test/support/pump_app.dart controller_app/test/touch_targets_test.dart docs/code-health.md packages/party_host/test/touch_targets_host_test.dart packages/puzzle_game/lib/src/board_hud.dart packages/puzzle_game/lib/src/match_view.dart packages/puzzle_game/lib/src/play_view.dart packages/puzzle_game/lib/src/puzzle_painter.dart packages/puzzle_game/test/round_label_test.dart 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

Claude (the designer) reads only your Summary first, verifies the findings it acts on, and writes ONE fix brief from your list. So: merge, de-duplicate and rank; a finding Claude cannot find in the file is worse than none.
1. **Carry over** every finding of the per-job reviews and of run-findings.md that still holds in the final code (a later job may have fixed it: check, and drop it if so).
2. **Hand-fixes**: list every `HAND-FIX` line of `docs/briefs/m16/wave2-789/run.log` and say whether the job's tests-first proof and review report exist.
2b. **Across jobs**: what no single-job review could see: two jobs solving the same thing twice, names or concepts that disagree between jobs, a document one job wrote that a later job made wrong, files that grew past 300 lines over several jobs, dead code left by a replaced approach, a rule in docs/review-rules.md that holds per job but not for the whole.
3. **Open questions**: collect every "Questions", "Not sure about" and "Blocked" entry from the jobs' reports that nobody answered, one line each, with the safest answer you would pick.
4. **Unverified fixes**: list every fix whose cause was not measured or reproduced (a report saying so, or a fix by reasoning alone): the batch must mark these "Fixed, unverified: needs device check".
5. **Numbers**: where reports give measurements, list the ones that miss a target stated in the briefs or in STATUS.md.

1b. **Already verdicted**: if `docs/briefs/m16/wave2-789/REVIEW-VERDICTS.md` exists (the driver's verdicts on the wave reviews, fix-as-you-go), skip every finding it lists or that a committed `f<n>` fix job of this folder already fixed; carry over only what is not in it.

6. **Fix-job sizing**: for each finding give its file, and note which ones would be pinned by controller_app (phone) tests, so Claude can split the fixes into jobs of 3 findings or fewer with no shared files, in one wave (phone-pinned ones get `phone` in `check:`).

in the report, in this order and nothing else:
- `## Summary` (at most 20 lines): the verdict (`clean`, `one fix batch` or `needs Claude's design`), counts by severity, the five findings that matter most, and the questions only the owner can answer.
- `## Findings`: one bullet each, most severe first: `- **<must|should|could>** <file>:<line> <what is wrong, in one sentence> → <the fix, in one sentence> (from: <job or "across jobs">)`.
- `## Open questions`: one line each with the suggested answer.
- `## Numbers against targets`.
- `## Could not check`.
rules: change nothing but your report · no praise, no retelling of what was built · every finding names a file and line you have read · install nothing · leave no scratch file behind
allow: docs/briefs/m16/wave2-789/REVIEW.md
report: docs/briefs/m16/wave2-789/REVIEW.md
