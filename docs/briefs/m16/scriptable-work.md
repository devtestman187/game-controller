# Scriptable work: where Claude usage goes by hand (Nov 14-21, 124 Claude transcripts)

Method: tally scripts in the session scratchpad (tally.py, fl.py). "Eff tokens" = input + output + cache write + 0.1 x cache read per call,
summed over the calls in a cluster (rough cost proxy: each poll re-reads the whole context). Totals: main sessions 311M
(one m15 session 283M, Opus 15M + 4M), Sonnet subagents 152M. Bash was about 5900 of 9000 tool calls.

## A. Claude work that scripts or the runner can do

1. Driver polling run.log in `for i in $(seq N); do tail run.log; sleep` loops.
   Evidence: 144+69+51+63+43+49+33+30 = ~480 poll calls in thumb-batch/Sonnet drivers (phonehost, sentry, fix, bugs, stats batches); ~50M eff, about a third of all subagent usage. The largest subagent transcript (41M, 396 calls) is mostly this.
   Replacement (builds on the planned digest): runner writes `<dir>/NEXT` (one line: running / DONE / STOPPED plus the action); `tools/wait-run.sh <dir>` blocks up to 170 s and prints only new run.log lines; better, the main session watches run.log with Monitor (idle cost zero) and no Sonnet driver sits in a loop at all.
   Gain ~50M/week. Cost: small bash. Risk: shell backgrounds at 180 s, so the script must exit by 170 s.

2. Resuming after a STOP (read run.log, flash log, run-check.log, diagnose, hand-fix, restart).
   Evidence: phonehost1 2 stops/2 hand-fixes, phonehost2 4/6, phonehost3 1/1, bugs1 1/0: 8 stops, 9 HAND-FIX in 4 batches, each a Sonnet/Opus read-diagnose-edit cycle. ~10-15M.
   Replacement: on STOPPED the runner writes a 10-line `STOP.md` (cause class, failing test names from run-check.log, files outside allow, last 20 log lines, suggested action). Causes seen are mechanical:
   (a) result 4 from generated churn (a test rewriting s7-results.json, site/shots, PNGs): add to CHURN_OUTSIDE or auto-apply when the report is fine, never stop;
   (b) "tests-first: passes on old code" for coverage-only fix jobs: auto-exempt fix jobs whose review finding is coverage-only;
   (c) combined-tree check failed twice on pins of code the wave changed (host_menu_fit_test, mirror_pad_test): the runner dispatches ONE flash repair job (allow list = the failing test files, input = failing output + wave diff), re-checks, and stops only if that fails.
   Risk medium: keep the HAND-FIX/repair log line.

3. Wrap-up bookkeeping by hand (STATUS.md lines, code-health entries, tracker notes, REVIEW verdicts, final report).
   Evidence: commits 21f3a2d5, f547febd, 6272d949, 0ecba28a each add 2-7 lines to STATUS/code-health; main session ran python heredoc edits on STATUS.md ~34 times; drivers re-read REVIEW.md 22 times; the thumb-batch report asks for jobs/turns/minutes/wall time that agents recompute from run.log. ~8-11M.
   Replacement: `tools/wrap.sh <dir>` generates the STATUS result line and the final report block (jobs, turns, minutes, commits, stops, hand-fixes, check result) from run.log + done.txt; a flash job drafts verdict lines (real/fixed/deferred) and code-health entries from REVIEW.md. Claude spot-checks a 10-line digest. Tracker writes stay one batched ArtifactData call.
   Risk: flash verdicts need a Claude check, so draft only.

4. Main session tailing background task output files.
   Evidence: `tail -N .../tasks/...` and `cat` of task files ~180 calls (60+37+27+21+19+15). ~5M.
   Replacement: flash.sh/runner print one summary line on exit (`RESULT s1 0 72 turns 16 min`); watch with Monitor and a grep filter.

5. Git churn clean-up typed by hand: `git checkout -- tv_test_app/windows/flutter/ ...` (25 calls), `git status --short | head` (22), `git diff --stat` repeats. ~2M.
   Replacement: `tools/tidy.sh` (checks out the known generated paths, lists anything else dirty), called from check.sh and commit-job.sh.

6. Release: only the pre-tag diff review is Claude-only; have release.sh print the final summary block so the Haiku checker just relays it. ~2M, low value.

Out of scope (another agent): wave-review skip, report lint, digest trial.

## Flash-worker scripts

Evidence: 242 flash transcripts last 7 days: 13481 Bash, 5936 Read, 3654 Edit (no Grep tool; search goes through git grep). flash-usage.tsv: 516 jobs, average 131 turns and 877 s, 88 (17%) ended in result 4, 16 in result 5.
- cd shapes: `cd "E:/AI/.../flash-xxx/packages/..." &&` plus `cd ..`, `cd ../..`, `pwd`: ~1100 calls (about 8% of all Bash), most of them failing or wasted against the allow-list (rules already say no absolute path).
- `cd packages/party_host && flutter test ...` fails 97 times plus ~70 with absolute cd: same failing file re-run after re-reading it.
- format/analyze: `check.sh format analyze host` 50, `dart format --output=none --set-exit-if-changed` 42, `check.sh format` 26 (~120 calls, format and analyze split).
- `tools/review.sh|tail` 44, `git diff --stat` ~70, `git status --short` ~53, `wc -l` 34, `sed -n N,Np` 150+ chunked reads.
- Re-reads across jobs: coding-guidelines.md 184, review-rules.md 117 (+29 `sed -n`), game_screen.dart 36, host_harness.dart 33, host_frame_screen.dart 32, night_start_screen.dart 27, REVIEW.md 22, COMMON.md 22.

Proposals (each needs one added `Bash(tools/x.sh:*)` entry in flash.sh `allowed`):

F1. `tools/mine.sh` ("check what I touched", top value). From the repo root, no cd. Takes `git status --short`, runs `dart format` on the changed .dart files (applies it), `dart analyze` per touched package, then `flutter test` once on the touched test files plus tests that name the touched lib files (git grep -l of the basename under test/), printing only failures (name + first 8 lines) and one `OK n tests` line; then checks out generated churn outside allow. Replaces ~120 format/analyze calls, ~170 failing-test reruns and the cd noise; expect 5-15 fewer turns of 131 and fewer result-4 stops. Risk: test mapping can miss a distant pin, so the runner's combined check stays authoritative. Cost ~60 lines.

F2. `tools/where.sh <word|file>`: definition lines (git grep -n), file length, test files naming it; `--outline <file>` lists classes/methods with line numbers so workers read ranges instead of 150 chunked `sed -n` and 30+ rereads of the big screens. Read-only, ~40 lines.

F3. `tools/brief-ctx.sh`, or better flash.sh appends a 40-line extract of coding-guidelines.md and review-rules.md (the parts the brief names) to the system prompt. Those two docs are re-read ~330 times in 242 jobs (about 1.4 per job, each followed by slice reads). Saves 1-2 turns and context per job at no turn cost.

F4 (minor). `tools/diffstat.sh` = status + diff --stat against the run base in one call; make a denied absolute `cd` say "you are at the repo root; use tools/mine.sh" (cheapest fix for ~1100 cd calls).
F5. Result-4 prevention: 17% of jobs stop on churn from tests that rewrite PNG/JSON; mine.sh reverts those paths and the work rules say to run it last.

## Ranking by Claude eff tokens saved per week (guess)
1 polling -> Monitor/wait-run.sh (~50M); 2 stop report + auto-repair (~12M); 3 wrap.sh (~10M); 4 task-output tailing (~5M); 5 tidy.sh (~2M).
Flash side (indirect Claude savings through fewer stops and hand-fixes): F1 mine.sh, F2 where.sh, F3 doc extract in the prompt.
