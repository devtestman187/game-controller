# Review of the speed1 run (56dce66a..b49aad6d)

## Summary

Verdict: **needs Claude's design** for two items (the churn revert, and whether format and analyze are cached); the rest is one fix batch of 11 small jobs, all in `tools/` and `docs/`, none pinned by controller_app tests.
Counts: must 6 · should 14 · could 9.
1. `tools/churn.sh:43-62` reverts every dirty file that matches the churn regex, with no record of what the job itself dirtied. Pre-job edits are gone from 3 `tv_test_app` generated files (sp4, sp6) and from 22 files (sp1, sp2).
2. `tools/tests/check-cache-test.sh:153` and `:245` expect 0 stub calls on a fully cached run. format and analyze never cache (`tools/check-cache.sh:36-39`), so a correct run makes 2 calls. `:173` expects 5; the run makes 7.
3. `tools/tests/check-cache-test.sh:185, 199, 208, 215, 224`: five cases pass without any cache (per the sp3 review's run; not re-run here).
4. `tools/tests/check-par-test.sh:146-155` and `tools/tests/affected-test.sh:90, 91, 118` pass on the pre-run code (exit 2 "Unknown option"; a missing script prints nothing).
5. `tools/check.sh:158` prints the help only to line 20, cutting the CHECK_SKIP paragraph. The committed cache test has no recorded passing run on the final tree.

Jobs (see Findings for each file): J1 check-cache-test.sh (after decision Q2) · J2 check-cache.sh · J3 check-par.sh · J4 check-par-test.sh · J5 check.sh + run-steps.sh · J6 affected.sh + affected-test.sh · J7 brief-check.sh + brief-check-testonly.sh · J8 job-metrics.sh + job-metrics-test.sh · J9 run-scope.sh + run-affected-test.sh · J10 docs (release.md, thumb-release.md, dev-tools.md, check-failfast fixture) · J11 report fixes. Claude: churn.sh. Each job's check: `tools`.

Questions only the owner can answer: Q1 (reverted files), Q2 (format and analyze cached?), Q3 (churn reverts only what the job dirtied?). Details below.

## Findings

- **must** tools/churn.sh:43-62 `churn_revert` runs `git checkout --` on every dirty path matching CHURN_REGEX (line 29) and never checks whether the job dirtied it → record the dirty paths at job start and revert only paths the job's own run changed; needs Claude's design (from: across jobs; sp1, sp2, sp4, sp6).
- **must** tools/tests/check-cache-test.sh:153 and :245 `calls` = 0 on a fully cached run, but format and analyze always run (`check-cache.sh:36-39` returns no key; `check.sh:116` only looks up cached suites), so a correct run makes 2 stub calls → after Q2, count only `ran` or expect 2 (from: sp3). Job J1.
- **must** tools/tests/check-cache-test.sh:173 expects `calls` = 5 for the protocol edit; the run is 5 suites (line 172 `ran`) plus format and analyze = 7 → expect 7, or assert `ran` and `cached` only (from: sp3). Job J1.
- **must** tools/tests/check-cache-test.sh:185, :199, :208, :215, :224 cases 5a, 6b, 7a, 7b, 8a pass on code with no cache (per the sp3 review's run) → before each edit or flag change, assert `cached` = ALL so each case needs the cache; keep the exit-code check at :185 as its own case (from: sp3). Job J1.
- **must** tools/tests/check-par-test.sh:146-153 the six bad-count arguments and CHECK_JOBS=0 only check exit 2 and no stub call; pre-run `check.sh:89` already exits 2 "Unknown option", so they pass on the old code → assert the "job count must be a whole number" text for each argument; make CHECK_JOBS=0 its own case (from: sp1). Job J4.
- **must** tools/tests/affected-test.sh:90, :91, :118 `expect ... ""` compares only stdout, so a missing tools/affected.sh (exit 127, no output) passes → add an exit-0 check to each (from: sp2). Job J6.
- **should** tools/check.sh:158 `-h` runs `sed -n '2,20p'`; line 20 is the CHECK_SKIP line, so lines 21-27 (CHECK_SKIP detail, CHECK_DART, the check list, exit codes) are dropped → end the range at the header's last line (27) and check the help text (from: sp1, sp3). Job J5.
- **should** tools/check-par.sh:58-63 the status file is written only on the subshell's normal path; if the subshell is killed or `mv` fails, `reap_finished` (:72-73) polls forever → write the status from an EXIT trap in the subshell (from: sp1). Job J3.
- **should** tools/check-cache.sh:76 the temp file is always `check-cache.tsv.tmp`; two check.sh runs in one checkout can clobber it → `mktemp "$cache_file.XXXXXX"` in the same folder, then `mv` (from: sp3). Job J2.
- **should** tools/check-cache.sh:26-29 the key hashes no toolchain input (no SDK version, no CHECK_DART/CHECK_FLUTTER), so a pass from an older SDK is reused → add the `flutter --version` output to the hashed input, or state the limit in the header at lines 1-7 (from: sp3). Job J2.
- **should** tools/run-steps.sh:108 `${RUN_CHECK_JOBS:-4}` is a bare 4; `tools/check.sh:62` (pre-run, so not new) also hard-codes `-j 4`, and `check.sh:134` defaults to 1 → one named default with its reason, used by both, and one name for the count (from: across jobs; sp4). Job J5.
- **should** tools/run-scope.sh:41 `format_one` runs over every `.dart` file that `find` finds under an allowed folder, so an unformatted file the job never touched is reformatted and lands in its commit → format only the .dart files the job changed (from: sp4). Job J9.
- **should** tools/tests/check-par-test.sh:172-177 case 9 (serial run) passes on the pre-run code; it is a guard, not a new behaviour test → say so in its comment (from: sp1). Job J4.
- **should** tools/brief-check.sh:13-25 the rule list omits the testonly WARN, and the help at `:51` (`sed -n '2,33p'`) does not reach it → add a `testonly` entry; the file is 298 lines, so keep it under 300 (from: sp6). Job J7.
- **should** tools/brief-check-testonly.sh:16 `*) return 0` means a folder in allow: (for example `packages/p/test`) never WARNs → decide with Q5 (from: sp6). Job J7.
- **should** tools/brief-check.sh:281 `[ -f ... ] && . tools/brief-check-testonly.sh` turns the WARN off silently when the file is missing → fail the batch check if it is missing (Q4) (from: sp6). Job J7.
- **should** tools/tests/job-metrics-test.sh:126-128 every METRICS check expects `wall=-`, so no case shows a numeric `wall=` from `--append` → add a case with a start and finish pair in run.log and grep `wall=7.5` (from: sp5). Job J8.
- **should** docs/release.md:97 and .claude/agents/thumb-release.md:12 were edited outside sp3's allow: (the brief said not to touch docs); `tools/tests/check-failfast-test.sh:15` (`export CHECK_CACHE=0`) is outside allow: too; and docs/dev-tools.md has no cache section, so the release line points at nothing → confirm or revert the three edits (Q7) and add the cache section to docs/dev-tools.md (from: sp3). Job J10.
- **should** docs/briefs/m16/speed1/sp3-report.md:55 and sp6-report.md:46 have no review-rules part A self-check (required by coding-guidelines §11; sp1, sp2, sp4, sp5 have one) → add the six one-line answers, each with its test (from: sp3, sp6). Job J10.
- **should** docs/briefs/m16/speed1/sp1-report.md:16 and :59 give the serial stub time as 12 s and 8 s; the test's bound (`tools/tests/check-par-test.sh:112`) needs -j 4 under half of serial, and 4 s is not under half of 8 s → use one measured value and name its run (from: sp1). Job J11.
- **could** tools/check-par.sh:28 and :36 `sleep 0.2` is a bare number → a named `POLL_S` with its reason in a comment (from: sp1). Job J3.
- **could** long lines over 120 columns: tools/tests/check-par-test.sh:46,122; tools/tests/job-metrics-test.sh:126-128; tools/tests/affected-test.sh:134; tools/tests/check-cache-test.sh:153,161,172; tools/tests/run-affected-test.sh:66,126,135; tools/run-scope.sh:18 → wrap them (from: sp1, sp2, sp3, sp4, sp5). Wraps ride with their file's job.
- **could** tools/job-metrics.sh:112-160 `read_log` is 49 lines against the guideline's about 40 → move the detail block (:151-158) into a helper (from: sp5). Job J8.
- **could** tools/job-metrics.sh:82-88 the calendar constants (400, 153, 146097, 365) have no name for the algorithm they follow; the comment at :76-79 does not name it → one line naming the days-from-civil algorithm (from: sp5). Job J8.
- **could** tools/affected.sh:74-75 only `path:` values that start with `.` count, so `path: packages/x` is ignored silently → accept any relative path that resolves inside the repo, or state the limit in the header (from: sp2). Job J6.
- **could** tools/tests/affected-test.sh:130-135 the real-repo expectations copy the suite list and the eight package folders (`:134`) → derive them from `bash tools/check.sh --list` (from: sp2). Job J6.
- **could** tools/run-scope.sh:36 `for j in $*` relies on word splitting → loop over `"$@"` or say why it is split (from: sp4). Job J9.
- **could** docs/briefs/m16/speed1/sp2-report.md:56 and :80 say `affected-out.tmp` must be deleted, and docs/briefs/m16/speed1/sp3-report.md:14 says `cache-test-run1.txt` is at the repo root; neither file exists now (checked) → drop both lines from the reports and status rows (from: sp2, sp3). Job J11.
- **could** across jobs: tools/brief-check.sh (298 lines, cap 300), tools/check.sh (250, cap 250) and tools/run-steps.sh (249, cap 250) are at their caps; the next change to any of them must split it first (from: across jobs; sp3, sp4, sp6).

## Open questions

1. Q1: Were the 22 files (sp1/sp2) and the 3 `tv_test_app` files (sp4/sp6) uncommitted work? Suggested: if so, copy them back from the checkout where they are still modified (the git snapshot at the start of this session lists the three `tv_test_app` files as modified at commit 67785f07, which is not this worktree's HEAD b49aad6d); the generated files are regenerated by a build anyway.
2. Q2: Are format and analyze cached? Suggested: never (current code); then the test expects 2 calls on a cached run and fixes M2 and M3 follow from it.
3. Q3: Should churn revert only the paths the job itself dirtied? Suggested: yes; this is the M1 design change for Claude.
4. Q4: If tools/brief-check-testonly.sh is missing, should the batch check fail? Suggested: yes.
5. Q5: Should a folder entry in allow: that holds only test files WARN? Suggested: yes, when every file in it is a test.
6. Q6: Keep the real-seconds timing case (check-par-test.sh:110-112)? Suggested: keep the bound but use a measured run in the report, or replace it with a check that two suites run at once.
7. Q7: Accept the three edits outside sp3's allow (docs/release.md:97, .claude/agents/thumb-release.md:12, tools/tests/check-failfast-test.sh:15) and the stub fixture in check-scope-test.sh:125? Suggested: accept the test fixtures; confirm the two docs lines.
8. Q8: Run `tools/check.sh -j 4` once on a real wave before the next run (sp4 Q3)? Suggested: yes.

## Numbers against targets

- sp1 stub timing: serial 12 s (sp1-report.md:16) and 8 s (:59); -j 4 4 s. Against the test's own bound (-j 4 under half of serial): 12 s passes (4 < 6), 8 s misses (4 is not under 4). Miss at the 8 s figure.
- sp5 turns: 43 turns against the cap of 35 (run.log:9-10). Miss; parked and hand-applied.
- Cache-test expectations, computed: a cached run makes 2 stub calls (format, analyze), so 0 is wrong (check-cache-test.sh:153, :245). A protocol edit reruns 5 suites (line 172) plus 2 = 7; the test expects 5 (:173). Both miss.
- sp5 WALL values, recomputed: 450 s = 7.5 min; 150 s = 2.5 min; 900 s = 15.0 min. These match the report.
- Full serial check (DRIVER-NOTES.md:2): 670 s before the run (596 s previously). No after-run time was measured; no speed target is written in any file I read, so this cannot be judged.
- Size: brief-check.sh 298 of 300; check.sh 250 of 250; run-steps.sh 249 of 250. All within the caps.

## Could not check

- No test or check was run in this review (read-only). The "five cases pass without a cache" and the sp3 "6 of 15 failing" come from the sp3 review and report, not from a run here. sp3's "the cache test hangs" is not confirmed by any run.
- Hand-fixes (run.log:18, :19, :52): sp2 (run.log:18; proof ba35a997 proof in done.txt; review wave1-sp2-review-report.md); sp5 (run.log:19; proof 3fdc97c3 proof; same review); sp3 (run.log:52; proof 3a15cabf proof; review wave2-sp3-review-report.md). The sp3 proof was written before the hand-fix changed the test's counts (7 → 5), so it does not cover the committed test.
- Fixed, unverified (needs a test run on the committed tree; there is no device check for shell tools): (a) sp3's no-git-key guard (check-cache.sh:21-25) and the count edits in check-cache-test.sh; (b) sp3's fix for the "second run does not skip" failure, whose cause sp3 says is unconfirmed (sp3-report.md:43); (c) the timing case's real-seconds behaviour, not measured on a slow machine.
- sp1's byte-diff of serial output against HEAD was not run (sp1-report.md:37).
- docs/briefs/m16/speed1/sp1-report.md:35 is a truncated long line; I did not re-read it, so the wave1 finding on it is not carried.
- STATUS.md and run-findings.md do not exist, so there were no runner findings to carry.
- The pre-run state of the reverted files is unknown here; git shows the three `tv_test_app` files identical to HEAD in this worktree.
- review-rules parts B and C: not applicable (no game code in this run).
- The tools suite runs `selftest.sh -j 4` inside `check.sh -j 4` (check.sh:62), so up to 16 processes can run at once; not measured.

## Commit message — a draft

review: speed1 run, 29 findings for the fix batch

Read-only review of the speed1 run's commits (56dce66a..b49aad6d)
against the coding guidelines, review rules and per-job reviews. Six musts
(churn revert of pre-job edits, cache-test expectations, cases that pass
without the cache, two tests that pass on old code), fourteen shoulds, nine
coulds. Only this report is written; no code or test changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

Speed1 run review done (6 must, 14 should, 9 could; no tests run); open: Claude's design for the churn revert (M1) and the cache contract (Q2), then fix jobs J1–J11, and the owner's answers to Q1–Q8.

## Delete

- none
