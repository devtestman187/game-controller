# Worker rules (every brief names this file first in `read:`)

Read this before the brief's own `do:` items. A brief only repeats a rule here when the job bends it.

- **decide:** low-usage mode, never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job cannot be done; then say why under "Blocked".
- **Report:** start with `## Summary` (at most 30 lines, within the first 40 lines): what changed, the test counts you saw, decisions. End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it. A fix whose cause is not measured says "Fixed, unverified: needs device check".
- **Self-check:** docs/review-rules.md part A, items 1-6, one line each in the report with the test that shows it (item 6: every look, menu and TV).
- **Tests:** new tests go in a NEW test file and must fail on the code as it was (the runner proves it and stops otherwise); a pure refactor or docs job says `tests-first: exempt <reason>` in its header. Await every async side effect (upload, save, timer) before teardown; in party_host use settleUploads from test/stats_test_support.dart. While working use `tools/mine.sh` (it runs the touched tests) plus the tests named in `read:`; the full suite runs once, at the end. UI sizes are tested under every look (see review-rules part A item 6).
- **Rules:** aim for 80-120 turns · no lib file you touch ends over 380 lines (split it; the runner stops otherwise) · tests first · write only inside `allow:` · stage nothing yourself · never `git add -A` · tools/review.sh: no FAIL on your lines.
- **Bash:** the one check is `tools/mine.sh` (format, analyze, touched tests, churn revert; failures only); never raw dart/flutter or a partial check.sh. Allow-listed by prefix: `tools/check.sh <suite>`, `tools/mine.sh`, `flutter test <file>`, `dart format`, `dart analyze`; no absolute paths, no `bash -c`.
