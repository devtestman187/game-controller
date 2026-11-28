job: the run's review (read-only): everything committed in this run, read as one change, against the coding guidelines and review rules; one findings list for Claude
pub: no
stop: after it.
read: docs/briefs/m17/tooling1/STATUS.md if it exists · every `docs/briefs/m17/tooling1/*-review-report.md` (the per-job reviews) · docs/briefs/m17/tooling1/run-findings.md if it exists · the Summary block of every `docs/briefs/m17/tooling1/*-report.md` · docs/coding-guidelines.md · docs/review-rules.md · the whole change: `git diff e9bbe42f351a0fbc0516df4f4a9d023ad3ebef71..9fcc2e1832f7c36cb7d00ef013a43bcd3e58ffd2` if the command is allowed, otherwise these files whole: packages/party_host/test/systest/systest_support.dart tools/tests/verify-batch-test.sh tools/verify-batch.sh 
decide: write `docs/briefs/m17/tooling1/REVIEW.md` EARLY and keep it up to date: after the carry-over (step 1) create it with a `## Summary` whose first line says `partial` and the findings so far, then rewrite it as each later step finishes, and drop `partial` only in your last edit. You may run out of turns: a REVIEW.md that exists beats a perfect one that does not. Never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

Claude (the designer) reads only your Summary first, verifies the findings it acts on, and writes ONE fix brief from your list. So: merge, de-duplicate and rank; a finding Claude cannot find in the file is worse than none.
1. **Carry over** every finding of the per-job reviews and of run-findings.md that still holds in the final code (a later job may have fixed it: check, and drop it if so).
2. **Hand-fixes**: list every `HAND-FIX` line of `docs/briefs/m17/tooling1/run.log` and say whether the job's tests-first proof and review report exist.
2b. **Across jobs**: what no single-job review could see: two jobs solving the same thing twice, names or concepts that disagree between jobs, a document one job wrote that a later job made wrong, files that grew past 300 lines over several jobs, dead code left by a replaced approach, a rule in docs/review-rules.md that holds per job but not for the whole.
3. **Open questions**: collect every "Questions", "Not sure about" and "Blocked" entry from the jobs' reports that nobody answered, one line each, with the safest answer you would pick.
4. **Unverified fixes**: list every fix whose cause was not measured or reproduced (a report saying so, or a fix by reasoning alone): the batch must mark these "Fixed, unverified: needs device check".
5. **Numbers**: where reports give measurements, list the ones that miss a target stated in the briefs or in STATUS.md.

1b. **Already verdicted**: if `docs/briefs/m17/tooling1/REVIEW-VERDICTS.md` exists (the driver's verdicts on the wave reviews, fix-as-you-go), skip every finding it lists or that a committed `f<n>` fix job of this folder already fixed; carry over only what is not in it.

6. **Fix-job sizing**: for each finding give its file, and note which ones would be pinned by controller_app (phone) tests, so Claude can split the fixes into jobs of 3 findings or fewer with no shared files, in one wave (phone-pinned ones get `phone` in `check:`).

in the report, in this order and nothing else:
- `## Summary` (at most 20 lines): the verdict (`clean`, `one fix batch` or `needs Claude's design`), counts by severity, the five findings that matter most, and the questions only the owner can answer.
- `## Findings`: one bullet each, most severe first: `- **<must|should|could>** <file>:<line> <what is wrong, in one sentence> → <the fix, in one sentence> (from: <job or "across jobs">)`.
- `## Open questions`: one line each with the suggested answer.
- `## Numbers against targets`.
- `## Could not check`.
rules: change nothing but your report · no praise, no retelling of what was built · every finding names a file and line you have read · install nothing · leave no scratch file behind
allow: docs/briefs/m17/tooling1/REVIEW.md
report: docs/briefs/m17/tooling1/REVIEW.md
