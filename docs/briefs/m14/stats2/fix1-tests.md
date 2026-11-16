job: M14 stats2 fix1-tests: close REVIEW.md findings 1 and 9 (test hardening, no lib change)
stop: after it.
read: docs/briefs/m14/stats2/REVIEW.md (findings 1 and 9) · packages/metrics/test/csv_build_test.dart · packages/metrics/test/csv_app_version_test.dart (~43) · packages/metrics/test/round_offset_test.dart (~84)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

do:
1 Finding 1: in csv_build_test.dart (lines ~73 and ~89) the plain-version case and the ten-digit/letter cases pass on the old code. Fold the plain case into the "+dev" test, and make the ten-digit/letter/empty cases assert something the old code failed (for example that the app is the bare version and no build is exported, so old code that kept "0.14.0+65a" in app fails). Each remaining test must fail on the old code.
2 Finding 9: rename the two tests whose names say the header ends with host_app,app or with the start offset to the new last columns (host_build,build and start_s,host_build).
tests-first: exempt test-only hardening of existing code.
rules: aim for 40-80 turns · write only inside allow: · stage nothing yourself, never git add -A · tools/review.sh: no FAIL on your lines.
allow: packages/metrics/test/csv_build_test.dart · packages/metrics/test/csv_app_version_test.dart · packages/metrics/test/round_offset_test.dart · docs/briefs/m14/stats2/fix1-tests-report.md
check: format analyze metrics
report: docs/briefs/m14/stats2/fix1-tests-report.md
in the report: start with "## Summary" (at most 30 lines, in the first 40): what changed, decisions. End with "## Hand-over" (at most 20 lines).
