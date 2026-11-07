job: review of tools job t1 (gate G4); read-only
stop: after the review. Change no file but the report; fix nothing.
read: the brief docs/briefs/m12/t1-g4.md · its report docs/briefs/m12/t1-g4-report.md · docs/coding-guidelines.md (§10, §11 and its review checklist)
diff: the job's work is uncommitted: `git diff HEAD -- tools docs/dev-tools.md` and the untracked files in `git status --short` (other uncommitted files are Claude's: ignore them).

do:
1 The brief's do-list and rules, item by item: done, missing, or different (say how), each with file:line.
2 Edge cases the job may have missed: adjacent literals (`'a' 'b'`), a `"don't"` string, a `// it's` comment, a literal with quotes inside `${…}`, a `'''` string over several lines, an escaped `\'` quote. This job can't create files, so find a real example of each with `git grep` in the lib/ folders, run the extraction on that file the way review.sh does, and say for each whether the output is right (quote the line and the output).
3 `tools/review.sh --strings --base 52cf0ea~1 --head 52cf0ea` and `--base 52cf0ea --head 46e142b`: do the outputs match the report's? Is every line explainable (a rename, a planned text)?
4 Old behaviour: `tools/review.sh` and `tools/review.sh --all` give the same totals as the report says; `--strings --all` and `--head` without `--strings` exit 2.
5 Portability: anything GNU-only (gawk functions, `sed -i` without a suffix, `\s` in awk) that breaks bash or awk on macOS.

format (the report, at most 80 lines):
## Findings — most severe first, one line each: `must|should|nit file:line — what is wrong; the rule or brief item`
## Brief — n of m items done; one line per item not done or done differently
## Checked — what you verified, and how
No praise, no summary of what the code does. A clean review says "no findings" and lists what it checked.

check:
report: docs/briefs/m12/t1-g4-review-report.md
