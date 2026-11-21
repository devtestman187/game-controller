# M16 process2 p2-docs: document mine.sh, wait-run.sh, selftest.sh and the extract

## Summary

Docs only, no code touched, no test added (`tests-first: exempt docs`).

Do item 1 and 2 are done. Do item 3 (`.claude/agents/thumb-batch.md`, step 3) could **not** be done: this job's permission settings deny every write under `.claude/` (the `Edit` tool says "File is in a directory that is denied by your permission settings", and Bash writes there are denied too). The file is unchanged. The exact line the brief asked for, to paste into step 3 under the `Repeat until DONE or STOPPED …` sentence:

```
   Trial (owner, Nov 21: for the next batch, the loop stays the default until the owner says otherwise): use `bash tools/wait-run.sh <dir>` (timeout 175000) instead of the for loop; fall back to the loop if it errors.
```

Files changed:
- `docs/dev-tools.md`: a row each for `mine.sh`, `selftest.sh` and `wait-run.sh` in the tools table; the three scripts added to the "plain bash, same on every OS" sentence; a `tools` row in the `check.sh` check table (`bash tools/selftest.sh`); a short section each for `tools/mine.sh`, `tools/selftest.sh` and `tools/wait-run.sh` (usage lines, what it does, env knobs, exit codes, the self-test that covers it); one sentence in the DeepSeek Flash section on `docs/worker-extract.md`.
- `docs/flash-digest.md`: a "Trial: wait-run" bullet in Run, and item 16 in Batch rules (short) saying `tools/mine.sh` exists. Nothing else.

Decisions (COMMON.md, low-usage): 
- The digest has no "Workers" heading, so the `mine.sh` line went into Batch rules (short), the digest's worker-rules list, as item 16 (appended, so no numbering moved).
- `thumb-batch.md` step 3 keeps the tail loop as the default and states the wait-run trial beside it, because the owner's decision (Nov 21) is "wait-run is for the next batch's no-polling trial; drivers keep their loop until the owner says otherwise".
- `churn.sh` has no section of its own (it is sourced, not run and has no exit codes); it is described in the `mine.sh` section's "The churn" bullet, which is where its header says it belongs.

Checks: `tools/check.sh format` PASS (9 s, "All checks passed"). I did not run the shell tools' self-tests or any Dart suite: the brief's `check:` is `format` only.

## Self-check (review-rules part A)

1. Host setups (TV/PC host, phone hosting, phone showing, joined phone, older peer): not applicable, docs-only job; no runtime path changed. The one behaviour documented, wait-run's exits, is shown by `tools/tests/wait-run-test.sh` (not run here).
2. Kept state: nothing kept by this job; the position and lock files wait-run keeps are described as they are in the script header, not changed.
3. Pause menu, host away, player away, "Get ready", dropped link, results, leaving: not applicable, no game or host code touched.
4. Stayed inside `allow:`: changed `docs/dev-tools.md` and `docs/flash-digest.md` only; `git status` also shows the runner's `docs/briefs/m16/process2/run.log` and the generated plugin churn, neither written by me.
5. Stop rather than overstep: `.claude/agents/thumb-batch.md` — all writes there were refused by the permission settings; the intended text is above instead of a workaround.
6. Every look (menu and TV), no fixed pixel height: not applicable, no widget touched.

## Questions and suggestions (not acted on)

1. `docs/dev-tools.md` still opens with "Two scripts replace the most repeated manual steps:" over a 13-row table, and `check.sh` is described as "all eight test suites" (there are ten `.dart` suites plus `tools`). Both were stale before this job and are outside its `do:` items, so I left them.
2. `tools/run-stop.sh` and its `run-stop-test.sh` are named in the selftest section's test list but have no section in `docs/dev-tools.md`; a later job could give them one.
3. The digest's batch rule 14 lists the worker Bash prefixes without `tools/mine.sh`, while `docs/briefs/templates/COMMON.md` allows it; item 16 now mentions the script but rule 14 could name it as an allowed prefix.
4. The `thumb-batch.md` step-3 edit is still owed: either allow the `.claude/` folder for that file in a brief, or apply the quoted line by hand.

## Commit message

docs: document mine.sh, wait-run.sh and selftest.sh, and the worker extract

dev-tools.md gains a section for each of the three shell tools: what it does,
the usage line, the environment knobs and exit codes 0/1/2/3 (plus 4 for
wait-run's "still running"), with the self-test that covers it and the
`tools/check.sh tools` suite. The tools table and the check.sh check table
list them, and the DeepSeek Flash section points at worker-extract.md.
The digest adds a "Trial: wait-run" bullet in Run and a line that mine.sh
exists. thumb-batch.md step 3 is not updated: `.claude/` writes are denied.

## Status row

M16 process2 p2-docs: dev-tools.md documents mine.sh, wait-run.sh and selftest.sh and the digest's wait-run trial is in — open: thumb-batch.md step 3 (`.claude/` writes denied in this job).

## Delete

- none
