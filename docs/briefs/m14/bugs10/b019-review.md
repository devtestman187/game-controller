job: review of jobs b019-1-stats-core and b019-2-phone-wiring (read-only): check what they committed against the coding guidelines, the review rules and their briefs; write findings only
pub: no
stop: after it.
read: docs/briefs/m14/bugs10/b019-1-stats-core.md · docs/briefs/m14/bugs10/b019-2-phone-wiring.md · their two reports (Summary and Hand-over only) · docs/coding-guidelines.md · docs/review-rules.md · docs/briefs/m14/bugs10/run-findings.md if it exists · the change: `git log --oneline -8 -- packages/party_host controller_app/lib/src/host` then `git diff` of the two job commits if allowed, else read packages/party_host/lib/src/live_stats.dart, packages/party_host/test/live_stats_lifecycle_test.dart, controller_app/lib/src/host/phone_host.dart, controller_app/test/phone_host_stats_lifecycle_test.dart
decide: never stop for a question. You change no code and no document except your report. If something cannot be judged from what you can read, say so in one line under "Could not check".

Second pair of eyes; Claude reads only your Summary, then verifies the findings it acts on, so be exact and short.
1 Guidelines: sizes, names, leftovers, timers and clocks.
2 Review rules: kept state start and end; a TV host with remote players keeps its session open as before; a session ended by pause() then a later join starts a fresh one; hidden/inactive never end a session; dispose order; unawaited errors.
3 The briefs: every item done, nothing unasked built, every Decision safe.
4 Tests: each new behaviour has a test that fails without it (run-findings.md entries count); no test asserts nothing.
5 Docs the jobs touched say what the code does.
in the report, in this order: `## Summary` (at most 12 lines: verdict `clean`, `small fixes` or `needs Claude`; counts by severity; the three that matter most) · `## Findings` (one bullet each, shape `- **<must|should|could>** <file>:<line> <what is wrong> → <the fix>`) · `## Decisions to confirm` · `## Could not check`.
rules: change nothing but your report · no praise · every finding names a file and line you read · install nothing · leave no scratch file behind
allow: docs/briefs/m14/bugs10/b019-review-report.md
report: docs/briefs/m14/bugs10/b019-review-report.md
