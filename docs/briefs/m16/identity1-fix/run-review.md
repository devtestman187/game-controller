job: the run's review (read-only): everything committed in this run, read as one change, against the coding guidelines and review rules; one findings list for Claude
pub: no
stop: after it.
read: docs/briefs/m16/identity1-fix/STATUS.md if it exists · every `docs/briefs/m16/identity1-fix/*-review-report.md` (the per-job reviews) · docs/briefs/m16/identity1-fix/run-findings.md if it exists · the Summary block of every `docs/briefs/m16/identity1-fix/*-report.md` · docs/coding-guidelines.md · docs/review-rules.md · the whole change: `git diff 4f273fb5565d185c44fa1d845fd48e34fe6ea6d3..14d577d1d6d7275dd7cf92193eba489974ddfefd` if the command is allowed, otherwise these files whole: controller_app/lib/src/ui/host_chip.dart controller_app/lib/src/ui/pad_drawing.dart controller_app/lib/src/ui/pad_widgets.dart controller_app/lib/src/ui/stick_widgets.dart controller_app/lib/src/ui/tilt_view.dart controller_app/test/pad_character_fill_test.dart docs/dev-tools.md docs/protocol.md packages/connection/lib/src/away_slots.dart packages/connection/lib/src/host_character_reservation.dart packages/connection/lib/src/host_connection.dart packages/connection/lib/src/host_connection_pairing.dart packages/connection/lib/src/host_server.dart packages/connection/test/identity_fix_test.dart packages/connection/test/identity_hello_hold_test.dart packages/protocol/lib/src/character.dart packages/protocol/lib/src/identity.dart packages/puzzle_game/lib/src/play_view.dart packages/puzzle_game/lib/src/puzzle_module.dart packages/test_game/test/arena_phone_identity_test.dart tools/check.sh tools/flash.sh tools/tests/claude-worker-test.sh 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

Claude (the designer) reads only your Summary first, verifies the findings it acts on, and writes ONE fix brief from your list. So: merge, de-duplicate and rank; a finding Claude cannot find in the file is worse than none.
1. **Carry over** every finding of the per-job reviews and of run-findings.md that still holds in the final code (a later job may have fixed it: check, and drop it if so).
2. **Hand-fixes**: list every `HAND-FIX` line of `docs/briefs/m16/identity1-fix/run.log` and say whether the job's tests-first proof and review report exist.
2b. **Across jobs**: what no single-job review could see: two jobs solving the same thing twice, names or concepts that disagree between jobs, a document one job wrote that a later job made wrong, files that grew past 300 lines over several jobs, dead code left by a replaced approach, a rule in docs/review-rules.md that holds per job but not for the whole.
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
allow: docs/briefs/m16/identity1-fix/REVIEW.md
report: docs/briefs/m16/identity1-fix/REVIEW.md
