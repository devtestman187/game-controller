# m17prep ci — report

## Summary

Read-only summary of the CI evidence and the patch. No file changed except this report.

- Cause: analyze-test-android hit its 30-minute limit. Four of the last six main runs were cancelled at 30m15s–30m20s (45878236414, 45734096031, 45627329271, 45217950023). Passing runs took 26m05s (Nov 21) and 28m21s (Nov 24).
- Growth: test files went from 451 (Nov 21) to 542 (Nov 26), about +20%. controller_app went from 91 to 117 test files (+29%).
- Duplicate work: the six plain Test steps run protocol, connection, test_game, party_host, controller_app and tv_test_app. The Coverage step (tools/coverage.sh) runs `flutter test --coverage` in all 10 packages, so those six packages run twice. Nov 26 cost of the plain Test steps: about 9m50s.
- Patch (ci-timeout.patch): timeout-minutes 30 → 45 for analyze-test-android; delete the six Test steps; rename Coverage to "Test with coverage (every package once; line % per package, no threshold)" with a comment.
- Expected: tests run once, with coverage, in about 15–16 min (down from about 25 min for tests). Whole job about 25–27 min, under the new 45 limit. If tests keep growing about 20% before the next cut, the job is still under 45.
- windows-desktop (limit 30) is not changed: total 4:00–5:28, margin about 25 min.
- Check on the next push: job time against 45 min; that the Coverage step fails when a test fails (it exits with the status); that the Step Summary still shows the per-package table.
- Not verified here: the patch is not applied by this job; the runner applies it to .github/workflows/ci.yml.

## Files changed

- docs/briefs/m17/m17prep/ci-report.md — new; this report.

## Checks

- tools/mine.sh: PASS (ran once after writing; 0 files formatted, 0 packages analyzed, 0 packages tested, as expected for a docs-only change).
- tests-first: exempt CI configuration, checked on the next push (per the brief).

## Computed values

- Nov 26 plain Test steps, sum of listed minimums: host 4:30 + controller 3:28 + game 0:38 + connection 0:14 + protocol 0:06 + TV 0:37 = 9:33; with host at 4:50 the sum is 9:53. Evidence says about 9m50s, which agrees.
- Expected job, from the evidence items: 1 + 15.5 + 6.5 + 1.5 + 1 = 25.5 min. The evidence says 26–27. The gap is probably the setup or analyze time that is not listed separately.
- Growth check: 15.5 min × 1.2 = 18.6 min for tests, which gives about 28.6 min for the job, not the "about 36 min" in the evidence.

## Questions

1. The evidence says the job is "about 36 min if the tests keep growing 20%". My arithmetic gives about 28–29 min. Which figure is right, and what is the "1" in the timing list?
2. The timing list has no time for format and analyze. Is that included in "1" or in setup?
3. Does tools/coverage.sh keep the exit status when a package's tests fail? The evidence says yes; the patch depends on it.

## Suggestions

- Put the per-step times and the list of Coverage packages in one table next time, so the expected job time can be checked by addition.
- After the next push, record the job time next to the 45-min limit in STATUS.md.

## Commit message — a draft

ci: raise analyze-test-android to 45 min; run tests once with coverage

Cancelled main runs hit the 30-min limit (test files grew about 20%).
The six plain Test steps ran protocol, connection, test_game, party_host,
controller_app and tv_test_app a second time, which tools/coverage.sh
already runs with --coverage. Delete them and rename the Coverage step to
"Test with coverage". windows-desktop stays at 30 min.

## Status row

CI timeout patch analysed (ci-timeout.patch, ci-evidence.md); report written; the runner still has to apply the patch to ci.yml and check the next push.

## Delete

- none
