job: M14 stats1 fix3-docs: close the run review's document and code-health findings (REVIEW.md findings 2, 7, 8, 9-14)
stop: after it. No behaviour change.
read: docs/briefs/m14/stats1/REVIEW.md (the findings named in the do list) · packages/metrics/lib/src/report_rounds.dart (roundsCsvHeader) · docs/dev-tools.md (~343) · docs/design/m12-report.md (~22) · docs/briefs/m14/STATUS.md (top) · docs/code-health.md (the M14 stats1 section) · docs/briefs/m14/stats1/b5-1-split-report.md (~23, ~41) · packages/metrics/test/csv_app_comma_test.dart (line 5)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

do:
1 Finding 2: dev-tools.md and m12-report.md give the rounds CSV as 17 columns ending fps,start_s (read the header in the code, do not guess); add the rule that app cells never quote and a comma becomes a semicolon (finding 12 closed by this note).
2 Finding 7: one line in docs/briefs/m14/STATUS.md after bugs10: M14 stats1 (Nov 15, committed, unpushed, nothing built): app columns, winner/draw/players and robot wins, per-round frames and fps, session.dart split, round start offset start_s, CSV docs; open: one device round for b4 level_ tag and b6 Windows hz/tags ("Fixed, unverified: needs device check"), no table reads the new columns.
3 Finding 8 (with 5, 9, 10, 11): code-health.md rows, each "when touched" unless said: session.dart 340 lines over the 330 aim; roundEnded 9 parameters and 41-line body (a RoundEnd value object); session_clean.dart name (HostType lives there; rename to session_format.dart); session_clean.dart bare numbers 16, 40, 2000 (name them); the two unread round columns (before a milestone).
4 Finding 13: fix the doc comment in csv_app_comma_test.dart (the symbol is technicalPattern in session_clean.dart). Finding 14: b5-1-split-report.md says six references and names all three new dartdocs, no "verbatim".
tests-first: exempt docs and comments only, no behaviour.
rules: aim for 40-80 turns · write only inside allow: · stage nothing yourself, never git add -A · tools/review.sh: no FAIL on your lines.
allow: docs/dev-tools.md · docs/design/m12-report.md · docs/briefs/m14/STATUS.md · docs/code-health.md · docs/briefs/m14/stats1/b5-1-split-report.md · packages/metrics/test/csv_app_comma_test.dart · docs/briefs/m14/stats1/fix3-docs-report.md
check: format analyze metrics
report: docs/briefs/m14/stats1/fix3-docs-report.md
in the report: start with "## Summary" (at most 30 lines): what changed, decisions. End with "## Hand-over" (at most 20 lines).
