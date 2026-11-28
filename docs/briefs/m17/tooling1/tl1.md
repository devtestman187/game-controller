job: tooling1 tl1 — verify-batch.sh musts check: whole words only, negated forms rejected
stop: no other check in tools/verify-batch.sh; no other file.
read: docs/briefs/templates/COMMON.md · tools/verify-batch.sh:94-102 · tools/tests/verify-batch-test.sh:60-82 (the musts cases)
changes: verify-batch.sh musts closed-word match (fixed, closed, answered as whole words) · REVIEW.md must line closing rule
model: haiku
turns: 35
expected-min: 25
tests-first: exempt the new cases pin a rule the old substring grep partly satisfies; the runner has no proof for a shell test
do:
1 Today (line 97) a must line is closed if `grep -v -i -E 'fixed|closed|answered'` matches anywhere. Make it whole words only (grep -w) and drop a line from the closed set when the word is negated: "not fixed", "not yet fixed", "never closed", "unfixed", "un-fixed", "unanswered", "isn't fixed". "prefixed" is not "fixed". Suggested: blank the negated phrases with `sed -E 's/(^|[^[:alnum:]])(not|never|un|[a-z]n.t)[[:space:]-]*(yet[[:space:]-]+)?(fixed|closed|answered)//Ig'` before the grep -w, keeping the line number from grep -n. Keep passing: "Fixed in tl1 (...)", "(FIXED)", "answered by owner", "closed", "fixed".
2 Add cases to tools/tests/verify-batch-test.sh next to the musts-closed case, same style (expect ... FAIL musts with the line numbers): FAIL for lines containing not fixed, unfixed, unanswered, prefixed, not yet fixed, un-fixed; PASS for Fixed in tl1 (x), fixed, closed, answered. Run first: `bash tools/tests/verify-batch-test.sh`.
3 Run `bash tools/tests/verify-batch-test.sh` until all PASS. Report the new case names.
allow: tools/verify-batch.sh · tools/tests/verify-batch-test.sh
check: format
report: docs/briefs/m17/tooling1/tl1-report.md
