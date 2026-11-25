## Summary

n8a: item 8 contract for Home. New files only: the role and find enums, the highlight rule, the three Home anchor keys, the saved `showTips` flag, and the Home strings. No screen, routing, settings row or consent change.

Files changed (all new):
- `controller_app/lib/src/home/home_contract.dart`: `HomeRole` (join, play, display, in button order), `HomeFind` (searching, found, none), `highlightedRole(HomeFind)`, and `HomeAnchors` with three `GlobalKey` fields. The doc comment carries the JOBS.md item 8 contract paragraph.
- `controller_app/lib/src/home/home_prefs.dart`: `showTipsProvider` (NotifierProvider<ShowTipsNotifier, bool>). `build` reads `getBool('showTips') ?? true`. `set(bool)` updates state and awaits `setBool`. Same shape as `controls.dart`.
- `controller_app/lib/src/home/home_text.dart`: `abstract final class HomeText` with the 15 const strings from the brief. No string contains the whole word "TV".
- `controller_app/test/home_contract_test.dart`: role order, highlight for each find value, three distinct anchor keys.
- `controller_app/test/home_prefs_test.dart`: no saved key gives true; `set(false)` saves and a new container reloads false.

Computed test values:
- `HomeRole.values` = [join, play, display].
- `highlightedRole(found)` = join; `highlightedRole(none)` = play; `highlightedRole(searching)` = null.
- Anchor keys: 3 distinct (`toSet().length` = 3).
- `showTips` with an empty mock store = true.
- After `set(false)`, `getBool('showTips')` = false and a new container reads false.

Decisions:
- `set` returns `Future<void>` and is awaited, not fire-and-forget as in `controls.dart`, so the test can await the save before teardown.
- The key name is a private const `_showTipsKey` in `home_prefs.dart`.
- `HomeAnchors` uses plain `GlobalKey()` (no state type parameter), since the brief named no state type.
- Constructor placed before fields to satisfy `sort_constructors_first`.

Self-check (review-rules part A):
1. Host setups: no host code touched. Covered by no change in `lib/src/host` or `party_host`.
2. Kept state: `showTips` starts from the saved key or defaults to true, and is saved only on `set`. Shown in the prefs test.
3. Combination with pause, away, Get ready, dropped link, results, leaving: no screen or flow exists yet; nothing combines. Deferred to the wiring jobs.
4. Stayed in the job's folder and inside allow:. Yes, apart from the churn revert below.
5. Stops: none needed.
6. Looks: no widget built, no pixel sizes.

Checks run:
- `tools/mine.sh`, first run: analyze FAILED (1 warning: unused `flutter/widgets.dart` import in `home_prefs_test.dart`; 1 info: `sort_constructors_first` in `home_contract.dart`). Both fixed.
- `tools/mine.sh`, second run: format ok, analyze ok (1 package), tests OK 7 tests in controller_app (5 contract + 2 prefs). Result: ok.

## Hand-over

- Tests-first: the test files were written before the lib files, but I did not run them against the old code. The brief's "fail on the code as it was" was not measured here; the runner's check decides it.
- `tools/mine.sh` churn revert: its output said "churn: reverted 22 generated file(s)". After the run, `git status` shows only my four new paths and `DRIVER-NOTES.md`. The 22 files that were modified before I started are back at HEAD: `docs/design/m13-placed-look.png`, `docs/design/puzzles/*.png` (13), `site/shots/*.png` (6), and `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h`, `generated_plugins.cmake`. I did not run any git command that changes state, and I can't restore them. If those edits were in progress, they need recovering by whoever owns them. The churn revert also ran against files outside my allow-list, which the brief did not expect.
- `dart format` also reformatted my own files during `mine.sh` ("2 file(s) formatted").

## Commit message — a draft

Add Home contract: roles, anchors, highlight rule, showTips flag, strings

Adds HomeRole and HomeFind with the highlight rule (found: Join, none:
Play, searching: none), HomeAnchors with three keys, and the strings in
HomeText. Adds showTipsProvider, saved under 'showTips' and defaulting
to true when no key is saved (Q3 A). New files only; no screen, routing
or settings change. Tests in home_contract_test.dart and
home_prefs_test.dart.

## Status row

n8a: done — Home contract (roles, anchors, highlight rule, showTips provider, HomeText) and its 7 tests pass; open: failing-first not measured, and the 22 pre-existing modified files were reverted by the mine.sh churn step (owner to recover).

## Delete

- none
