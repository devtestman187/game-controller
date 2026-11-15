# Review of b023-stats-card (B-023 host Stats row)

## Summary

**needs Claude.** must 2, should 1, could 4.
1. The new `_HostStatsStatus` sits in `controller_app/lib/src/ui/settings_sections.dart:325`, a file outside the brief's
   `allow:`; the runner had to hand-apply the commit (`docs/briefs/m14/bugs12/run.log:7`), and the report's self-check 4
   (`b023-stats-card-report.md:46`) says every lib/test file was allowed.
2. Two of the three new tests (`settings_stats_row_test.dart:55`, `:68`) pass on the old code and repeat
   `host_stats_test.dart:50-80`, so they guard nothing the change added.
3. The row is exercised at one screen size only (`settings_stats_row_test.dart:14`), although a second subtitle line
   changes a `ListTile`'s height and Settings goes two-column on a tablet.

## Findings

- **must** controller_app/lib/src/ui/settings_sections.dart:325 `_HostStatsStatus` is added to a file outside the brief's `allow:` (which lists settings_screen.dart, settings_text.dart, controller_app/test, packages/party_host/test) → move the 26-line widget into controller_app/lib/src/ui/settings_screen.dart, which then ends at 373 lines, still under the brief's 380.
- **must** controller_app/test/settings_stats_row_test.dart:55 and :68 both tap tests pass on the old code (the report says so) and repeat controller_app/test/host_stats_test.dart:50-80, so only test 1 would catch this bug → merge them into a test that also asserts the new line (e.g. after answering "yes" the row reads "Sharing hosted sessions: no upload set up"), or drop them and keep host_stats_test.dart.
- **should** docs/briefs/m14/bugs12/b023-stats-card-report.md:46 self-check 4 states every lib/test file was in `allow:`, but the diff adds controller_app/lib/src/ui/settings_sections.dart → state the overstep (or remove it by moving the widget) so the self-check matches the diff.
- **could** controller_app/test/settings_stats_row_test.dart:14 the row is tested at one screen size only, while the two-line subtitle changes tile height and Settings is two-column at 700 px → add a `pumpApp(tester, tablet: true)` case asserting the status and hint still show.
- **could** packages/party_host/lib/src/text/settings_text.dart:59 the five sharing states are now worded twice (also packages/party_host/lib/src/text/host_text.dart:295), so a new state must be added in both → say so in the doc comments or build one wording on the other.
- **could** controller_app/lib/src/ui/settings_sections.dart:338 the `state.consent == null` hint condition is state logic in the UI, which the brief's item 2 asked to keep in the text → return a nullable hint from settings_text.dart (e.g. `SettingsText.hostShareHint(StatsState)`) and let the widget show `Text` or nothing.
- **could** docs/briefs/m14/bugs12/b023-stats-card-report.md:32 the line counts are 347, 346 and 250; `settings_text.dart` has 250 lines, not 249 → correct the number.

## Decisions to confirm

1. Decision 2 (a `ListTile` with a chevron, not connect_screen's paper-and-ink-edge row): the brief said "use the connect_screen look"; every other Settings navigation row is a `ListTile`, so this is coherent, but the owner may have expected the paper row.
2. Decision 3 (`lastError` before the uploaded/waiting counts): after one failed try the row stops showing "3 uploaded, 2 waiting" and never says it retries, while `host_text.dart:301` keeps the counts and adds "(last try failed, trying again later)"; confirm the row should hide progress on an error.
3. Decision 4 (widget placed in settings_sections.dart to stay under 380 lines): settings_screen.dart would end at 373 with it, so the cap did not force the move, and that file was not in `allow:`.
4. Decision 1 (bold ink, no accent colour): the bold is asserted in the test but never seen at any size; a colour would only change `_HostStatsStatus`.

## Could not check

- The quoted `tools/check.sh format analyze host phone` run (host 482, phone 478): I re-ran only format, `dart analyze` on controller_app and the four related test files (see Checks below).
- How the row looks at the smallest phone and at tablet width (no test at those sizes, no device).
- The worker's own text: the commit was applied by hand by the runner, so what the worker wrote and what was committed cannot be separated.
- `docs/briefs/m14/bugs12/run-findings.md` does not exist, so there are no third-party "passes on the old code" entries.

## Files changed

- `docs/briefs/m14/bugs12/b023-stats-card-review-report.md` — this review.

## Computed test values / checks

- `flutter test test/settings_stats_row_test.dart test/host_stats_test.dart` — 9 tests, all pass.
- `flutter test test/host_stats_test.dart test/phone_host_stats_lifecycle_test.dart test/settings_test.dart` — 23 tests, all pass (matches the report's "23 tests together").
- `dart format --output=none --set-exit-if-changed` on the four changed files — 4 files, 0 changed.
- `dart analyze` in controller_app — no issues.
- Line counts: settings_screen.dart 347, settings_sections.dart 346, settings_text.dart 250; 347 + the 26-line widget = 373.
- Old-code pass check is the report's own admission; not re-proved (no checkout of the parent tree).

## Questions

1. Move `_HostStatsStatus` into settings_screen.dart (373 lines), or widen `allow:` to settings_sections.dart in a follow-up brief?
2. Should the row keep the uploaded/waiting counts when `lastError` is set, as `HostText.statusLine` does?

## Commit message

Review B-023 host Stats row: one file outside allow, two weak tests

The change itself does what the brief asked (five status lines, a bold
Tap to choose hint before the answer, a chevron, the same tap flow), but
it adds the new widget to settings_sections.dart, which the brief's
allow: did not list, and two of its three tests pass on the old code.
The report's self-check says all lib/test files were allowed, and its
line count for settings_text.dart is one short. Those, plus three smaller
notes on size coverage and the duplicated state wording, are the findings.

## Status row

- **B-023 stats card review:** done; verdict needs Claude (must: the row widget lives in a file outside allow; must: two new tests pass on the old code); open: the fix job and the owner's device check.

## Delete

- none
