# m12 c2, G4 — review

Read-only. `tools/review.sh`: 0 fail, 2 note (both on this job's files, both the tool's member-scan quirk, as the
report says); no FAIL to copy. `tools/review.sh --strings`: 0 removed, 0 added — no changed text to mark.

## Findings

- should controller_app/test/support/fakes.dart:170 — `SlowCapsHaptics` has one user, `controller_screen_test.dart:63`, and the job's own rule sent `uprightSteering`/`lastTiltX` to their only user; review brief item 3, "the support files only hold what several files share".
- nit docs/briefs/m12/c2-g4-report.md:154 — quotes `strings: 0 removed, 0 added, 22 unchanged or moved`; today `tools/review.sh --strings` prints `0 removed, 0 added, 29 unchanged or moved` (same 0/0, the total is not reproducible; the tool counts every in-scope changed file in the working tree, other jobs' files included).
- nit docs/briefs/m12/c2-g4-report.md:25 — the `connection.dart` row of the move map omits `discoveryStateProvider`, `clientStateProvider`, `connectionActionsProvider`, `outagesProvider`, all of which are in `providers/connection.dart`; brief item 4 asks for the move map.
- nit docs/briefs/m12/c2-g4-report.md:56 — "the same nine `ref.listen`s"; `providers/metrics.dart:37-47` has eight (seven setters plus `clientStateProvider`).
- nit controller_app/lib/src/providers/connection.dart:9 — imports `../providers.dart`, the barrel that exports it (also `haptics.dart:7`, `game_feedback.dart:4`): a file cycle, already raised as report question 2.
- nit controller_app/lib/src/providers/connection.dart:56 — the comment was reworded ("The model, OS and haptics go into the next hello once known" → "Puts the model, OS and haptics into the next hello once they are known"), a text edit outside item 2's comment; brief rules, "pure move apart from …".

## Brief — 4 of 4 do items done

- Item 1, done differently: the providers are split as asked (7 files, 34–184 lines, all ≤300; `_addDeviceDetails`
  and `_updateMetrics` the named private functions), but `providers.dart` is not only the export barrel the brief
  allows: it keeps the log buffer (39 lines) for the `debugPrint` leftover (report question 1). No provider is over
  60 lines; the tool's two `func` notes are its scan past `});`, which I confirmed on `device.dart:24` (ends 28).
- Item 4, done with the two numbers above: line counts and the 262 count are right, the `--strings` total and the
  connection row of the map are not.
- Items 2 and 3 done as written: the catch comment is at `connection.dart:63-66` with the reason; 11 test files of
  45–241 lines plus `test/support/`, every test name and body kept, checked one by one against `HEAD`.
- Extra, reported as questions and inside `--allow`: `_at` → `at` in `support/pump_app.dart` (a shared helper cannot
  stay private) and the one-line import change in `test/phone_metrics_test.dart`. Neither changes a test.

## Checked

- Providers, name/type/body against `git show HEAD:controller_app/lib/src/providers.dart`: all 53 old top-level
  members present once (11 device, 16 connection, 5 haptics, 4 feedback, 9 game feedback, 2 pad, 3 metrics, 3 log);
  bodies read line by line against the old file — only `clientProvider`'s IIFE → `_addDeviceDetails` and
  `phoneMetricsProvider`'s local `update` → `_updateMetrics` differ, and both keep the old statements and order.
  `flutter analyze` on `controller_app`: "No issues found", so every import elsewhere resolves.
- Tests: old `widget_test.dart` 70 `test(`/`testWidgets(` lines, new 11 files 70, no duplicate declaration lines;
  the two loops (`game_controls_test.dart:72` ×3, `gyro_mode_test.dart:121` ×2) give 73. Running the 11 files:
  "+73: All tests passed!"; the whole suite: "+262: All tests passed!".
- Report's numbers by `wc -l`: providers.dart 39, connection 184, device 79, feedback 34, game_feedback 82,
  haptics 43, metrics 75, pad 145 (sum 681); fakes 215, pump_app 117; test files 99/60/86/79/139/195/135/119/180/45/
  241 (sum 1710). Per-file test counts 6/4/4/3/7/10/9/7/7/2/14 = 73. 262 = 73 + 189 across the seven other files.
- Support files: `tv`, `connected`, `TestApp`, `pumpApp`, `settle`, `at`, `openSettings`, `closeSettings`,
  `scrollTo`, `tapVisible`, the fakes — same text as the old helpers except `_at` → `at`.
- `git status`: this job's paths only (`lib/src/providers.dart`, the 7 new files, the 11 test files, `support/`,
  the `phone_metrics_test.dart` line, `widget_test.dart` deleted). `lib/src/log2.tmp` is gone. No pubspec change.
  `dart format --output=none --set-exit-if-changed controller_app/{lib,test}`: 56 files, 0 changed.
- Not checkable now: the report's "335 with `widget_test.dart` still on disk" — that file is already deleted.
