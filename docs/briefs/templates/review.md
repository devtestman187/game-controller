job: review of <job> (gate G<gate>); read-only
stop: after the review. Change no file but the report; fix nothing.
read: the brief <docs/briefs/…/sN-gX.md> · its report <…-report.md> · <the contract> · docs/coding-guidelines.md (all, and its review checklist)
diff: the job's work is uncommitted: `git diff HEAD` and the untracked files in `git status --short`.

do:
1 `tools/review.sh`: copy every FAIL line on the job's lines.
2 `tools/review.sh --strings`: every message, log line or UI text the diff adds, removes or changes. Mark each "allowed by brief item N" or "not in the brief".
3 The brief's do-list and rules, item by item: done, missing, or different (say how), each with file:line.
4 The guidelines' review checklist, over the whole diff: layers, shortcuts (magic numbers, special cases, swallowed errors, timing fixes), sizes and public surface, tests (real time, dispose), protocol, and changes outside the brief.
5 Tests: for each case the brief lists, the test that covers it; name any that would still pass if the rule broke.
6 The report's claims (line counts, test counts, "no behaviour change"): check two or three of them.

format (the report, at most 80 lines):
## Findings — most severe first, one line each: `must|should|nit file:line — what is wrong; the rule or brief item`
## Brief — n of m items done; one line per item not done or done differently
## Checked — what you verified in step 6, and how
No praise, no summary of what the code does. A clean review says "no findings" and lists what it checked.

check:
report: docs/briefs/<milestone>/<job>-review-report.md
