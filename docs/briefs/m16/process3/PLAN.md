# M16 process3 plan (tools batch): DRAFT, not run

Source: owner list of Nov 22 (items a-g) and docs/briefs/m16/identity1/WAVE1.md (wave 1 defects). Only tools/ and tests; no app code. Every job ships a fast shell test (under 20 s, fake inputs, stand-in sleeps, env-overridable limits) that tools/selftest.sh runs; none edits flash.sh or .claude/**.

| Wave | Job | Scope | Owned files | Turns | Min |
|---|---|---|---|---|---|
| 1 | p3a | (a) wait-run: OVERRUN once, "checking" state, resume = job start | tools/wait-run.sh, tests/wait-run3-test.sh | 60-80 | 30 |
| 1 | p3b | (b) check.sh fail-fast; (d) selftest per-script limits (run-wire-test.sh 240 s) | tools/check.sh, tools/selftest.sh, 2 tests | 50-70 | 25 |
| 1 | p3c | (c) run-limits.sh helpers, combined check watched during the run, review limits | tools/run-limits.sh (new), run-steps.sh, run-review.sh, test | 85-100 | 40 |
| 2 | p3d | (c) wiring, (e) 120-turn cap, (f) RESULT line, (g) FLASH_CMD in the runner | tools/run-jobs.sh, test, docs/dev-tools.md | 90-110 | 45 |
| 2 | p3e | (g) stand-in worker | tools/fake-flash.sh (new), test | 35-50 | 20 |
| 3 | p3f | runner refuses a wave whose base does not compile | tools/run-base.sh (new), run-jobs.sh (few lines), test | ~30 | 15 |

5 jobs, about 320-410 turns, about 1 h 15 min by wave maximum (40 + 45) plus the combined check (about 12 min with fail-fast, selftest now 240 s on run-wire-test). Slightly over the 1 h target: p3c and p3d cannot shrink without sharing run-jobs.sh. No two jobs of one wave share a file. Wave 2 needs wave 1: p3d calls run-limits.sh (p3c) and sets nothing in check.sh (p3b's CHECK_FAIL_FAST is turned on by p3c's run-steps.sh).

## Notes
- `minutes:` field not added: the brief format already has `expected-min:` (read by wait-run.sh); the runner reads the same field, else the usage median, else 20 min. Tell the owner.
- B.8 is enforced after a job ends (turns from its usage row, stop before the checks). A hard `--max-turns` in flash.sh is a hand edit, see HANDEDITS.md.
- OVERRUN as seen in wave 1b: the check has a hard 12 min limit with fail-fast, so a 41-46 min combined check cannot recur unseen.
- Limits unit: RUN_LIMIT_UNIT_S (60 by default; tests set 1) lets a test cover minutes-long limits in seconds.
- p3d rewrites run-jobs.sh to 380 lines at most (now 326); if the worker cannot fit, it stops and asks for a split, not a silent move.
- Hand edits for the driver, not the workers: HANDEDITS.md. Dry-rehearsal of the finished tools: REHEARSAL.md.
- Lesson from identity1 wave 1b (coordinator, Nov 22): jobs of one wave must not depend on each other's results (i1b's worktree was cut from a base without i1a2's compile fix, so its job check could never pass and ran 60 min). The runner should refuse a wave whose base does not compile: add a base `dart analyze` to the preflight (one more item for p3d, or a p3f if p3d is full) and the brief rule "a job that needs another job's output goes in a later wave" to HANDEDITS item 3.
- Stop/resume lesson: a `<job>-report.md` left in the briefs folder makes the runner `resume` that job (skipping the run); rename stale reports before a re-run. Also worth a runner warning (p3d).

- Decisions of the main session, Nov 22: `expected-min:` is the one estimate field (limit = x1.5, default when absent); tools/flash.sh got `--max-turns ${FLASH_MAX_TURNS:-150}` (hard backstop, sizing target stays 120; the runner's after-the-fact cap stays); p3f added as wave 3 (base-compile refusal, replaces the 'preflight item for p3d' note above).
