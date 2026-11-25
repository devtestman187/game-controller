# wave9 review report: f5, n8e5, n9e3

## Summary

Verdict: needs Claude (the churn revert discarded uncommitted files outside the jobs' folders).
Counts: 1 must, 1 should, 2 could.
1. **must**: `tools/churn.sh:58` runs `git checkout --` on the three `tv_test_app/windows/flutter` files that were dirty at session start; each job's `mine.sh` run reported "churn: reverted 3", and `git status` no longer lists them.
2. **should**: `controller_app/test/launch_home_test.dart:176` disposes the hosting test's host only on the success path.
3. **could**: `packages/party_host/lib/src/controls.dart:19` the new `otherLayout` field has no dartdoc.

## Findings

- **must** tools/churn.sh:58 `churn_revert` runs `git checkout --` on every dirty path matching the generated-churn regex, so the three uncommitted edits to `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h` and `generated_plugins.cmake` (all shown `M` in the session's git status) are gone, and the f5, n8e5 and n9e3 runs each triggered it → ask the owner whether those edits matter (git cannot restore them), and make `churn_revert` skip any path that was already dirty before the job started.
- **should** controller_app/test/launch_home_test.dart:176 `await tester.runAsync(host.dispose);` is the last line of "a connect that fails on the pad while this phone hosts does not open Home", so an `expect` at about line 168 or 174 that fails leaves the host running → wrap the body in try/finally, or register the dispose with `addTearDown`, so it runs on failure too.
- **could** packages/party_host/lib/src/controls.dart:19 `final GameLayoutMessage? otherLayout;` has no dartdoc, while the brief rule asks for one on every public member → add a one-line dartdoc on the field; `only` and `layout` (lines 17-18) lack one as well, so one edit can cover all three.
- **could** controller_app/test/haptics_test.dart:87 the test name "with haptics off, TV events play nothing" still says "TV", while the diagnostics line it relates to now says "screen events" (diagnostics_screen.dart:299) → rename in a later job; it is a test name, not pinned UI text, so this is optional.

Checked and clean: every new test names its rule; the n9e3 layout labels hold (`pause_menu_widgets.dart:6` gives B "Resume", so the new test 1 fails on the old code by reading); `_layoutFor` (controller_menus.dart:176-183) keeps the per-player cache; `controls.dart` is 52 lines and `controller_menus.dart` 311 (under 340); `diagnostics_screen.dart` 363 lines; no added line is over 120 columns; the four n8e5 strings in the inventory's CHANGE rows for these two UI files are all applied; the f5 hosting guard exists (`launch_route.dart:42`).

## Decisions to confirm

- n9e3: `otherLayout` is a new field on the public `Controls.menus` rather than a second claim (`controls.dart:19`, `controller_menus.dart:181`). It was the worker's call; confirm the API shape.
- n9e3: during a pause a non-resumer's B keeps the menu's "Back" label (`pause_menu_widgets.dart:58`). This follows the owner's "keep normal label" choice, but it is a device-check item in the report.
- n8e5: "TV" became "screen" in the diagnostics report (`diagnostics_screen.dart:293, 299, 306`) and in the demo line (`controller_parts.dart:143`). Owner decision 7 covers generic display-device text; confirm that a support report should also say "screen".
- f5: the hosting test builds its host with `hostingProvider.notifier.start(playsHere: false)` (`launch_home_test.dart:166`) rather than the route `host_mode_test.dart` uses. The brief allowed either; it avoids `pumpHostApp`.

## Could not check

- No tests, format or analyze were run by me: this job is read-only, and `tools/mine.sh` runs `churn_revert` again (finding 1).
- f5: the new expectations were not run against the base (the f5 report says so). I could not confirm by reading that the dropped-link positive control (`launch_home_test.dart`, the first `pumpApp` in that test) passes on the base.
- n9e3: test 2 and test 3 pass on the old code by design (they are guards); only test 1 is the new behaviour, and it fails on the old code by reading, not by a run.
- n9e3 reports `OK 4 tests packages/party_host`, but `pause_resume_label_test.dart` has 3 tests; the fourth test is not identified in the report or in the run output I have.

## Commit message — a draft

docs: wave9 review report for f5, n8e5 and n9e3

Review of the wave 9 jobs against the guidelines, the review rules and their briefs.
Finds that tools/churn.sh discarded three uncommitted tv_test_app edits during the
jobs' mine.sh runs (must), and a hosting test that leaks its host on failure (should).
Only the report file is added; no code changes.

## Status row

wave9 review (f5, n8e5, n9e3): needs Claude. Done: read all three briefs, reports and diff; 1 must (churn revert discarded 3 uncommitted tv_test_app files), 1 should (hosting test leaks host on failure), 2 could. Open: owner decision on the discarded files; churn.sh fix; the hosting-test cleanup; no test run by this review.

## Delete

- none
