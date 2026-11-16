# Review of stats-bug (M14 sentry1)

## Summary

`small fixes`

Counts: 1 must, 2 should, 3 could.

1. `stats_crash_button_test.dart:23` passes on the old code — the "no crash button" guard the report
   itself names, so the report's "all 12 fail on the old code" is wrong two lines above it.
2. Retry has no in-flight guard (`stats_screen.dart:114`): two quick presses start two reads whose
   results race, and a late failure can put the error card back over a table a newer read showed.
3. `CrashSharingButton` is public although only `stats_screen.dart:100` uses it, and the library
   exports `src/ui/stats_screen.dart`, so it joins the package's public surface.

Read: the whole diff `d7f8a02..2e8c28c` (8 files). Ran: `flutter test` on
`stats_screen_failure_test.dart` + `stats_crash_button_test.dart` (12 pass), then with
`stats_screen_test.dart` + `screen_fit_test.dart` (33 pass); `flutter analyze` clean;
`dart format --set-exit-if-changed` on the 4 lib files and 2 test files: 0 changed.
The job's lib files are 219, 236, 373 and 30 lines; every changed file is inside its `allow:`.

## Findings

- **must** packages/party_host/test/stats_crash_button_test.dart:23 "no crash button where this build cannot send reports" passes on the code before this job (the old screen has no `statsCrash` key and does have `statsSharing`), so it proves nothing about the new behaviour → keep it as a guard but say in the report that the file's tests-first result is 6 of 7, not 7 of 7.
- **should** docs/briefs/m14/sentry1/stats-bug-report.md:24 the report claims "all 12 fail on the old code" while line 25 gives "5 and 6 of 7 failed", i.e. 11 of 12 → print the true count and name the one that passes.
- **should** packages/party_host/lib/src/ui/stats_screen.dart:114 `onRetry: () => unawaited(_load())` starts a read with no "read in flight" flag and leaves the button enabled, so two presses run two `sessions()` reads whose completions race (a failure of the slower one replaces a table the faster one drew) → ignore a Retry while a read is running, via a `_reading` flag set in `_load()` and cleared when it ends.
- **should** packages/party_host/lib/src/ui/stats_screen_widgets.dart:24 `CrashSharingButton` is public although the only use is `stats_screen.dart:100` in the same library, and `party_host.dart:96` exports `src/ui/stats_screen.dart`, so it is added to the package's public surface where its neighbour `_SharingButton` is private → make it private (or name the outside caller the brief meant).
- **could** docs/briefs/m14/sentry1/stats-bug-report.md:41 the icon decision says "the cloud pair on Sharing does the same", but `_SharingButton` draws `Icons.cloud_upload_outlined` when on (stats_screen_widgets.dart:15) and `CrashSharingButton` draws the solid `Icons.bug_report` when on (stats_screen_widgets.dart:37), so the two buttons read differently → either match the Sharing convention (outlined when on) or reword the decision to say the pair differs on purpose.
- **could** docs/briefs/m14/sentry1/stats-bug-report.md:1 the report starts with a `#` title and its `## Summary` spans lines 3–33 (31 lines), where its brief asks the report to start with `## Summary` in at most 30 lines → drop the title and one line.

## Decisions to confirm

- Decision 4 (Retry is not autofocused): the test reaches it with `LogicalKeyboardKey.tab` sent straight to the binding; on a TV the key has to come through `ControllerMenus`, so confirm a real remote's Tab lands on Retry with Export focused, or ask for a different focus rule.
- Decision 6 (Retry keeps the error card, no spinner): that is also what leaves the button pressable during a read (finding 3); confirm "no spinner flash" is worth a guard rather than a spinner or a disabled Retry.
- Decision 3 (solid bug when on): differs from the Sharing button beside it (finding 5); confirm the look before a device build.
- Decision 5 (a failed read also hides the live session): the live session's table disappears with the saved ones until a retry works; confirm an adult can accept that.

## Could not check

- Which individual new tests fail on the old code: nothing here was run against `d7f8a02` (no checkout allowed); `docs/briefs/m14/sentry1/run.log:39-40` only records the two files' tests-first result.
- The crash button and the error card on a real build with a DSN (no DSN here, and `crashAvailableProvider` is false everywhere in local runs) and their fonts on a TV panel.
- The report's full-suite counts (`tools/check.sh host phone`: 566 and 505) and its `tools/review.sh` "0 fail, 1 note": neither was run in this review.
- `run.log:36`'s dropped `site/shots/*.png` churn: whether the new tests regenerate them or an earlier tool did.

## Commit message

Fix the Retry race, the public crash button, and the tests-first count

`stats_screen.dart` starts a read per Retry press with no in-flight flag,
so two quick presses could let a slow failure cover a newer table; a
`_reading` flag now ignores a Retry until the read ends.
`CrashSharingButton` becomes `_CrashSharingButton`: the only user is the
same library, and `party_host.dart` exports it.
`stats_crash_button_test.dart:23` passes on the old code: the review
report and `stats-bug-report.md` now say 11 of 12 fail, not 12, and the
icon decision names the difference from the Sharing button.

## Status row

- **M14 sentry1 stats-bug review (Nov 16, 2026):** `small fixes` — 1 must (one new test passes on the old code), 2 should (unguarded Retry race, public `CrashSharingButton`), 3 could (report claims/counts); 12 new tests and 33 with the Stats and fit files pass, analyze clean. Open: the fixes above, then the device check of the crash button and the error card.

## Delete

- none
