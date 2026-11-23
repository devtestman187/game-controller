job: the run's review (read-only): everything committed in this run, read as one change, against the coding guidelines and review rules; one findings list for Claude
pub: no
stop: after it.
read: docs/briefs/m16/speed1/STATUS.md if it exists · every `docs/briefs/m16/speed1/*-review-report.md` (the per-job reviews) · docs/briefs/m16/speed1/run-findings.md if it exists · the Summary block of every `docs/briefs/m16/speed1/*-report.md` · docs/coding-guidelines.md · docs/review-rules.md · the whole change: `git diff 56dce66af669aac908cfd784337448e2930db212..0607a8072560646ab5f6308dd7b4c1ea957160c6` if the command is allowed, otherwise these files whole: .claude/agents/thumb-release.md docs/release.md tools/affected.sh tools/brief-check-testonly.sh tools/brief-check.sh tools/check-cache.sh tools/check-par.sh tools/check.sh tools/job-metrics.sh tools/run-scope.sh tools/run-steps.sh tools/tests/affected-test.sh tools/tests/brief-check-testonly-test.sh tools/tests/check-cache-test.sh tools/tests/check-failfast-test.sh tools/tests/check-par-test.sh tools/tests/check-scope-test.sh tools/tests/job-metrics-test.sh tools/tests/job-wall-test.sh tools/tests/run-affected-test.sh 
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

Claude (the designer) reads only your Summary first, verifies the findings it acts on, and writes ONE fix brief from your list. So: merge, de-duplicate and rank; a finding Claude cannot find in the file is worse than none.
1. **Carry over** every finding of the per-job reviews and of run-findings.md that still holds in the final code (a later job may have fixed it: check, and drop it if so).
2. **Hand-fixes**: list every `HAND-FIX` line of `docs/briefs/m16/speed1/run.log` and say whether the job's tests-first proof and review report exist.
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
allow: docs/briefs/m16/speed1/REVIEW.md
report: docs/briefs/m16/speed1/REVIEW.md
