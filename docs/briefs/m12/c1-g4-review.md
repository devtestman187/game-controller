job: review of cleanup c1 (gate G4); read-only
stop: after the review. Change no file but the report; fix nothing.
read: the brief docs/briefs/m12/c1-g4.md · its report docs/briefs/m12/c1-g4-report.md · docs/coding-guidelines.md (all, and its review checklist)
diff: the job's work is uncommitted: `git diff HEAD -- packages/connection` and the untracked files under those paths in `git status --short` (other uncommitted files are not this job's: ignore them).

do:
1 `tools/review.sh` and `tools/review.sh --strings`: copy every FAIL on the job's lines and every changed text; mark each text "allowed by brief item N" or "not in the brief".
2 The pure move: every member of the old game_host.dart is in a new file with the same body (compare `git show HEAD:packages/connection/lib/src/game_host.dart` with the new files); connection.dart exports the same names.
3 Each replaced wait (the report's table): does the new wait really wait for the event the test needs? Name any that could pass without the behaviour happening, or that could hang. Any `Future.delayed`, `settle` or sleep loop left in packages/connection/test.
4 The brief's do-list and rules, item by item: done, missing, or different (say how), each with file:line.
5 The report's claims (line counts, test counts): check them with `wc -l` and by counting `test(`/`testWidgets(` lines.

format (the report, at most 80 lines):
## Findings — most severe first, one line each: `must|should|nit file:line — what is wrong; the rule or brief item`
## Brief — n of m items done; one line per item not done or done differently
## Checked — what you verified, and how
No praise, no summary of what the code does. A clean review says "no findings" and lists what it checked.

check:
report: docs/briefs/m12/c1-g4-review-report.md
