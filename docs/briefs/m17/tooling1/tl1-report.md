# tl1 report: verify-batch musts check, whole words, negated forms rejected

## Summary

- `tools/verify-batch.sh` musts check: a must line now closes only on the whole words fixed, closed, answered (`grep -w`). Before blanking, the negated forms (`not`, `never`, `isn't`, `un`, with an optional `yet`) are removed from the line by `sed`, so "not fixed", "unfixed", "un-fixed", "unanswered", "isn't fixed", "never closed" and "not yet fixed" stay open. "prefixed" no longer closes because `grep -w` needs a word boundary.
- `tools/tests/verify-batch-test.sh`: two new cases next to `musts-closed`.
- Test counts: before the change 17 PASS / 0 FAIL; after the change 19 PASS / 0 FAIL.
- `tools/mine.sh`: RESULT ok, 0 files formatted, 0 packages analyzed or tested (no Dart file changed; mine.sh does not run shell tests, so the test file was run directly).
- Not run: `tools/check.sh` (left to the script, as the brief says).

### Files changed

- `tools/verify-batch.sh`: musts grep chain now `grep -n ... | sed -E '...' | grep -v -w -i -E 'fixed|closed|answered'`; the `# musts` comment says why the words are whole words and negated forms are blanked first.
- `tools/tests/verify-batch-test.sh`: added `musts-negated` and `musts-whole-words` after `musts-closed`.
- `docs/briefs/m17/tooling1/tl1-report.md`: this report.

### Computed values

- `musts-negated`: a REVIEW.md with 8 must lines, lines 1-8 = `not fixed`, `unfixed`, `unanswered`, `prefixed`, `not yet fixed`, `un-fixed`, `isn't fixed`, `never closed`. Expected: `FAIL musts: 8 open must finding(s) in docs/briefs/m1/b1/REVIEW.md at line(s): 1 2 3 4 5 6 7 8`. Result: PASS.
- `musts-whole-words`: 5 must lines = `Fixed in tl1 (x)`, `(FIXED)`, `fixed`, `closed`, `answered`. Expected: `OK musts: no open must finding`. Result: PASS.
- Existing `musts-closed` (`(FIXED)`, `answered by owner`, `closed`) still passes.
- The `isn't` apostrophe in the test is written with `'"'"'` so the printf single-quoted string stays valid.

### Decisions

- The sed pattern is the one the brief suggested, with two changes: `[a-z]n.t` became `isn.t`, because `(^|[^[:alnum:]])` before the group could not match an "s" that follows "i" (so "isn't fixed" would have passed); and the group is now a plain alternation `(not|never|isn.t|un)`.
- The `I` flag in sed is GNU sed; it works in Git Bash here (tests pass).

### Self-check (review-rules part A)

1. Host setups: N/A, shell script only (no app code).
2. Kept state: N/A, no state; the check reads REVIEW.md once per run.
3. Combination with other states: N/A.
4. Stayed inside allow: yes, the two script files plus this report.
5. Stop rather than overstep: see Questions, item 1 (REVIEW.md not edited).
6. Looks: N/A.

## Questions

1. The brief's `changes:` line says "REVIEW.md must line closing rule", but REVIEW.md is not in `allow:` and the `do:` steps only change the script and its test. I changed only the script (the closing rule lives there). If a REVIEW.md template line also needs a note, say which file and I will report it instead of editing.
2. The check also treats a bare "fixed" preceded by a non-word character, such as "bun fixed" or "x-fixed", as closed (`grep -w`). That is correct for the stated rule but could be looser than intended; a stricter check would need a word list. Not changed.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

verify-batch: must lines close only on whole words, not negated ones

The musts check matched fixed, closed and answered anywhere in a line, so
"prefixed", "unfixed", "not fixed" and "isn't fixed" closed an open must.
Blank the negated forms first (not, never, isn't, un, optional yet), then
match the three words with grep -w. Two cases in verify-batch-test.sh pin
the rule; the existing closed cases still pass.

## Status row

tooling1 tl1: verify-batch musts check counts whole words only and keeps negated forms open (done, 19/19 test cases pass); open: REVIEW.md closing-rule note (question 1, not in allow).

## Delete

- none
