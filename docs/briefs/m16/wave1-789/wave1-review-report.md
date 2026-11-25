## Summary

Verdict: needs Claude
Counts: 3 must, 4 should, 1 could
1. The party_host volume test passes on the old code (run-findings; run.log 18:24:03), and its tests-first exemption rests on a Slider default that the job did not verify.
2. Both new test files use `// ignore: deprecated_member_use`, which the rules forbid.
3. The settings, dialog and volume checks compare against a whole-tree `contains` or a suffix `endsWith`, not the per-slider equality the brief asked for, and the volume test has no TV look.

## Findings

- **must** packages/party_host/test/volume_semantics_test.dart:46 The volume test passes on the old code (run.log 18:24:03, run-findings line 1), and the brief's exemption assumes the default Slider semantics already read a percentage on a 0-100 scale, which nobody checked → write it to fail on the old code by asserting `tester.getSemantics(find.byKey(Key(key))).value` equals `_percentShownAbove(...)` per key, or have the owner withdraw the exemption.
- **must** controller_app/test/slider_semantics_test.dart:40 `// ignore: deprecated_member_use` breaks the rule against analyzer ignores → reach the semantics root without the deprecated member, or read each node through `tester.getSemantics`.
- **must** packages/party_host/test/volume_semantics_test.dart:21 `// ignore: deprecated_member_use` breaks the rule against analyzer ignores → same fix as the controller test's line 40.
- **should** controller_app/test/slider_semantics_test.dart:72 The settings check uses `contains` over the whole semantics tree, so another slider with the same text can satisfy it; the brief asked for a per-slider equality via `tester.getSemantics(find.byKey(key)).value` → assert that equality for each key.
- **should** controller_app/test/slider_semantics_test.dart:92 `endsWith(...)` is a suffix match, and an empty semantics value matches every line (also at line 110) → compare with `equals` against the value the slider reports.
- **should** packages/party_host/test/volume_semantics_test.dart:39 The volume rows are tested only in the Sunny and Night palettes, never the TV look, and the file does not use `test/support/all_looks.dart` → run the case through the all-looks helper so both the menu look and the TV look are covered.
- **should** docs/briefs/m16/wave1-789/n9c-report.md:1 The report gives no review-rule part A self-check (host setups, kept state, combinations, folder, stop, looks) → add the six one-line answers, e.g. "A6 looks: sunny and night in slider_semantics_test.dart; TV look not tested for volume rows".
- **could** packages/party_host/test/volume_semantics_test.dart:11 `_spokenValues` and the row helpers repeat the ones at controller_app/test/slider_semantics_test.dart:30-52 → move them to one test support file in a later job, when the next slider test needs them.

## Decisions to confirm

- The tests-first exemption for packages/party_host/test/volume_semantics_test.dart (brief line 5): it means the volume test is not shown to fail on the old code; the owner or Claude should accept that or require the fix above.
- The driver hand-fixed the test helper and committed n9c by hand (run.log lines 35-36, 50): the code is in the six allowed files, but the worker's own tests-first run never happened and the report is the driver's note, not the worker's.
- Dialog sliders read the whole visible line (for example "Gyro sensitivity: 50%") rather than the value alone: this follows the brief's `shown` text, but confirm the screen-reader wording is wanted.

## Could not check

- The Flutter SDK's default `Slider` semantics value: the SDK source was not readable without a permission prompt, so the exempt reason is unverified.
- The tests were not run: this review is read-only and the runner's evidence (run.log) was used instead.
- Whether the gyro and stick `(_) => shown` closures stay current after a drag: not traced through the dialog's rebuild path.
