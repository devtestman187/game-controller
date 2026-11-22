# process3 run review: the whole change 88bad26f..5a6183d0

## Summary

Verdict: **one fix batch** (one must, and it is a defect no single-job review could see).
Counts: 1 must, 14 should, 21 could. Read whole: the seven reports, the three wave reviews, run.log,
done.txt, waves.txt, PLAN/HANDEDITS/REHEARSAL, the diff's 34 files (every tools/*.sh and every
tools/tests/*.sh in the range), docs/dev-tools.md.

The five that matter most:

1. **must** a job's time limit is only watched while the runner waits on that job, and a wave's jobs are
   waited on in order — so p3e ran 48 min against a 30-min limit (run.log:15-17) with no stop.
2. **should** docs/dev-tools.md never names `RUN_CHECK_MAX_MIN`, `RUN_REVIEW_MAX_MIN`, `CHECK_FAIL_FAST`,
   `CHECK_DART`/`CHECK_FLUTTER` or `SELFTEST_TIMEOUTS`, and three of the four new test scripts are missing
   from it: no job's `allow:` covered the file at the right time (across jobs).
3. **should** `review_over` and its `REVIEW TIMEOUT` (run-review.sh:99) still have no test.
4. **should** the "no estimate" default is 20 in run-limits.sh:42 and 15 in wait-run.sh:58, and the median
   logic exists twice; a p3d-tier job under wait-run warns OVERRUN before the runner's own limit.
5. **should** after a failed check the runner still fetches packages and re-runs (run-steps.sh:131-133),
   which cannot fix a format failure and cost 12 min twice in this run (run.log:18, 38).

Owner-only questions: is `RUN_TURN_CAP` a knob (docs) or a constant (code)? may a wave review have its own
limit? does the DONE line count the batch's jobs or this run's? which `RUN_MAX_MIN` did the last restart
get (run.log has no computed-backstop line)?

## Findings

- **must** tools/run-jobs.sh:321 a wave's jobs are waited on one after another, and each job's limit is only checked in its own `while kill -0`, so a later job can pass its limit unseen while an earlier one runs → check every started pid's limit in one poll loop (or check all of them while waiting on any), with a wire-test case of two jobs where the second passes its limit. (from: across jobs; p3c's limit, p3d's wiring)
  Evidence: p3e started 02:36:14 and its `finished` line was written 03:24:06 (48 min wall) against `expected-min: 20` x1.5 = 30 min (run.log:15-17, p3e.md:5); p3d was waited on first and its own 45-min estimate gave it 67 min, so p3e's loop found its pid already gone and never tested the limit. `usage()` then reports p3e's own 32 min, not the 48 the limit counted.
- **should** docs/dev-tools.md:448 the runner paragraph documents `RUN_MAX_MIN`, `RUN_TURN_CAP` and `RUN_BASE_CHECK_MAX_MIN` but the file names neither `RUN_CHECK_MAX_MIN` nor `RUN_REVIEW_MAX_MIN`, has no `--fail-fast`/`CHECK_FAIL_FAST`/`CHECK_DART`/`CHECK_FLUTTER` bullet (:41-46, :85), no `SELFTEST_TIMEOUTS` (:152-157) and no `tools/fake-flash.sh` section, and omits `check-failfast-test.sh`, `selftest-limits-test.sh`, `wait-run3-test.sh` and `fake-flash-test.sh` from its test list (:149) → one docs job adds those knobs, flags and tests (p3b-report.md:128 and p3e-report.md:130 both asked). (from: across jobs; wave1, wave2)
- **should** tools/run-review.sh:99 `review_over` and the `REVIEW TIMEOUT` stop have no test: no script sources run-review.sh for this function (run-jobs-split-test.sh:128 sources it only for `review_covers`), so a typo in the limit or in the `RUN_LIMIT_UNIT_S` arithmetic ships uncaught → add a run-limits-test.sh case with `RUN_REVIEW_MAX_MIN=1`, `RUN_LIMIT_UNIT_S=1` and a start time 2 s old that asserts true then false. (from: wave1)
- **should** tools/run-limits.sh:42 the no-estimate default is 20 min here and 15 in tools/wait-run.sh:58, and `run_expected_min` (run-limits.sh:48) copies `expected_min` (wait-run.sh:188) line for line, so the two tools disagree about one job and the rule lives twice → have wait-run.sh source run-limits.sh and call `run_expected_min`, or move the default into one shared place. (from: wave1, p3c-report.md:137)
- **should** tools/run-steps.sh:131-133 after any failed check the runner logs "checks failed; fetching packages and trying once more" and runs the whole check again, but with p3b's `CHECK_FAIL_FAST=1` a `format` failure names itself in the log and no `pub get` can change it; this run paid that retry twice (run.log:18 03:36 -> 03:48, run.log:38 04:13 -> 04:25, about 12 min each) → skip the retry when run-check.log's first FAIL is `format` (and say in the note which check failed). (from: across jobs; p3b's fail-fast, p3c's watchdog)
- **should** tools/tests/run-base-test.sh:172 case 4's only timing assertion is `elapsed_s -lt 20`, which also passes if `run_base_check` sends a plain `kill`: `wait` returns when the direct child dies, so p3f-report.md:23's "the tree kill works" is not what the test measures → have the stub start a grandchild that writes a marker after a few seconds and assert after the run that the marker never appears. (from: wave3)
- **should** docs/briefs/m16/process3/p3d-report.md:58 Decision 2 says a computed backstop of 0 becomes 360 and that `RUN_EXPECT_DEFAULT_MIN` was deliberately not used, while tools/run-jobs.sh:248 floors the value to `RUN_EXPECT_DEFAULT_MIN` (20) → rewrite Decision 2 (and Question 4, :155) to the 20-min floor and why it is there. (from: wave2)
- **should** docs/briefs/m16/process3/p3c-report.md:113 the hand-over's "219 min for process3 today" was stale the moment p3d read it (done.txt listed p3a-p3c: 45+20+15 = 80; (80x125+99)/100 = 100), and p3d-report.md:96 repeats it as this batch's row; now that five of six jobs are done the same call returns 19, floored to 20 → give the number as of that commit or drop it. (from: wave1, wave2)
- **should** docs/briefs/m16/process3/REHEARSAL.md:20 run 6 cannot end in `STOPPED: TIMEOUT`: two `expected-min: 1` jobs give (2x125+99)/100 = 3, run-jobs.sh:248 raises it to 20, and with the row's `RUN_LIMIT_UNIT_S=1` the 1 min job limit fires first → expect `job r1 passed its limit (1 min, estimate 1)`, or give run 6 a long job limit so the run's own limit is what ends it. (from: wave2)
- **should** docs/briefs/m16/process3/REHEARSAL.md:17 run 3 expects `STOPPED: r1 used 121 turns, cap 120`; tools/run-jobs.sh:177 prints `job r1 used 121 turns, over its cap of 120` → put the runner's words in the row. (from: wave2)
- **should** docs/briefs/m16/process3/p3e-report.md:113 the tests-first line says the failure was "reasoned from the script's calls, not run" although the brief asked for the run; for a NEW script on a tree without it the proof is trivial anyway (`bash` exits 127) → mark it exempt as a new file, or run it from the base commit and quote the lines. (from: wave2)
- **should** docs/briefs/m16/process3/p3f-report.md:18 the new script takes 29 s (34 s on its tests-first run) against p3f.md:11's "Under 20 s", and neither the report nor the hand-over names the miss → cut the fixtures' start-up or state why 20 s cannot be met. (from: wave3)
- **should** tools/run-jobs.sh:100 `RUN_TURN_CAP=120` is a plain assignment, so a value in the environment is silently replaced although docs/dev-tools.md:448 and the header (:74) present it as a knob → `RUN_TURN_CAP=${RUN_TURN_CAP:-120}`, or call it a constant in both places. (from: wave2)
- **should** tools/run-review.sh:111 the note "start the run's review" is parsed by tools/wait-run.sh:141-146 as a job named "the run's review" (it only skips `start at ...`), so during the final review the exit-4 line names it, OVERRUN can fire on it, and p3a's "checking" sentence never shows → log it in a form the parser skips or exclude it in `unfinished_jobs`, with a wait-run3 case. (from: wave1, p3a-report.md:83)
- **should** docs/dev-tools.md:164-165 the wait-run section still lists `WAIT_STATE_DIR` as "the lock, position and marker files" and describes exit 2/4 without the overrun record, the `, overrun already reported` suffix, the `checking: the combined check for <n> min` text or the resume rule, all of which p3a added → update those two bullets. (from: wave1)
- **could** tools/tests/wait-run3-test.sh:27,53 `fail()` and `now()` are defined and never called → delete both. (from: wave1)
- **could** tools/tests/wait-run3-test.sh:90 the "a new run reports the same job's OVERRUN again" case makes one call and passes on the old tool too (p3a-report.md:48) → after the new run's exit 2, call again and assert exit 4 with `, overrun already reported`. (from: wave1)
- **could** tools/tests/wait-run3-test.sh:101 case 3 makes two full 2 s windows (about 4 s) against p3a.md:9's "each case under about 3 s" → assert the commit line with a single call, or note the 4 s. (from: wave1)
- **could** tools/wait-run.sh:186 `seen_add` appends without `2> /dev/null` while `seen_reset` (:180) and `seen_has` (:184) discard their errors, so a read-only `WAIT_STATE_DIR` prints a shell error on every OVERRUN although p3a-report.md:72 calls that fallback quiet → redirect it the same way. (from: wave1)
- **could** tools/selftest.sh:36 `-h` prints lines 2..20 and now drops line 21 ("Works in Git Bash on Windows and bash on macOS/Linux") → `2,21p`. (from: wave1)
- **could** tools/selftest.sh:53 a space after a comma (`SELFTEST_TIMEOUTS="a=5, b=6"`) makes the name " b", which matches no script and is accepted silently, so that limit never applies → trim leading spaces or refuse whitespace in an entry. (from: wave1)
- **could** tools/run-limits.sh:32 `run_number` keeps the default for any malformed `RUN_*` value (`RUN_CHECK_MAX_MIN=1O` gives 20), where tools/check.sh:32-39 refuses a bad `CHECK_FAIL_FAST` with exit 2 and p3b-report.md:35 Decision 4 argues a typo must not turn a feature off → print the refused value and exit, or list the silent fallback as a decision. (from: wave1)
- **could** tools/tests/run-limits-test.sh:126 the hand-fixed `RUN_CHECK_MAX_MIN` default 20 (run.log:41) is pinned by no case (case 5 always sets 2) → assert the default once, as case 3 does for `RUN_EXPECT_DEFAULT_MIN`. (from: across jobs, the p3c hand-fix)
- **could** tools/run-jobs.sh:92 the `run-base.sh` source has no `|| exit 2`, unlike the three sources above it (:86-88), so a helper that fails to source leaves the runner with no base check and no message → `[ -f "$dir/run-base.sh" ] && { . "$dir/run-base.sh" || exit 2; }`. (from: wave3)
- **could** tools/run-jobs.sh:59 the base-check header line is 136 columns, the only header line over 120 (`-h` prints them) → wrap it over two lines. (from: wave3)
- **could** tools/run-jobs.sh the runner is now 376 of the split test's 380 lines, after p3d (+42) and p3f (+8) both grew it → move the stop helpers or the base-check call into run-steps.sh before the next job touches it, or give the split test's limit a name. (from: across jobs; p3d-report.md:161)
- **could** tools/run-base.sh:31 `RUN_LIMIT_UNIT_S` is used unvalidated when the helper is sourced alone (:10 says it can be): a non-numeric value makes the `$(( ))` fail, leaves `limit_s` empty and the clamp sets 1 s, so the base check is killed at once → validate the unit as `RUN_BASE_CHECK_MAX_MIN` is validated on :19. (from: wave3)
- **could** tools/tests/run-limits-wire-test.sh:155 `[ -f "$STUB_MARK" ]` cannot tell the preflight call from the job call (the stub appends the same `flash` line for both at :45) → have the stub record `$1` and assert two lines, `--preflight` and `--brief`. (from: wave2)
- **could** tools/tests/fake-flash-test.sh:9 the header says "no case sees another's files", but the cases at :78 and :172 inspect the `report` fixture's folder → say that those two continue the first run. (from: wave2)
- **could** tools/fake-flash.sh:88 `FLASH_USAGE_LOG` defaults to the real `~/.thumbparty/flash-usage.tsv`, so a rehearsal that forgets the variable writes fake rows into the log `run_expected_min` reads → refuse to write when the path is the default and the run is not a rehearsal (or document it louder in REHEARSAL.md). (from: wave2)
- **could** tools/fake-flash.sh:58 `-h`/`--help` is not in the brief (which names `--brief` and `--preflight`) and no decision lists it → keep it and add it to p3e's Decisions, or drop it. (from: wave2)
- **could** tools/run-jobs.sh:117,219 `--drop` (:117) and `--dry-run` (:219) exit without the `RESULT:` line the header (:75) and docs/dev-tools.md:448 promise on every run → print one on both, or narrow the promise. (from: wave2)
- **could** docs/briefs/m16/process3/STOP.md is committed at HEAD (925e2272) but deleted in the worktree and no commit removes it, while run-jobs.sh:68 and docs/dev-tools.md:448 say the next start removes and commits it; `clear_last_stop` (run-steps.sh:200-204) only acts when the file exists in the worktree → have it test `committed "$B/STOP.md"` before deciding, and commit this tree's removal. (from: across jobs; the run's own tree)
- **could** tools/check.sh:106 the PATH refusal is now two lines naming `CHECK_DART`/`CHECK_FLUTTER` in place of docs/building.md, an output change no decision in p3b-report.md lists (only its test case 8 asserts it) → add it to the report's Decisions. (from: wave1)
- **could** docs/briefs/m16/process3/p3c-report.md:91 and p3d-report.md:115 say `tools/review.sh` was not run because it is "not in the allow list", but `allow:` bounds the files a job writes, not the commands it runs → drop the sentence and run it next time (its `in_scope` skips `.sh`, so the 0-fail claim carries no information either way). (from: wave1, wave2)
- **could** docs/flash-digest.md HANDEDITS.md item 5 ("after p3 ships, note `RESULT:` lines, the per-step limits and FLASH_CMD; wait-run no longer repeats OVERRUN") is still unapplied and no job's `allow:` covered the file → a docs job adds it now that p3a-p3f are committed. (from: across jobs)

**Hand-fixes** (the three `HAND-FIX` lines of run.log; each job's proof and review do exist):

- run.log:21 `HAND-FIX p3d` (split test 340 -> 380): report p3d-report.md (committed 269882af, tests-first section with 4 FAIL lines), review wave2-review-report.md, and its hand commit was re-proved and re-reviewed by the runner (run.log:64-65, done.txt `p3d ... proof`). The 380 itself landed later in 0debb143; only run-limits-test (a different file) pins the number's neighbours.
- run.log:41 `HAND-FIX p3c` (`RUN_CHECK_MAX_MIN` 12 -> 20): report p3c-report.md, tests-first section with 6 FAIL lines, review wave1-review-report.md; the runner ran its proof and review at its restart (run.log:46-49). The new value is pinned by no case (see the could above).
- run.log:58 `HAND-FIX p3f` (estimate 15 -> 25 and a fresh start, after it hit its 22-min limit with no report): report p3f-report.md with 4 FAIL lines, review wave3-review-report.md (5a6183d0).

**Unverified fixes** (mark in the batch as "Fixed, unverified: needs device check"):

- p3f's tree kill (run-base.sh:39): the test only measures wall time (run-base-test.sh:172), so the tree-kill cause is not reproduced.
- p3a's anchored log parsing (wait-run.sh:136-146): no case feeds the `STOPPED: TIMEOUT: ... counted from the last 'start at' line` line it fixes.
- p3a's three states on a live batch (REHEARSAL.md rows 4 and 7: the "checking" line during a long combined check, `resume r1` shown until its commit) were never rehearsed; no batch ran them.
- p3e's tests-first proof: reasoned from the script's calls, not run (p3e-report.md:113).
- `RUN_CHECK_MAX_MIN=20` (run.log:41): measured on one PC's 12-min check only; no case and no second measurement.

**Fix-job sizing** (file per finding; none is pinned by controller_app tests, so no `phone` in `check:`):

- Job A (runner, 3): run-jobs.sh:321 must; run-jobs.sh:100; run-jobs.sh:92.
- Job B (docs/dev-tools.md, 3): the docs should; :164-165; run-jobs.sh:117,219 (the RESULT promise text lives in the same paragraph).
- Job C (limits, 3): run-limits.sh:42 + wait-run.sh:58; run-limits.sh:32; run-limits-test.sh:126.
- Job D (review limit + parser, 3): run-review.sh:99; run-review.sh:111 + wait-run.sh:141; wait-run3-test.sh:90.
- Job E (wait-run polish, 3): wait-run.sh:186; selftest.sh:36; selftest.sh:53.
- Job F (p3 reports, 3): p3d-report.md:58; p3c-report.md:113 + p3d-report.md:96; p3e-report.md:113.
- Job G (REHEARSAL + p3f report, 3): REHEARSAL.md:17; REHEARSAL.md:20; p3f-report.md:18.
- Job H (base check, 3): run-base-test.sh:172; run-base.sh:31; run-jobs.sh:59.
- Job I (retry + new tests, 3): run-steps.sh:131; run-limits-wire-test.sh:155; fake-flash-test.sh:9.
- Job J (leftovers, 4 could): wait-run3-test.sh:27,53; wait-run3-test.sh:101; fake-flash.sh:58; check.sh:106 — split J in two if 3 is the cap.
- Job K (1): run-jobs.sh 376/380.
- Job L (2 docs/one tree): STOP.md removal (run-steps.sh:200); p3c/p3d-report.md:91/115.
- Job M (2): fake-flash.sh:88; docs/flash-digest.md item 5.

## Open questions

1. Is `RUN_TURN_CAP` a knob or a constant (code says constant, docs say knob)? Suggested: a knob (`${RUN_TURN_CAP:-120}`).
2. May a wave review have its own limit (p3c-report.md:121)? Suggested: no new knob until the background chain can be killed; the run's backstop covers it today.
3. Does the DONE line count the batch's jobs or this run's (p3d-report.md:150)? Suggested: the batch's, and say so in dev-tools.md.
4. Which `RUN_MAX_MIN` did the 05:07 restart get? run.log has no computed-backstop line, so an explicit value was set, and with the computed 32 min the run should have stopped at 05:39 during the check. Suggested: the driver should log it.
5. May the `preflight (no job started yet)` branch stay untested (p3a-report.md:87)? Suggested: yes; re-add if the script's 18 s grows.
6. Keep the "checking" window starting at the last commit line (p3a-report.md:89)? Suggested: yes.
7. Two command hooks (`CHECK_DART`/`CHECK_FLUTTER` vs mine.sh's `DART`/`FLUTTER`, p3b-report.md:131)? Suggested: keep both, unify in a later job.
8. Does a check or review timeout need its own `run-stop.sh` class (p3c-report.md:122, p3d-report.md:148)? Suggested: yes, one `limit` class naming the RUN_* knob.
9. Are `RUN_RECENT_ROWS` and `FLASH_USAGE_LOG` wanted (p3c-report.md:124)? Suggested: keep; the median needs both.
10. Should the base check be skipped on a restart where the wave has nothing left (p3f-report.md:89)? Suggested: yes, before the first wave only if a job will start.
11. Name the split test's size limit (p3d-report.md:158)? Suggested: yes, one `RUNNER_MAX_LINES`.
12. Set `FAKE_FLASH_NOTE_FILE` in REHEARSAL.md's env line (p3e-report.md:131)? Suggested: yes.
13. Does the preflight's output text matter (p3e-report.md:132)? Suggested: no, only exit 0.
14. `RUN_BASE_WHY` as a caller-read global, and `RUN_BASE_CHECK_MAX_MIN=0` meaning 1 s (p3f-report.md:44, :46)? Suggested: keep both, and say "0 means 1 s" in dev-tools.md.

## Numbers against targets

| target | where | measured | verdict |
|---|---|---|---|
| run-base-test under 20 s | p3f.md:11 | 29 s (34 s tests-first) | miss |
| check-failfast-test / selftest-limits-test under 20 s | p3b.md:11 | 8 s / 12 s | ok |
| run-limits-test under 20 s | p3c.md:12 | 7 s | ok |
| run-limits-wire-test under 20 s each case | p3d.md:14 | 28-33 s whole, each case under 20 | ok |
| fake-flash-test under 15 s | p3e.md:10 | 10 s | ok |
| wait-run3-test each case about 3 s | p3a.md:9 | case 3 about 4 s, whole 18 s | slight miss |
| run-jobs.sh at or under 370 (p3d), 380 (p3f) | p3d.md:18, p3f.md:15 | 376 | ok |
| p3d turns aim 90-110 | p3d.md:18 | 67 | under |
| p3e turns 35-50, 20 min | PLAN.md:10, p3e.md:5 | 74 turns, 32 min by usage / 48 min wall | miss, and no limit stop (see the must) |
| p3f turns about 30, 15 min | p3f.md:15, p3f.md:5 | 47 turns, 22 min (stopped at 22 of 22.5), then 22 min of 25 | miss on turns |
| the batch about 1 h 15 min | PLAN.md:15 | 01:47:36 -> 05:53:18, 4 h 6 min, three stops | miss |
| this batch's backstop 219 min | p3c-report.md:113, p3d-report.md:96 | 100 when p3d read it, 19 (floored 20) now | stale number |

## Could not check

- Could not run any script: the harness refused `bash tools/tests/*-test.sh`, `tools/selftest.sh`, `tools/check.sh` and sourcing run-limits.sh, so every PASS/RESULT/time line here is the reports' (and run.log's), not mine; I did not even re-run `bash -n`.
- Why the committed STOP.md's removal was never committed: `clear_last_stop` (run-steps.sh:200-204) sees no file in the worktree, and which step deleted it (a hand edit, a worktree cleanup, a failed `git add -A` on a deleted path) is not visible from what I can read.
- The 05:07 restart's `RUN_MAX_MIN` (see Open question 4).
- tools/review.sh cannot see `.sh` files (tools/review.sh:65-76), so no report's "review.sh: 0 fail" says anything about these diffs.
- The real cost of one combined check on this PC (250-355 s in the reports) and the 12-min figure in run.log are not mine.
- HEAD here is detached at 4c5f228d (the review's own brief commit), so the worktree is one commit past 5a6183d0 and carries STOP.md deleted and run.log modified; I read the range the brief names.

## Commit message

Review the process3 run as one change: 1 must, 14 should, 21 could

Read the seven reports, three wave reviews, run.log, done.txt and the
whole diff 88bad26f..5a6183d0 against the coding guidelines and review
rules. The must is a wave-level defect no single job could see: a job's
limit is only checked while the runner waits on that job, so p3e ran 48
min against 30. The shoulds: dev-tools.md never names the new limits,
flags and three new tests; review_over still untested; two no-estimate
defaults (20 vs 15); a pub-get retry that cannot fix a format failure;
stale p3c/p3d numbers and two REHEARSAL rows that cannot match. No
script ran here, so every PASS line is the reports'.

## Status row

**Run review (Nov 22):** process3 read as one change (p3a-p3f, the three wave reviews, run.log, docs); findings only, no code changed: 1 must, 14 should, 21 could. Open: the per-job limit's in-order wait (must), docs/dev-tools.md for the new knobs and tests, a test for the review limit, one shared no-estimate default, the check retry, and the stale p3c/p3d/REHEARSAL numbers.

## Delete

- none
