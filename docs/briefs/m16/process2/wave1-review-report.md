# Wave1 review: p2-harness and p2-prompt

## Summary

Verdict: **needs Claude** — the code is sound and both changed tools run green here, but
p2-prompt's committed report and commit message describe a job that stopped, not the
wiring that landed.
Counts: 1 must, 6 should, 5 could.
1. **Must** p2-prompt-report.md:145 — the commit message says the flash.sh wiring and the
   two doc notes "could not be done", while f4ed1fcb contains them.
2. **Should** tools/tests/selftest-test.sh:120 — the interrupted-run case never checks that
   the test script's children end, the rule script-rules.md:8 states.
3. **Should** tools/selftest.sh:18 — the header promises macOS, where a new `tools` check
   (tools/check.sh:35) fails without coreutils' `timeout`.

## Findings

- **must** docs/briefs/m16/process2/p2-prompt-report.md:145 the report's commit message (and its Summary at :5-9 and "What the follow-up needs" at :25-63) says the `$rules` extract append, the `FLASH_EXTRACT` knob, the allow entries and the two doc notes were not done, while commit f4ed1fcb carries all of them (tools/flash.sh:249-269, docs/coding-guidelines.md:3, docs/review-rules.md:3) → rewrite the Summary, Decisions, Self-check A4 and Commit message to say the runner applied steps 2-4 by hand (run.log `15:12:55`) and drop the "could not be done" text.
- **should** docs/briefs/m16/process2/p2-prompt-report.md:130 self-check A4 says "only `docs/worker-extract.md` remains changed", while f4ed1fcb changed five files → state the five files and that the two flash.sh-blocked steps were applied by the runner.
- **should** docs/briefs/m16/process2/p2-prompt-report.md:164 Delete lists `tools/tests/flash-prompt-test.sh`, which does not exist and is p2-ptest's to create (p2-ptest.md:10) → remove the Delete entry.
- **should** tools/tests/selftest-test.sh:120 the interrupted-run case checks only the lock and the temp folder, never that the test script's child processes end, which script-rules.md:8 requires ("kills its children"); the fixture at :62 detaches its output so a surviving child is invisible → have the hang fixture record its `sleep` pid and assert that pid is gone after the interrupt, and kill the child's process group in cleanup if it is not.
- **should** tools/selftest.sh:21 `cd "$(dirname "$0")/.." || exit 2` uses exit 2 (the timeout code) and prints no RESULT line, against script-rules.md:5 (exit 3 for setup, last line RESULT); selftest-test.sh:12 and :14 repeat it → call `bad_input` (moving it above the cd) or print `RESULT: BAD INPUT: ...` and exit 3 in all three places.
- **should** tools/selftest.sh:18 the header says it works on bash on macOS/Linux, but stock macOS has no `timeout` (the script itself exits 3 at :46 saying "it comes with coreutils"), so the new `tools` check at tools/check.sh:35 fails there → name the coreutils requirement in tools/selftest.sh:18 and tools/check.sh:1-15, or fall back to `gtimeout`.
- **should** docs/briefs/m16/process2/p2-harness-report.md:67 the computed-values table expects the interrupted case to pass and the driver run at ~7 s, with no mention of the trap fix the runner applied after the first combined run failed (run.log `15:12:55`); the suite takes 11 s here → add one line on the hand fix (`trap "" INT TERM` at tools/selftest.sh:83-84) and the measured 11 s.
- **could** tools/selftest.sh:55 the comment "One lock per script" contradicts the single lock the run takes (report decision 6) → say "one lock per run".
- **could** tools/selftest.sh:58-65 the live-pid check and the `printf > "$lock"` write are not atomic, so two copies started at the same instant both run; the test covers only a later start (selftest-test.sh:106-110) → create the lock with `set -C` or `mkdir` so the loser is refused.
- **could** tools/flash.sh:257 the extract is appended with no `else`, so with a missing extract the prompt still says at :249 "The extract below is the rules" and nothing follows → append the fallback sentence planned at p2-prompt-report.md:51, or reword :249.
- **could** tools/tests/selftest-test.sh:113 the stale-lock case writes pid 999999, which can be a live pid on a busy Linux host and would then be refused → take the pid from a process that has just exited.
- **could** docs/worker-extract.md:8 "No lib file you touch ends over 380 lines" is in neither source doc (coding-guidelines.md §3 says about 300, hard limit 400) → cite §3 and use its numbers, since the extract is billed as a short copy.

## Decisions to confirm

- p2-prompt step 5 (tools/tests/flash-prompt-test.sh) was moved to p2-ptest by the runner (run.log `15:12:55`, p2-ptest.md:9); p2-prompt-report.md still presents it as undone — confirm the move and that p2-ptest's `allow:` covers the file.
- tools/flash.sh is in `protected` (tools/flash.sh:281), so the p2-prompt brief cannot be done by a flash worker at all; the runner edited it by hand — decide whether flash.sh briefs go to Claude Code directly from now on.
- The missing-extract case: p2-ptest.md:9 wants "a prompt without the extract", while p2-prompt-report.md:51 planned a fallback line that was not applied — confirm the wording at tools/flash.sh:249 is what you want when the file is absent.
- The `tools` check adds ~11 s to every full `tools/check.sh` run and needs coreutils (finding above); confirm both are acceptable before the other waves rely on the check.

## Could not check

- Whether an interrupted run really leaves child processes alive: `ps`/`pgrep` filtering is unavailable here, and the new test does not assert it either.
- A full `tools/check.sh` run: only `tools` was run (`PASS tools (11s)`); the other checks need the whole suite and were outside this review.
- Whether `tools/selftest.sh` passes on a real Linux/macOS host (Git Bash only here).

## Commit message

Review wave1 (p2-harness, p2-prompt): one must, six should

Read both jobs against their briefs, docs/coding-guidelines.md and
docs/review-rules.md, and read the diff 923c053c..f4ed1fcb.
Ran `bash tools/selftest.sh` (PASS, 11 s) and `bash tools/check.sh tools`
(PASS, 11 s); `bash -n` is clean on all four changed scripts.
The must: p2-prompt's report and commit message say flash.sh was not wired,
while its commit contains the wiring and the two doc notes.
The shoulds: the interrupted-run case does not test script-rules' "kills its
children", exit 2 without a RESULT line on cd failure, the macOS claim, and
the harness report not mentioning the hand trap fix.
Findings only; this report is the only file the job writes.

## Status row

**Wave1 review (Nov 21):** p2-harness and p2-prompt checked against their briefs, the guidelines and parts A of the review rules; both tools run green here (selftest 11 s, tools check 11 s, 9 self-test cases). Open: p2-prompt's report and commit message must be rewritten to match what landed, five should fixes (interrupt-case children, exit code on cd failure, macOS/coreutils claim, harness report's computed values, p2-prompt report's file list and Delete line), and p2-ptest still owns flash-prompt-test.sh.

## Delete

- none
