job: M14 stats2 fix4-docs: close REVIEW.md findings 4, 6, 11, 12, 13, 14 (docs and comments only)
stop: after it. No behaviour change.
read: docs/briefs/m14/stats2/REVIEW.md (findings 4, 6, 11-14) · packages/metrics/lib/src/session_clean.dart (~46) · docs/dev-tools.md (~344) · docs/briefs/m14/STATUS.md (~14) · docs/design/m12-report.md (~25) · docs/code-health.md (~123) · docs/decisions.md (~82)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

do:
1 Finding 4: the session_clean.dart doc and dev-tools.md say a local build sends "0.14.0+dev"; say instead that a local build sends the bare version and a tail that is not 1-9 digits is dropped.
2 Finding 11: the STATUS.md stats2 line: drop the trailing "; nothing built". Finding 12: m12-report.md section 2 sizes: session.dart 361, host_service.dart 369 (past its 360 budget: tech debt).
3 Findings 6 and 13: code-health.md, an "M14 stats2" section, rows (rec. "when touched"): the "+build" rule lives in three places (app_info, host_identity, session_clean); HostIdentity reads the build from the display versionLabel instead of a value the app passes (needs phone-host wiring in controller_app/lib/src/host/, pending bugs12); host_service.dart 369 lines, split next time.
4 Finding 14: decisions.md one row: the stats app string is "version+build" (digits only, 1-9; tail dropped otherwise; old apps send the bare version; the summary keeps app and build apart).
tests-first: exempt docs and comments only.
rules: aim for 40-80 turns · write only inside allow: · stage nothing yourself, never git add -A.
allow: packages/metrics/lib/src/session_clean.dart · docs/dev-tools.md · docs/briefs/m14/STATUS.md · docs/design/m12-report.md · docs/code-health.md · docs/decisions.md · docs/briefs/m14/stats2/fix4-docs-report.md
check: format analyze metrics
report: docs/briefs/m14/stats2/fix4-docs-report.md
in the report: start with "## Summary" (at most 30 lines, in the first 40): what changed, decisions. End with "## Hand-over" (at most 20 lines).
