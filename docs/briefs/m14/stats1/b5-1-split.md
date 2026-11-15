job: M14 stats1 b5-1-split: make room in metrics session.dart (phase 1 of 2 for the round start offset)
stop: after it. No behaviour change, no start offset yet.
read: packages/metrics/lib/src/session.dart (371 lines; the lib cap is 380 and the next job adds about 15 lines) · packages/metrics/lib/metrics.dart (exports) · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

do:
1 Move self-contained helpers out of session.dart into a new file in packages/metrics/lib/src/ (for example session_clean.dart): the string/tag cleaning (_clean, _cleanDevice, the _technical, _tagPattern and _roundTagPattern patterns, _roundTags, maxRoundTags) or whatever else is separable. Keep every public name and export working (re-export from the same library, or `part`), so no other package changes. Aim for session.dart at most 330 lines.
2 Pure move: no logic or text changes. Tests stay as they are and must pass unchanged.
3 Report: the line counts before and after and a move map.
tests-first: exempt pure refactor (a move), no behaviour added.
rules: aim for 40-80 turns · no lib file you touch may end over 380 lines · write only inside allow: · stage nothing yourself, never git add -A · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/lib/src/session.dart · packages/metrics/lib/src/session_clean.dart · packages/metrics/lib/metrics.dart · docs/briefs/m14/stats1/b5-1-split-report.md
check: format analyze metrics host
report: docs/briefs/m14/stats1/b5-1-split-report.md
in the report: start with "## Summary" (at most 30 lines): what moved, line counts, decisions. End with "## Hand-over" (at most 20 lines).
