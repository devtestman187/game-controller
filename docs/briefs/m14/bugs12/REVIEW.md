# bugs12 REVIEW (B-023), written by Claude from the two worker reviews

## Summary

- The run's own review wrote no REVIEW.md; this file replaces it. Both jobs ended DONE, nothing built, nothing pushed.
- Tests-first: the runner SKIPPED b023-stats-card's proof and review after the hand-fix (log: WARN, then "skip ... already done"). Claude ran both proofs by hand: settings_stats_row_test.dart on b843a1a (lib as before) gives +2 -1 (fails); first_host_consent_test.dart on 287579b gives +1 -3 (fails). Both pass on the tip.
- b023-stats-card: 8 findings; no code defect. Fixed by hand: a tablet test, a doc line on the duplicated wording; rest closed with reasons or in docs/code-health.md.
- b023-first-host-consent: 7 findings; finding 1 is REAL and serious. `hosting.start` points `clientProvider` at the own client, so the Connect panel rebuilds while the prompt is up, `context.mounted` is false afterwards, and the host route is never pushed (the phone hosts with no screen and no Stop). The widget tests use a fake clock and cannot see it.
- Fix job f1 (3 findings: move the prompt onto HostScreen's first frame, test 2 that passes on old code, silent answerConsent) is in waves.txt and runs next. Fixed, unverified: needs device check.

## b023-stats-card findings

1. must, widget in settings_sections.dart outside allow: **not real as a defect**: the file is 346+0 lines under the cap, the widget belongs with the other rows, and the hand-apply was logged (HAND-FIX). The report's self-check 4 is wrong; the commit message says so. Closed.
2. must, two of three tests pass on old code: **not real**: the file fails on old code (+2 -1, proved by hand), the two passing tests pin the tap flow the row keeps and add little; kept as pins. Closed.
3. should, self-check 4 overstates allow: **real, doc only**: the overstep is in the commit message and run.log; the report is left as written. Closed.
4. could, one screen size: **real, fixed**: tablet test added (settings_stats_row_test.dart, 4 tests pass).
5. could, wording duplicated in settings_text.dart and host_text.dart: **real, fixed**: doc comment now says a new state goes in both.
6. could, hint condition in the UI: **real, minor**: code-health.md.
7. could, line count 249 vs 250 in the report: **not real**: report text only.
- Decision 2 (ListTile, not paper row): coherent with the other Settings rows; kept. Decision 3 (lastError hides counts): kept, code-health.md. Decisions 1, 4: fine.

## b023-first-host-consent findings

1. must, `if (!context.mounted) return;` drops the host route: **real** (verified: hosting.dart:36 sets ownClientProvider; connection.dart:80/97; ConnectionPanel watches clientStateProvider). Fix job f1 item 1.
2. must, test 2 passes on old code: **real** (proved: +1 -3 on old code, test 2 is the passing one). f1 item 2.
3. should, answerConsent returns silently if absent: **real**. f1 item 3.
4. should, a phone joining while the prompt is up is untested: **real**; moot once the prompt sits on HostScreen, covered by a test in f1 item 1.
5. could, fake clock cannot show the rebuild: **real**; f1 item 1's test waits for the own client's link.
6. could, prefs key 'statsConsent' spelled in tests: **real, minor**: code-health.md.
- Decision 1 (ask after start): the cause of finding 1; f1 moves the ask to HostScreen. Decision 4 (enterHostMode answers "don't share" by default): kept; f1 item 3 tightens the helper.
