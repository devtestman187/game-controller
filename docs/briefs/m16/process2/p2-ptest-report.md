# M16 process2 ptest — self-test for the flash.sh prompt and allow list

## Summary

Added `tools/tests/flash-prompt-test.sh`, a self-test for the standing prompt
`tools/flash.sh` gives a worker: the rule extract it appends and the commands its
allow list names. 17 cases, all passing (the tools suite shows
`PASS  tools/tests/flash-prompt-test.sh (2s)`). `tools/flash.sh` itself is
unchanged (protected).

Cases, one per line the brief asked for:

1. the dry run exits 0 and the prompt carries the extract's heading text
   (`# Worker extract: the rules every job follows`, read from the file's first
   line, so it follows the file);
2–11. one case per allow-list entry: `Bash(tools/mine.sh:*)`,
   `Bash(bash tools/mine.sh:*)`, `Bash(tools/wait-run.sh:*)`,
   `Bash(bash tools/wait-run.sh:*)`, `Bash(tools/run-stop.sh:*)`,
   `Bash(bash tools/run-stop.sh:*)`, `Bash(tools/selftest.sh:*)`,
   `Bash(bash tools/selftest.sh:*)`, `Bash(bash tools/tests/:*)`,
   `Bash(tools/tests/:*)`;
12. the extract has at most 60 lines (45 now);
13. `FLASH_EXTRACT` at a missing file still gives a prompt, without the extract;
14. `FLASH_EXTRACT` in a path with spaces is included (marker text:
   `The extract from a path with spaces reached the prompt.`);
15. `docs/coding-guidelines.md` carries the note line;
16. `docs/review-rules.md` carries the note line;
17. `bash tools/run-jobs.sh` does not appear in the allow list (nor anywhere in
   the printed command).

Implementation notes:

- The dry run prints the command with `printf '%q'`, which backslash-escapes
  `(`, `)`, `*` and spaces (and spells the whole prompt as `$'...'` when it holds
  newlines). The test strips backslashes from the output before comparing with
  `grep -F`, so the cases hold whichever way the local bash quotes.
- A stub `claude` (exit 0) is put first on `PATH`: `--dry-run` only asks whether
  the CLI is installed, so no worker, key or network is used.
- Everything runs in a `mktemp -d` folder, removed by the EXIT trap; no real
  time, no lock, no file outside the temp folder is touched. Runtime 2s.
- The note line is matched as the two docs write it, word for word
  (`docs/worker-extract.md` is the short copy workers get in their prompt;
  update it with this file) — if the wording changes, that case has to change
  with it, which is the point (the note must stay in both docs).

Computed values: 45 extract lines against the 60-line ceiling (from `wc -l`);
17 cases (1 heading + 10 entries + 1 line count + 1 missing + 1 spaces + 2 docs +
1 run-jobs); 99 lines in the test file, no line over 120 columns.

Decisions: the run-jobs case checks the whole dry-run output for the string,
not just the `--allowedTools` argument, because that argument is one `%q`-quoted
blob and splitting it per rule would need worse quoting than the check is worth;
the denied list does not name `run-jobs.sh` either, so a hit anywhere is a
regression.

## Self-check (docs/review-rules.md part A)

1. Host setups: not applicable — a shell tool job; no app state. Shown by cases
   2–11 (the allow list is the same for every job type).
2. Kept state: not applicable — the test keeps nothing; its temp folder is
   removed by the EXIT trap (case: the test passing leaves no lock or file).
3. Combinations (pause menu, away, results, leaving): not applicable; nothing
   here runs a game.
4. Stay inside `allow:`: changed only `tools/tests/flash-prompt-test.sh` and this
   report (case 17 keeps the prompt honest about what a worker may run).
5. Stop rather than overstep: `tools/flash.sh` is protected; its rules, extract
   wiring and allow list were read, not edited. The two docs already carried the
   note line, so they were not touched.
6. Every look: not applicable — no widget or look is involved.

## Questions

1. `bash tools/tests/flash-prompt-test.sh` (the command the brief names) was
   refused in this job's sandbox ("requires approval"), although
   `Bash(bash tools/tests/:*)` is in `tools/flash.sh`'s allow list; I ran it via
   `tools/check.sh tools`, which runs `tools/selftest.sh`, which runs every
   `tools/tests/*-test.sh`. Is that rule missing from the job's sandbox, or does
   the prefix rule not match for another reason? Worth checking, since every
   `script-rules.md` self-test tells the worker to run itself that way.

## Suggestions

- `tools/check.sh --verbose tools` prints only the per-script PASS line, not the
  script's own output, so a worker cannot show its `PASS <case>` lines through
  the check. A `--verbose` that forwards them would make reports cheaper to
  prove.
- The extract's "## Before you write" section and the docs' note lines could be
  covered by the same test file later, if the ptest batch wants one place for
  prompt-contract cases.

## Commit message

Add a self-test for flash.sh's prompt extract and allow list

tools/tests/flash-prompt-test.sh runs flash.sh --dry-run with a stub claude
and checks the standing prompt: the extract heading, the ten allow-list
entries for the tool scripts, the 45-line extract against its 60-line
ceiling, and a missing or space-containing FLASH_EXTRACT. It also checks
that both full docs carry the note that the extract is updated with them,
and that bash tools/run-jobs.sh stays off the allow list. No script under
test changed.

## Status row

M16 process2 ptest: self-test for flash.sh's extract and allow list added and passing (17 cases); open: why `bash tools/tests/<name>-test.sh` needs approval inside a job's sandbox.

## Delete

- none
