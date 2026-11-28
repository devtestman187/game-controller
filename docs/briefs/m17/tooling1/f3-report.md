# f3 report: apostrophe-less and more contracted negations

## Summary

- Changed: `tools/verify-batch.sh` (musts negation list) and `tools/tests/verify-batch-test.sh` (musts-negated case).
- Test first: added four lines to `musts-negated` (`isnt fixed`, `wont be fixed`, `hasn't been fixed`, `don't fix: not closed`) and set the expectation to 17 open lines, 1 to 17. On the script as it was, the case FAILED: `FAIL musts: 14 open must finding(s) ... at line(s): 1 2 3 4 5 6 7 8 9 10 11 12 13 17`. Lines 14, 15 and 16 were read as closed, which is wrong.
- Script: the musts sed now takes two shell variables, `neg` (negation group `(not|never|un|cannot|(is|was|wo|ca|has|are|does|do)n.?t)`, apostrophe optional) and `closed` (`fixed|closed|answered`), each with a one-line comment. The `yet|been|be` part is unchanged.
- After the change, `bash tools/tests/verify-batch-test.sh`: 19 PASS, 0 FAIL. The `musts-negated` case now reports `FAIL musts: 17 open must finding(s) ... at line(s): 1 2 ... 17`.
- `tools/mine.sh`: `RESULT: ok: 0 file(s) formatted, 0 package(s) analyzed, 0 package(s) tested` (it covers Dart only, so it checked nothing here).

Decisions:
- The brief's `changes:` line lists `wasnt, arent, cant, hasnt, doesnt, dont` too. The `do:` item asked only for the four test lines, and the one group `(is|was|wo|ca|has|are|does|do)n.?t` covers all of them. Only the four lines are tested.
- `grep -v -w -i -E` now reads `"$closed"` instead of a repeated literal. Same words, one source.
- `(is|...)n.?t` uses `.?` as the old `isn.t` did, so `isn-t` also matches. This is the existing looseness, not a new one.

## Self-check

1. Setups: shell-only change; no host, phone or TV code touched. Covered by no code path; `tools/mine.sh` runs no app.
2. Kept state: none; the script reads REVIEW.md and writes only `say` output. Covered by the existing `musts-skip` and `musts-open` cases (PASS).
3. Combinations: the musts check is independent of pause menu, host, players, results and leave. Covered by the unchanged `musts-closed`, `musts-whole-words` (PASS).
4. Folder and allow: only the two allowed tool files and this report changed. `docs/briefs/m17/tooling1/run.log` was already modified before the job started; I did not touch it.
5. Stops: none.
6. Looks: no UI.

## Hand-over

- Files: `tools/verify-batch.sh` (variables `neg` and `closed` for the musts negation); `tools/tests/verify-batch-test.sh` (`musts-negated`: four new lines, count 13 to 17); this report.
- Checks: `tools/mine.sh` ok (nothing to run for shell); `bash tools/tests/verify-batch-test.sh` 19 PASS, 0 FAIL; the musts-negated case failed before the script change and passes after it.

## Commit message

Negation words in the musts check: accept isnt, wont, hasnt, dont

verify-batch.sh read "isnt fixed", "wont be fixed" and "hasn't been fixed"
as closed, because the negation list needed an apostrophe in the middle of
the contraction. The list now takes the contractions with or without the
apostrophe, so those must lines stay open. The sed keeps its shape; the
negation and closed words are shell variables with a comment each.
musts-negated gains four lines, and the test fails on the old script.

## Status row

f3 done: musts negation accepts apostrophe-less and more contractions (isnt, wont, hasn't, don't), tested in musts-negated (19/19 PASS). Open: other contractions (wasnt, arent, cant, hasnt, doesnt) are matched by the new group but have no test line.

## Delete

- none
