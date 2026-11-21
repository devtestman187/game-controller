# Wave3 review: p2-docs, p2-ptest

## Summary

Verdict: **needs Claude** — `tools/check.sh tools` PASS (109 s, which runs the new self-test through
tools/selftest.sh); p2-ptest's cases match tools/flash.sh's rules, extract wiring and allow list, and p2-docs's
sections match the tool headers; what is left is one brief item nobody could write and two doc sentences now false.
Counts: 1 must, 2 should, 7 could.
1. **Must** .claude/agents/thumb-batch.md:17 — p2-docs do item 3 is not in the file; the exact trial line is
   quoted at p2-docs-report.md:10 and needs a job allowed to write `.claude/`.
2. **Should** docs/dev-tools.md:448 — "Every brief names worker-extract.md first" is false: briefs name
   COMMON.md first (COMMON.md:1) and tools/flash.sh:256-257 appends the extract.
3. **Should** docs/dev-tools.md:149 — the list of `tools/tests/` scripts omits the new flash-prompt-test.sh.

## Findings

- **must** .claude/agents/thumb-batch.md:17 p2-docs do item 3 is missing: step 3 still ends at "Repeat until DONE or STOPPED shows after the last `start at` line." with no wait-run trial, because the worker's `.claude/` writes were refused → paste the line quoted at p2-docs-report.md:10 after :17 from a job whose `allow:` includes that file.
- **should** docs/dev-tools.md:448 the new sentence says "Every brief names [worker-extract.md](worker-extract.md) first", but briefs name `docs/briefs/templates/COMMON.md` first (COMMON.md:1, p2-docs.md:4) and it is tools/flash.sh:256-257 that appends docs/worker-extract.md to the prompt → say "tools/flash.sh appends docs/worker-extract.md to every worker's standing prompt".
- **should** docs/dev-tools.md:149 the `tools/tests/` list names four scripts and calls them "one per tool", while the folder also holds flash-prompt-test.sh (added in 850f6c9, after this job committed) → add `flash-prompt-test.sh` (tools/flash.sh's prompt and allow list) and drop "one per tool".
- **could** tools/tests/flash-prompt-test.sh:50 `has` greps the whole dry-run output, whose first line is the `allow: … | check: … | report: …` summary, so the ten entry cases are not scoped to the `--allowedTools` argument → match only the text after `--allowedTools`.
- **could** tools/tests/flash-prompt-test.sh:52 the extract case checks only the extract's first line, so an append cut off after the heading would still pass → also assert the extract's last line.
- **could** tools/tests/flash-prompt-test.sh:13 `cd "$(dirname "$0")/../.." || exit 2` exits with the timeout code and prints no RESULT line (script-rules.md:5), the same gap wave2-review-report.md:21 found in the three sibling tests → print `RESULT: BAD INPUT: …` and exit 3.
- **could** tools/tests/flash-prompt-test.sh:25 `report` shows `head -c 600 "$out"` on every failure, so a failing doc-note case (:85-88) dumps the last flash dry run instead of the line it looked for → have the doc cases print the doc and the missing line.
- **could** docs/flash-digest.md:22 worker rule 14 lists the allow-listed Bash prefixes without `tools/mine.sh`, which tools/flash.sh:267 allows and COMMON.md's Bash line names → add `tools/mine.sh` to the list.
- **could** docs/dev-tools.md:3 "Two scripts replace the most repeated manual steps:" sits over a 13-row table, and :7 says "all eight test suites" where check.sh runs ten Dart suites plus `tools` → reword both while the table is being extended.
- **could** docs/briefs/m16/process2/p2-ptest-report.md:60 self-check item 2 cites "case: the test passing leaves no lock or file", but no case asserts that (the EXIT trap at flash-prompt-test.sh:17 removes the folder) → cite the trap or drop the claim.

## Decisions to confirm

- p2-ptest tests unchanged tools/flash.sh, so all 17 cases pass on the old code; that meets the guidelines' "new tests fail on the old code" only because the brief says `tests-first: exempt shell tooling` — confirm test-only guard jobs are exempt.
- p2-ptest-report.md:50-54: the run-jobs.sh case searches the whole output, so a future rules line naming `run-jobs.sh` would fail it — confirm that is wanted.
- p2-docs-report.md:18: the digest has no "Workers" heading, so the mine.sh line went in as Batch rules item 16 — confirm the placement.
- p2-docs-report.md:10: the quoted thumb-batch text puts the tail loop first and the trial beside it — confirm the wording before someone pastes it.
- docs/flash-digest.md:30: the Trial bullet adds "(3 is bad input)" beyond the brief's text (it matches wait-run.sh:18) — confirm the extra detail.

## Could not check

- The per-case PASS lines and the 2 s timing of tools/tests/flash-prompt-test.sh: `bash tools/tests/flash-prompt-test.sh` is refused by this session's allow list (the same refusal p2-ptest-report.md:75 reports), so only the aggregate `tools/check.sh tools` PASS (109 s, which runs tools/selftest.sh over every tools/tests/*-test.sh) was seen, and the check-log folder is outside the working directory.
- p2-docs's `tools/check.sh format` PASS (9 s): not rerun here; the job touched no Dart or shell file.
- Whether the `.claude/` write refusal the p2-docs worker reports was real: no log records the attempt and the settings that would show it are outside the working directory.

## Commit message

```
Review wave3 (p2-docs, p2-ptest): one must, two should

Read both briefs, their reports and the diff d7e6af3..850f6c9 against the
coding guidelines and review rules A-B, and ran tools/check.sh tools (PASS,
109 s, which runs the new flash-prompt self-test).
Must: p2-docs item 3, the thumb-batch.md trial line, is absent and needs a
job allowed to write .claude/; its text is quoted in the report.
Should: dev-tools.md now says every brief names worker-extract.md first
(it names COMMON.md), and its tools/tests list omits the new test file.
Coulds: the prompt test's unscoped grep, heading-only extract check, exit
code and failure output, two stale dev-tools lines, the digest's rule 14.
Findings only; this report is the only file the job writes.
```

## Status row

**Wave3 review (Nov 21):** p2-docs and p2-ptest checked against their briefs, the guidelines and review rules A-B;
`tools/check.sh tools` PASS (109 s); 10 findings, 1 must. Open: the thumb-batch.md step-3 trial line (must), the
false worker-extract sentence and the stale tools/tests list in dev-tools.md (should), and seven coulds (test
scoping, extract coverage, the cd exit code, failure output, dev-tools:3/7, digest rule 14, a report self-check).

## Delete

- none
