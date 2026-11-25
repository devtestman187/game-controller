# n8b0 report: host start becomes a function Home can call

## Summary

Behaviour-free extract. The "Host a game" path now calls `launchHosting` (new file) instead of holding the start and the route inline.

- `controller_app/lib/src/host/host_launch.dart` (new, 25 lines): `launchHosting(BuildContext, WidgetRef, HostChoice)` reads `hostingProvider.notifier`, calls `start(playsHere: choice == HostChoice.onPhone)`, then pushes `HostScreen(host: host, choice: choice)` through a `MaterialPageRoute` and awaits it. The ordering comments (m12 bug 1108a rule D, B-023) moved with the code.
- `controller_app/lib/src/ui/connect_panels.dart` (320 lines): the `hostGame` button still awaits `showHostStartSheet`, returns if the choice is null or the context is unmounted, then calls `launchHosting`. Imports: `host_screen.dart` and `hosting.dart` removed (no longer used here), `host_launch.dart` added. Keys and strings unchanged.

Decisions:
- The notifier read moved from before the sheet to after the mounted check (inside `launchHosting`). This is safe because `context.mounted` is checked first, and `ref` is valid while the element is mounted. The old comment "Read before the dialog" no longer applies and was replaced by "After the dialog this widget may be gone: check before launching."
- `launchHosting` has no `await` before the `Navigator` use, so no `use_build_context_synchronously` gap.
- No test file changed (brief: none expected). Tests-first exempt: behaviour-free extract.

Test counts seen in this job:
- `tools/mine.sh`: format OK (2 files formatted), analyze OK, 1 touched test run: "OK 1 tests controller_app".
- `flutter test controller_app/test/host_mode_test.dart controller_app/test/host_start_log_test.dart`: 0 passed, 2 failed, both in `setUpAll`, before any test body ran. Cause in the output: `Unable to load asset: "packages/puzzle_game/puzzles/index.json"` from `controller_app/test/support/host_app.dart:33` (`loadPuzzles`). The file exists at `packages/puzzle_game/puzzles/index.json`, so the asset is not declared or bundled for the test run. My change does not touch assets or `loadPuzzles`. I did not confirm that the failure also happens on the unmodified code, because that needs a checkout I was not allowed to make. The flow tests therefore did NOT run in a meaningful way here.
- `dart analyze` on the two changed files: No issues found.

Self-check (review-rules part A):
1. Host setups: the flow is the same for every host (TV, phone "Play on this phone" → `onPhone`, phone "Show on this device" → `onDevice`). Covered by the unchanged `host_mode_test` (could not run here, see above).
2. Kept state: none added or removed; `hostingProvider` start is called exactly as before.
3. Combinations: no new state, so no new combination. Behaviour-free.
4. Stayed inside `allow:`; no other file edited by me.
5. Nothing stopped.
6. Looks: no UI or layout change; the button and sheet are the same widgets.

## Hand-over

- Files changed: `controller_app/lib/src/host/host_launch.dart` (new), `controller_app/lib/src/ui/connect_panels.dart`, this report.
- `tools/mine.sh` also reverted 3 generated files under `tv_test_app/windows/flutter/` ("churn: reverted 3 generated file(s)"). These were already modified in the start-of-session status. Whether that revert is wanted is a question for the user (see below).
- Flow tests could not be run to a pass in this worktree because of the missing puzzle asset in the test run.

## Questions

1. The two flow tests (`host_mode_test`, `host_start_log_test`) fail in `setUpAll` on the missing `packages/puzzle_game/puzzles/index.json` asset. Is this a known environment problem for worktrees? Should someone confirm they fail the same way on `main`?
2. `tools/mine.sh` reverted the 3 `tv_test_app/windows/flutter/generated_plugin_registrant.*` and `generated_plugins.cmake` churn files that were modified at session start. Is that revert expected by the runner?

## Suggestions

- Consider a test that calls `launchHosting` directly (with a fake `hostingProvider`) once Home needs it, so the function has its own test rather than relying on the button path.

## Commit message — a draft

Extract host start into launchHosting for Home to call

Move the "Host a game" start and route push out of connect_panels.dart
into host/host_launch.dart as launchHosting(context, ref, choice).
The sheet still runs in the panel, and the mounted check still comes
before the launch. The ordering comments (B-023, m12 bug 1108a rule D)
move with the code. Behaviour is unchanged; no keys or strings changed.

## Status row

n8b0 done: launchHosting extracted to host/host_launch.dart and called from connect_panels; analyze clean and mine.sh OK. Open: host_mode_test and host_start_log_test could not pass here (puzzle index asset missing in the test run); needs a run on a full checkout.

## Delete

- none
