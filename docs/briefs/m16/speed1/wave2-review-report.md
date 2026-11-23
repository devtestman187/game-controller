# Wave 2 review: sp6 and sp4

## Summary

Verdict: needs Claude (one must: an uncommitted-file revert outside allow:, see the first finding).
Counts: must 1 · should 3 · could 4.
Top three:
1. sp4 ran tools/mine.sh, whose churn step reverted three files outside its allow: that were already modified; they are now identical to HEAD, so any pre-job edits are gone.
2. The brief-check.sh rule list and its -h help (lines 13-25, 51) do not name the new testonly WARN.
3. tools/run-steps.sh:108 hard-codes the default `-j 4` (a bare number the guidelines do not allow).

## Findings

- **must** docs/briefs/m16/speed1/sp4-report.md:38 Self-check A4 says only the listed files changed, but the churn revert (sp4-report.md:52) restored tv_test_app/windows/flutter/generated_plugin_registrant.cc, generated_plugin_registrant.h and generated_plugins.cmake, which are outside allow:; they are now identical to HEAD, so edits they held before the job are lost → Claude decides whether they can be recovered, and mine.sh's churn step must leave files that were dirty before the job began.
- **should** tools/brief-check.sh:13 The header rule list (lines 13-25) and the -h output (`sed -n '2,33p'`, line 51) do not name the testonly WARN → add a `testonly` entry to the list and let the help range cover it (the file is 298 lines; check it stays under 300).
- **should** tools/run-steps.sh:108 `${RUN_CHECK_JOBS:-4}` puts a bare 4 in the runner (guidelines §2 allows only 0, 1, -1, 2) → a named default with its reason in a comment; if the brief's exact text must stay, record it as a decision.
- **should** docs/briefs/m16/speed1/sp6-report.md:31 The report has no review-rules part A self-check (guidelines §11 requires it; sp4-report.md has one) → add the six one-line answers, each with its test.
- **could** tools/run-scope.sh:41 format_job_files runs dart format on every .dart file under an allowed folder, so unchanged files in that folder are rewritten and committed with the job → format only the .dart files the job changed.
- **could** tools/run-scope.sh:18 The note line is over 120 columns → wrap it.
- **could** tools/tests/run-affected-test.sh:126 Lines 66, 126 and 135 are over 120 columns → wrap them.
- **could** docs/briefs/m16/speed1/sp6-report.md:37 Says brief-check.sh gets "3 lines added"; the diff adds 4 (the blank line after the source line is the fourth) → fix the count.
- **could** tools/run-scope.sh:36 `for j in $*` relies on word splitting of the job names (works, since names have no spaces) → loop over "$@" with a quoted expansion, or say in the comment why it is split.

Checked and true: the tests named in the reports pass here (see Could not check for the rest); sp4's claims that checks() gets the job names as one string (run-jobs.sh:341), that check.sh takes -j (check.sh:137, 145), that run-steps.sh is 249 lines, and that the tools rule holds in every path all match the code. sp6's claims about the WARN text, the exit code and the brief-check.sh size (298) match the code.

## Decisions to confirm

- tools/run-scope.sh:18-19 A failing or missing affected.sh skips no suite for its paths but still applies the tools rule; the brief's words were "falls back to every suite". Cases 4 and 5 pin the worker's reading; confirm it.
- tools/run-scope.sh:36-41 The jobs' .dart files are formatted before the checks and before commit, and a `dir` entry formats the whole folder; confirm the owner's format-before-check choice covers folders.
- tools/tests/check-scope-test.sh:125 An existing test's fixture gains a tools/affected.sh stub that prints an empty line. Its assertions are unchanged, but confirm it is a fixture change, not a loosened check.
- tools/brief-check-testonly.sh:16 A folder entry in allow: (for example packages/p/test) never WARNs, because only *_test.dart counts; the brief says *_test.dart only, so this follows it, but it is a gap.
- tools/brief-check.sh:281 The testonly WARN is silently off when tools/brief-check-testonly.sh is missing (sourced "when present", as the brief asked); say if it should be required.
- tools/run-steps.sh:108 The default parallel count 4 is fixed here (see the should above).

## Could not check

- The FAIL-before-change lines in sp4-report.md:16-21 and sp6-report.md:14-17 were not re-run on the old tree (no git checkout allowed); the new tests all pass now.
- Whether the three generated files held real pre-job edits: git status listed them as M at job start, and git diff now shows no difference from HEAD, so what was lost cannot be seen from here.
- The real combined check with -j 4 on a live wave: not run (out of scope; tools/check.sh is outside allow:).
- docs/briefs/m16/speed1/run-findings.md does not exist, so there were no run-findings entries to count.
- Whether the allowed folders hold generated .dart files that the new formatter would rewrite: not checked.

Tests run here: tools/tests/run-affected-test.sh 8 of 8 PASS · tools/tests/brief-check-testonly-test.sh 6 of 6 PASS · tools/tests/check-scope-test.sh 9 of 9 PASS · tools/tests/brief-check-test.sh 8 of 8 PASS · tools/tests/run-wave-test.sh 4 of 4 PASS · tools/tests/run-jobs-split-test.sh 13 of 13 PASS.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

none: this review changes no code and makes no commit. The report is the only file written.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 speed1 wave 2 review done (sp4, sp6): all test suites pass here; 1 must, 3 should, 4 could. Open: Claude decides the recovery of the three generated tv_test_app files reverted by mine.sh, and the should fixes (brief-check header, the -j 4 default, the sp6 self-check).

## Delete

- none
