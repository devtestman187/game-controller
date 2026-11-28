# tooling1 f2 — report: more negated forms in the musts check

## Summary

- Added five negated forms to the musts test case (tests first), confirmed the case FAILs on the old script, then widened the negation in the script.
- Added the comment line above the musts check (grep -w also closes on "x-fixed"; accepted).
- `bash tools/tests/verify-batch-test.sh`: 19 PASS, 0 FAIL after the change.
- `tools/mine.sh`: ok (0 Dart files formatted, 0 packages analyzed or tested; the change is shell only).

## Files changed

- `tools/tests/verify-batch-test.sh`: the `musts-negated` case gets five new REVIEW.md lines (`i` to `m`: "has not been fixed", "wasn't fixed", "won't be fixed", "cannot be fixed", "can't be closed"). Expected count 8 → 13, and the line list now runs 1 to 13.
- `tools/verify-batch.sh`: the musts sed negation group is now `(not|never|isn.t|wasn.t|won.t|can.t|cannot|un)`, the words before the closed word are `(((yet|been|be)[[:space:]-]+)*)`, and a one-line comment sits above the `om=` line. Nothing else changed.

## Tests-first evidence (before the script change)

`bash tools/tests/verify-batch-test.sh`, the musts-negated line:

```
FAIL musts-negated (rc 1, want 1 and: FAIL musts: 13 open must finding(s) in docs/briefs/m1/b1/REVIEW.md at line(s): 1 2 3 4 5 6 7 8 9 10 11 12 13)
    | FAIL musts: 8 open must finding(s) in docs/briefs/m1/b1/REVIEW.md at line(s): 1 2 3 4 5 6 7 8
```

The old script found 8 open findings where 13 are expected; lines 9 to 13 were blanked wrongly.

## Test values after the change

- Expected open musts: 13 (lines 1 to 8 as before, 9 to 13 the new negated forms). The script reports 13 at lines 1 to 13.
- Full test run: 19 PASS, no FAIL lines.
- Other musts cases unchanged: musts-open (2 open, lines 1 2), musts-closed OK, musts-whole-words OK.

## Questions

1. None blocking. The `.` in `isn.t`, `wasn.t`, `won.t`, `can.t` matches any character (as the original `isn.t` already did); this is kept to match the existing style.

## Suggestions

1. If the negation list grows again, consider one shared list in a variable so the sed and its comment stay in step.

## Commit message — a draft

Widen the musts negation check to more forms

Teach verify-batch's musts check the negated forms it missed: wasn't,
won't, can't, cannot, and "not been"/"not be" before the closed word.
Before this, "has not been fixed" and "cannot be fixed" counted as open
must findings. The musts-negated test case now covers the five new forms
and expects 13 open findings; it failed on the old script (8 found).

## Status row

tooling1 f2: musts negation widened (wasn't, won't, can't, cannot, not been/be); musts-negated test extended to 13 lines, 19/19 verify-batch tests PASS. Open: none in this job.

## Delete

- none
