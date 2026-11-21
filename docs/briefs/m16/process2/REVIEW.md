# Run review: M16 process2 (e53cc348..93929f2e)

## Summary

Verdict: **one fix batch** (three fix waves, no design round).
Counts: 3 must, 16 should, 19 could — 38 findings, each one read at the line it names. The run's own tests pass on the
final tree: `bash tools/selftest.sh` → 7 scripts, 151 s, `RESULT: ok`.
1. **Must** `tools/run-review.sh:24` — p2-split (886e8a58, the runner restructure) was never reviewed: no wave report
   names it and `done.txt` has no `proof` line for it, so it has neither a worker review nor a tests-first proof.
2. **Must** `docs/briefs/m16/process2/p2-prompt-report.md:153` — the report still says the flash.sh wiring "could not be
   done", and its Delete list (:164) now names `tools/tests/flash-prompt-test.sh`, a file p2-ptest created.
3. **Must** `.claude/agents/thumb-batch.md:17` — the wait-run trial line is still missing; only a hand edit can add it.
4. **Should** `tools/run-jobs.sh:139` and `tools/run-steps.sh:130` — a stop kills a running wave review before it can be
   flushed, and the finding written when `run-stop.sh` fails is never committed.
5. **Should** `docs/dev-tools.md:448,149,3,7` — four sentences about the tooling are now false (the extract, the tests
   list, two counts).
Hand-fixes: three `HAND-FIX` lines (p2-harness, p2-prompt at 15:12:55; p2-split at 16:05:21); harness and prompt have their proof line in `done.txt` and their wave1 review, p2-split has neither (finding 1).
Only the owner can answer: is `tools/flash.sh` hand-edited from now on, and is the 330-line ceiling for `run-jobs.sh` superseded (it is 336, the split test allows 340)?
Fix sizing (a proposal; jobs that share a file sit in different waves): f1 run-steps.sh, f2 run-review/run-jobs/split test, f3 run-stop/wait-run/mine-test, f4 selftest, f5 dev-tools, f6 the prompt report, f7 digest/extract, f8 headers and cd lines; waves f1/f3/f5, then f2/f4/f6/f7, then f8; no controller_app file, so no `phone`, `check: tools`.

## Findings

- **must** tools/run-review.sh:24 a job committed after its wave's review report already exists is never reviewed: `wave_review` skips when `committed "$B/wave$1-review-report.md"`, so p2-split (committed at 16:14:31, after wave3-review-report) got no review and nothing would redo it → name the review brief by the jobs it covers (`wave$1-<first job>`), or skip only when every name in RV_NAMES is already in a committed report, with a case in tools/tests/run-jobs-split-test.sh (from: across jobs; f2)
- **must** docs/briefs/m16/process2/p2-prompt-report.md:153 the Summary (:5-16), self-check A4 (:130) and commit message (:153) say the extract append, the `FLASH_EXTRACT` knob, the allow entries and the two doc notes were not done, while f4ed1fcb carries all of them, and :164 Delete lists tools/tests/flash-prompt-test.sh, which now exists → say the runner applied steps 2-4 by hand (run.log 15:12:55) and make Delete `none` (from: wave1; f6)
- **must** .claude/agents/thumb-batch.md:17 step 3 still ends at "Repeat until DONE or STOPPED shows after the last `start at` line." with no wait-run trial, and `.claude/**` is protected from workers (tools/flash.sh:281) → paste the line quoted at p2-docs-report.md:10 by hand, after :17 (from: wave3; hand edit)
- **should** tools/run-jobs.sh:139 `stop` kills its children before `flush_reviews`, so a wave review started by `start_reviews` is killed at every stop and its report never committed → keep waiting for the review on the stops that are not the STOP file, or kill only after `flush_reviews wait` (from: wave4; f2)
- **should** tools/run-steps.sh:174 `trap 'rm -f "$WORK/lock"' EXIT INT TERM` removes the lock on INT/TERM without ending the run and without checking it holds `$$`, unlike tools/mine.sh:79-85 → trap EXIT for the removal only, add `trap 'rm -f ...; exit 130' INT` and `... exit 143' TERM`, and remove it only when `$(cat "$WORK/lock")` is `$$` (from: wave4; f1)
- **should** tools/run-steps.sh:130 `save_stop` commits only `run.log` and `STOP.md`, so the finding written at :155 ("STOP.md was not written") stays uncommitted and a fresh clone never sees it → add `$B/run-findings.md` to its paths when it exists (from: wave4; f1)
- **should** tools/run-steps.sh:31 `apply_safe` returns 1 when `git apply --3way` fails, so a result-4 job whose outside files were all churn still stops (the s6b2 stop, docs/briefs/m16/phonehost2/run.log:93), against the brief's "applied, never a stop" → when the patch is empty or fails, copy the brief's `allow:`/`report:` paths out of the kept worktree and apply those (from: wave4; f1)
- **should** tools/run-jobs.sh:1 the runner is 336 lines against script-rules.md:3's "file under 300 lines", and tools/tests/run-jobs-split-test.sh:116,121 now allow 340, loosening the 330 p2-split delivered (p2-split-report.md:25: "312 lines (limit 330)") → move the stop, lock and time helpers into a fourth sourced file and keep 330, or record the new limit in script-rules.md (from: wave4 + across jobs; f2)
- **should** tools/selftest.sh:95 the hung script's `timeout` child is killed but its own `sleep` is not, so script-rules.md:8's "kills its children" is unmet, and tools/tests/selftest-test.sh:120 never checks it (the fixture at :62 detaches its output, so a survivor is invisible) → run each script in its own process group and kill the group, then have the fixture record its `sleep` pid and assert it is gone (from: wave1; f4)
- **should** tools/selftest.sh:18 the header promises "bash on macOS/Linux" while :46 exits 3 without GNU `timeout`; tools/mine.sh:26 makes the same claim and :51 needs `timeout`; tools/wait-run.sh:66,175 use GNU-only `date -d` and `touch -d @` → say "Git Bash on Windows and Linux; macOS needs coreutils (`gtimeout`)" in the three headers, or fall back to `gtimeout` (from: wave1 + across jobs; f8)
- **should** tools/run-stop.sh:121 `room=$((STOP_MAX_LINES - 7 - STOP_LOG_TAIL))` trusts five knobs: `STOP_LOG_TAIL=60` writes a 69-line STOP.md against the 40-line limit of :9, `STOP_MAX_LINES=10` still writes 29, and a non-numeric value aborts in `$(( ))` with no RESULT line (script-rules.md:5) → check the knobs are whole numbers first through `bad_input`, and cap the tail at `STOP_MAX_LINES - 8` before computing `room` (from: wave2; f3)
- **should** tools/wait-run.sh:174 `WAIT_STALL_MIN` (also `WAIT_POLL_S` at :267 and `WAIT_RECENT_ROWS` at :151) is used unvalidated while `WAIT_MAX_S` is checked at :213, so `WAIT_STALL_MIN=abc` dies in `$(( ))` under `set -u` with no RESULT line → validate the three knobs beside the `WAIT_MAX_S` check and exit 3 through `bad` (from: wave2; f3)
- **should** tools/tests/mine-test.sh:131 the case is named "a renamed file is formatted under its new path (and its tests still run)" but only the format paths are asserted, so p2-mine-report.md:24 decision 2 (the old basename keeps its tests) has no test → also assert `grep -qF 'flutter test test/screen_test.dart' "$stub/log"` (from: wave2; f3)
- **should** tools/wait-run.sh:43 `cd "$(dirname "$0")/.." || exit 3` prints no reason and no RESULT line, and nine more scripts repeat it with exit 2 (the timeout code): tools/selftest.sh:21, tools/tests/selftest-test.sh:12, tools/tests/mine-test.sh:14, tools/tests/wait-run-test.sh:14, tools/tests/run-stop-test.sh:14, tools/tests/run-wire-test.sh:18, tools/tests/run-jobs-split-test.sh:18, tools/tests/flash-prompt-test.sh:13, tools/run-jobs.sh:76 → print `RESULT: BAD INPUT: ...` and exit 3 in each, or move `bad`/`bad_input` above the cd (from: wave1/wave2/wave3; f8)
- **should** docs/dev-tools.md:448 "Every brief names [worker-extract.md] first" is false: briefs name `docs/briefs/templates/COMMON.md` first (COMMON.md:1) and tools/flash.sh:256-257 appends the extract → say "tools/flash.sh appends docs/worker-extract.md to every worker's prompt" (from: wave3; f5)
- **should** docs/dev-tools.md:149 the `tools/tests/` list calls itself "one per tool" over five scripts and omits `flash-prompt-test.sh` (added by 850f6c9d, after p2-docs committed) → add `flash-prompt-test.sh` (tools/flash.sh's prompt and allow list) and drop "one per tool" (from: wave3; f5)
- **should** docs/dev-tools.md:3 "Two scripts replace the most repeated manual steps:" sits over a five-row table, and :7 says `check.sh` runs "all eight test suites" where it runs ten Dart suites plus `tools` (tools/check.sh:18-35) → reword both to the current counts (from: wave3 + p2-docs-report.md:34; f5)
- **should** docs/flash-digest.md:22 worker rule 14 lists the allow-listed Bash prefixes without `tools/mine.sh`, which tools/flash.sh:266 allows and COMMON.md:10 now names → add `tools/mine.sh` (and `bash tools/tests/<name>-test.sh`) to rule 14 (from: wave3; f7)
- **should** tools/run-steps.sh:44 `tests_first` proves only `*_test.dart` files, so no shell self-test in this batch was ever shown failing on the old code (run.log holds no `tests-first ok` line) while docs/flash-digest.md:22 batch rule 1 says "Tests-first is proved by run.log" → say in the digest that a shell-tool batch's proof is its own self-test run against the old tree (from: across jobs; f2)
- **could** tools/churn.sh:3 and :17 still say "tools/mine.sh is the caller" and "the folders and files tools/run-jobs.sh calls CHURN", while both files source it and the names are `CHURN_PATHS`/`CHURN_REGEX` → name both callers and the current names (from: wave4; f7)
- **could** docs/flash-framework.md:56 still says the design PNGs "are also in the runner's `CHURN` list", which p2-wire removed (the list is `CHURN_PATHS` in tools/churn.sh) → one phrase to "the churn list in tools/churn.sh" (from: wave4; f7)
- **could** tools/run-steps.sh:29 `apply_safe` repeats four churn paths as inline exclude globs, a third copy of the list the brief asked to keep in one source → build them from `CHURN_PATHS`/`CHURN_REGEX`, or say in the code why they must differ (from: wave4; f1)
- **could** tools/run-jobs.sh:323 the run's final review is a foreground `tools/flash.sh` call with no `time_check` around it, so a stuck review keeps the runner past `RUN_MAX_MIN` with no `STOPPED: TIMEOUT` → run it under the same 5 s `check_stop` poll as the jobs (from: wave4; f2)
- **could** tools/wait-run.sh:249 every call opens with a `WAIT: ...` banner (and :220 prints a `NOTE:`), while p2-wait.md:24 asks for only the new lines → keep `RESULT:` and the cap NOTE, drop the banner or record it as a decision (from: wave2; f3)
- **could** tools/wait-run.sh:126 `unfinished_jobs` counts only `start <job>` lines, so a `resume <job>` (tools/run-jobs.sh:253) is never tracked: exit 4 says "preflight (no job started yet)" while a resumed job runs, and OVERRUN never fires for it → record a `resume <job>` line as that job's start (from: wave2; f3)
- **could** tools/tests/mine-test.sh:163 the only `.rc` stub written is the failing test's, so tools/mine.sh:207-209 (`FAILED dart format`) and :217-219 (`FAILED dart analyze`, the analyzer-error filter) print untested output → add one case with a `dart-format.rc` and one with a `dart-analyze.rc` (from: wave2; f3)
- **could** tools/tests/wait-run-test.sh:21 `fail()` is defined and never called (`report` at :30-33 increments `fails` itself), a leftover in a new file → delete it or call it from `report` (from: wave2; f3)
- **could** tools/tests/flash-prompt-test.sh:50 `has` greps the whole dry-run output, whose first line is the `allow: … | check: … | report: …` summary, so the ten allow cases are not scoped to `--allowedTools`; :31 dumps that same dry run when a doc-note case fails → match only the text after `--allowedTools`, and print the doc plus the missing line for the doc cases (from: wave3; f4)
- **could** tools/run-stop.sh:81 `outside_paths` is a second copy of `outside_files` (tools/run-steps.sh:11), the awk that reads a flash log's CHANGED FILES OUTSIDE block → keep the copy only if run-stop.sh must stay standalone, and say so in its header (from: across jobs; f3/f1)
- **could** tools/selftest.sh:55 "One lock per script" contradicts the single lock at :56, and the check-then-write at :58-65 is not atomic, so two copies started at the same instant both run (the test covers only a later start) → say "one lock per run" and create it with `set -C` or `mkdir` (from: wave1; f4)
- **could** tools/tests/selftest-test.sh:113 the stale-lock case writes pid 999999, which can be a live pid on a busy Linux host and would then be refused → take the pid of a process that has just exited (from: wave1; f4)
- **could** docs/dev-tools.md:5 the tools table has no row for `tools/run-stop.sh`, which the runner now calls at every stop (p2-docs-report.md:35 asks for it) → add the row and a short section (from: across jobs; f5)
- **could** docs/briefs/m16/process2/p2-harness-report.md:67 the computed-values table expects the interrupted case to pass and the suite at "~7 s" (11 s here), and never mentions the runner's trap fix (tools/selftest.sh:83-84, run.log 15:12:55) → add the hand fix and the measured 11 s (from: wave1; f6)
- **could** docs/briefs/m16/process2/p2-stop-report.md:104 the detail fixture's STOP.md is recorded as 31 lines; the count is 32 (4 head + 3 headings + 4 error lines + "none found" + 20 run.log lines) → correct the value (from: wave2; f6)
- **could** docs/briefs/m16/process2/p2-wait-report.md:48 "Two env knobs beyond the brief's list" undercounts: `WAIT_MAX_S`, `WAIT_POLL_S`, `WAIT_EXPECT_DEFAULT_MIN`, `WAIT_RECENT_ROWS` and `RUN_WORK` also go beyond it (tools/wait-run.sh:27-31) → list them or drop the ones no caller needs (from: wave2; f6)
- **could** docs/briefs/m16/process2/p2-ptest-report.md:61 self-check item 2 cites "case: the test passing leaves no lock or file", which no case asserts (the EXIT trap at tools/tests/flash-prompt-test.sh:17 removes the folder) → cite the trap or drop the claim (from: wave3; f7)
- **could** tools/flash.sh:256 the extract is appended with no `else`, so with a missing file the prompt still says at :249 "The extract below is the rules" and nothing follows; the fallback p2-prompt-report.md:51 planned is not applied and tools/tests/flash-prompt-test.sh:73 accepts either → add the `else` sentence or reword :249 (from: wave1; hand edit with f7)
- **could** docs/briefs/m16/process2/p2-mine-report.md:93 the stray folder a mistyped path created (`E:\AI\game-controller-m16-jobs\flash-20261121-155004-86602`) still needs deleting, and no other report or owner action points at it → delete it by hand (from: wave2; owner action)

## Open questions

- Does a brief that touches `tools/flash.sh` go to Claude Code directly from now on? Suggested: yes — keep the file in `protected` (tools/flash.sh:281) and edit it by hand; p2-prompt shows no worker can.
- Is the missing-extract fallback line wanted (p2-prompt-report.md:140)? Suggested: yes, add the `else` at tools/flash.sh:256; tools/tests/flash-prompt-test.sh:73 already accepts it.
- Should the runner log its `--logs` folder into run.log (p2-wait-report.md:96)? Suggested: yes, one `logs <dir>` line at start, so the waiter needs no `WAIT_LOGS`.
- Should wait-run exit non-zero on a `HAND-FIX` line (p2-wait-report.md:98)? Suggested: no; keep waiting for DONE or STOPPED.
- Is exit 4 right for a window with no new lines, rather than STALLED sooner (p2-wait-report.md:100)? Suggested: keep the brief's 20-minute rule.
- Is the 330-line ceiling for run-jobs.sh superseded by 340 (wave4; p2-split-report.md:25)? Suggested: no — move the stop, lock and time helpers out and keep 330.
- `RUN_MAX_MIN` counts from the runner's own start (tools/run-jobs.sh:111), so a batch restarted three times never reaches it (wave4). Suggested: count from the first `start at` line of run.log.
- Is `save`'s `git add -A -f -- "$@"` (tools/run-jobs.sh:151) safe for every caller? Suggested: yes; every caller names its paths and `clear_last_stop` needs one deletion.
- Is the `([^/]+/)*[^/]+-results\.json` pattern in tools/churn.sh:29 (any `X-results.json`, fixtures included) wanted (wave4)? Suggested: yes for this batch; note it in the digest.
- Are test-only guard jobs exempt from "new tests fail on the old code" (wave3; p2-ptest)? Suggested: yes for shell tooling, and say so in the digest (the should above).
- Is the digest placement of the mine.sh line as batch rule 16 right (p2-docs-report.md:18)? Suggested: yes.
- Should the mid-wave poll be 1 s instead of 5 s (p2-wire-report.md:86)? Suggested: no.
- Can `bash tools/tests/<name>-test.sh` be allowed for workers (p2-ptest-report.md:71)? Suggested: yes — the prefix is in tools/flash.sh:268, so check the sandbox's own settings, not the allow list.
- Was the `.claude/` write refusal p2-docs reported real? Suggested: treat it as real (the folder is protected, tools/flash.sh:281) and hand-apply the step-3 line.
- Can run-stop.sh's unwritable-folder branch be tested (p2-stop-report.md:115)? Suggested: accept the untested branch and mark any change to it "Fixed, unverified: needs device check".
- Should the stray folder of p2-mine-report.md:93 be deleted? Suggested: yes, by hand; it is outside the repository.

## Numbers against targets

- The slowest self-test is tools/tests/run-wire-test.sh and tools/tests/wait-run-test.sh at 44 s each (script-rules.md:10 target: under 60 s) — met; all seven take 151 s.
- docs/briefs/m16/process2/p2-harness-report.md:67 expects "~7 s" for tools/tests/selftest-test.sh; it takes 11 s (also 11 s in wave1-review-report.md:50).
- tools/run-jobs.sh is 336 lines: over script-rules.md:3's "file under 300 lines" and over the 330 recorded at p2-split-report.md:25; tools/tests/run-jobs-split-test.sh:121 allows 340.
- docs/briefs/m16/process2/p2-stop-report.md:104 states 31 lines for the detail STOP.md; the count is 32.
- docs/dev-tools.md:7 "all eight test suites": tools/check.sh:18-35 runs ten Dart suites plus `tools`.
- docs/dev-tools.md:3 "Two scripts replace the most repeated manual steps": the table under it has five rows.
- No status target could be checked: docs/briefs/m16/process2/STATUS.md does not exist (see below).

## Could not check

- `docs/briefs/m16/process2/STATUS.md` and `run-findings.md` do not exist, so no STATUS targets and no run-level findings could be read.
- Whether an interrupted selftest really leaves the hung script's `sleep` alive: `ps`/`pgrep` filtering is unavailable here and no test asserts it (the finding rests on tools/selftest.sh:95-96 alone).
- run-stop.sh's unwritable-folder branch and STOP.md under odd knobs: `chmod` is a no-op in this Git Bash and the runner's own commands were refused by this session's allow list.
- Why `apply_safe` failed for s6b2: its kept worktree and flash log are gone (docs/briefs/m16/phonehost2/run.log:93-100 only).
- Whether the `.claude/` write refusal p2-docs reported was real: no log records the attempt.
- The stray folder outside the repository (p2-mine-report.md:93): listing it is refused.
- Any `dart` suite: the run changed no Dart file, so only `tools/selftest.sh` was run here.

## Commit message

docs: run review of M16 process2 (one fix batch)

Read the eight job reports, the four wave reviews, run.log and the whole
diff e53cc348..93929f2e, then ran bash tools/selftest.sh (PASS, 7 scripts,
151 s).
The musts: p2-split was never reviewed (run-review.sh keys the report on
the wave number), p2-prompt's report and Delete list are still wrong, and
the thumb-batch step-3 line can only be hand-applied.
The shoulds: a stop kills a running review, the failed-STOP.md finding is
never committed, the scripts ship GNU-only tools under a portable header,
five knobs are unchecked and four dev-tools sentences are stale.
Findings only; this report is the only file the job writes.

## Status row

**Run review (Nov 21):** all eight jobs of M16 process2 read as one change, every wave finding re-checked at its line; `bash tools/selftest.sh` PASS (7 scripts, 151 s). Open: 3 musts (p2-split never reviewed, p2-prompt's report and Delete list, the thumb-batch step-3 line), 16 shoulds (the review-chain kill and the uncommitted finding, the portability and knob checks, the split ceiling, the stale dev-tools sentences) and 19 coulds.

## Delete

- none

