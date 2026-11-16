## Summary

**Verdict: small fixes.** Counts: 0 must, 1 should, 3 could.

The drop itself is correct and tested end to end (`live_stats_unmarked_test.dart` fails on the old code,
runner-confirmed), and both suites I ran are green: metrics 172, host 586.

The three that matter:
1. The `hasShareMarks` term in `_refreshCounts` (live_stats.dart:354) is not pinned by any test: once the
   id is in `skippedSessions`, the test sees `waiting` 0 without that term.
2. `!skipped.contains(f.id)` in `uploadNow`'s pending filter (live_stats.dart:317) is not pinned either:
   the second `uploadNow()` ends with the same counters with or without it.
3. The report's "comment trims" claim (unmarked-drop-report.md:14) is not in the diff.

## Findings

- **should** packages/party_host/lib/src/live_stats.dart:354 the `hasShareMarks` term in `waits` is not pinned by any test, because by the time the test reads `waiting` the unmarked id is already in `skippedSessions`, so the sibling `!skipped.contains` gives 0 without it → add a case with `uploader: null` (where `uploadNow` returns at :309) or with consent given after the files exist, asserting `waiting` stays 0 there.
- **could** packages/party_host/lib/src/live_stats.dart:317 `!skipped.contains(f.id)` in the pending filter is not pinned: the test's second `uploadNow()` re-visits the unmarked file and still ends with 1 upload and `waiting` 0 without the filter → make the test observable there (a prefs write counter in the fake, or a marked file re-written under the skipped id) so the filter is exercised.
- **could** packages/party_host/test/live_stats_unmarked_test.dart:15 `waitFor` measures real time (`DateTime.now`, `Future.delayed`), which coding-guidelines §9 forbids → use fake clocks once the timers are injectable, with the item already listed in code-health B-019 (3).
- **could** docs/briefs/m14/sentry2/unmarked-drop-report.md:14 the Summary says "the getter and comment trims keep it under the 380 cap", but the diff is +15/−4 with no comment line removed → say the file grew 11 lines to the cap and needs the split.

## Decisions to confirm

- Decision 1: with no uploader configured (`sessionUploaderProvider` is null by default, providers.dart:70), `uploadNow` returns at live_stats.dart:309, so no unmarked id is ever written to `skippedSessions` while `waiting` is 0 through `hasShareMarks`; the recorded and counted paths differ — confirm that is acceptable.
- Decision 4 (no log line): a dropped session leaves no trace in the host log or Diagnostics, and settings_text.dart:65 shows only "N waiting"; an adult cannot tell why nothing went up. The report leaves the UI note out of scope — confirm.
- Decision 2 (permanent skip): consent changes never revisit a dropped file; today a saved file cannot gain answers, so this is safe now but binds any future answer source.
- Hand-over flake: the suggestion to use `unorderedEquals` in live_stats_share_test.dart is unverified; my one full host run passed.

## Could not check

- `tools/check.sh format analyze` and `tools/review.sh` were not re-run (the report claims PASS; I ran the two suites only).
- The `live_stats_share_test` player-order flake: one full host run passed, so it did not reproduce.
- Whether `site/privacy.html` needs a line about old sessions never being sent: the job could not edit it.

## Commit message

Review: unmarked-drop wave 1 findings and test gaps

Read the unmarked-drop job against its brief, the coding guidelines and the review rules. The drop is
correct and covered end to end; two new branches (the `waiting` filter and the pending skip filter) are
not pinned by any test, and the new host test measures real time against §9. Also lists the report's
unsupported "comment trims" claim, three decisions for confirmation, and what this pass did not run.

## Status row

- **M14 sentry2 wave1 review:** reviewed — unmarked-drop is correct and its suites pass (metrics 172, host 586), findings written in wave1-review-report.md; open: the two untested branches (live_stats.dart:317, :354), a real-time new test, the live_stats.dart split at 380 lines, and confirming the decisions listed in the report.

## Delete

- none
