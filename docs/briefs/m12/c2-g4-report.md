# m12 cleanup c2, G4 — the phone app's providers.dart and widget_test.dart, split

Gate: G4 (complete). This job only. No behaviour, text or provider-name change.

## What was done

`controller_app/lib/src/providers.dart` (617 lines) is now a 39-line file: a barrel of `export`s plus the log
buffer (see question 1). The providers moved, by responsibility, into `controller_app/lib/src/providers/`, seven
files of 34 to 184 lines. `controller_app/test/widget_test.dart` (1614 lines) became `test/support/fakes.dart`,
`test/support/pump_app.dart` and eleven test files of 45 to 241 lines, one per screen or feature, as the TV
app's tests are (`tv_test_app/test/support/pump_app.dart` and its users).

Imports elsewhere did not change: every screen and `main.dart` still imports `package:controller/src/providers.dart`,
which re-exports the new files. One test changed its import: `test/phone_metrics_test.dart` imported
`widget_test.dart as app` for `pumpApp`/`settle`/`TestApp`/`connected`/`openSettings`/`scrollTo`; it now imports
`support/pump_app.dart as app` (the same names, same call sites).

### The seams, and the move map

Old member (providers.dart) → new file:

| Old member | New file |
| --- | --- |
| `prefsProvider`, `isIOSProvider`, `isTabletProvider`, `pxPerMmProvider`, `storeProvider`, `identityProvider`, `deviceDetailsProvider`, `deviceStatusSourceProvider`, `sessionMonitorProvider`, `sessionStatsProvider`, `SessionStatsNotifier` | `providers/device.dart` (79) |
| `discoveryProvider`, `DiscoveryStateNotifier`, `clientProvider`, `ClientStateNotifier`, `demoProvider`, `DemoNotifier`, `everConnectedProvider`, `EverConnectedNotifier`, `localNetworkStatusProvider`, `ConnectionActions`, `Outage`, `OutagesNotifier` | `providers/connection.dart` (184) |
| `hapticsProvider`, `hapticsPlayerProvider`, `hapticsCapabilitiesProvider`, `hapticSettingsProvider`, `HapticSettingsNotifier` | `providers/haptics.dart` (43) |
| `pressFeedbackProvider`, `PressFeedbackNotifier`, `flashOnPressProvider`, `clickSoundProvider` | `providers/feedback.dart` (34) |
| `gameLayoutProvider`, `GameLayoutNotifier`, `gameStatusProvider`, `GameStatusNotifier`, `TvHaptics`, `tvHapticsProvider`, `TvHapticsNotifier`, `ratingPromptProvider`, `RatingPromptNotifier` | `providers/game_feedback.dart` (82) |
| `padProvider`, `PadNotifier` | `providers/pad.dart` (145) |
| `shareStatsProvider`, `ShareStatsNotifier`, `phoneMetricsProvider` | `providers/metrics.dart` (75) |
| `logProvider`, `logLinesProvider`, `LogLinesNotifier` | stay in `providers.dart` (39) — question 1 |

Seam names, in the order the files sort: **device** (the phone this app runs on: saved settings, platform,
screen, identity, native device details, and the battery/CPU session readout), **connection** (discovery, the
client and its state, the demo mode, the last-TV actions, drops and recovery), **haptics** (the hardware, the
player and its saved settings), **feedback** (flash and click for phones without vibration), **game_feedback**
(what the game and the TV send back: layout, status panel, haptic events, the rating prompt), **pad** (the
touch input and its send pacing), **metrics** (touch metrics and the share switch).

### Item 1 — the providers over 60 lines

`docs/project-notes.md` lists the old file as "617 lines, two providers over 60". No provider in the new files
is over 60 lines: `tools/review.sh` on this diff has no `func` FAIL, and its two `func` *notes* are
`isTabletProvider` (56 lines) and `phoneMetricsProvider` (44 lines) — both are the tool's member scan running on
past the `});` that closes the member to the next brace at column 0 of the file, so they measure a stretch of the
file, not one member (`isTabletProvider` itself is five lines). The one long thing left, `PadNotifier` in
`pad.dart` (about 130 lines), is a class, which is a split unit the brief allows and the tool does not scan; it
moved verbatim.

Two provider bodies were broken into named private functions, as the brief allows:

- `clientProvider`'s "the model, OS and haptics go into the next hello once known" block (an inline `unawaited(()
  async {...}())`) → `Future<void> _addDeviceDetails(Ref ref, ControllerClient client)` in
  `providers/connection.dart`. Same order, same `ref.mounted` checks.
- `phoneMetricsProvider`'s local `void update()` closure → `void _updateMetrics(Ref ref, PhoneMetrics metrics)`
  in `providers/metrics.dart`. The same nine `ref.listen`s call it; the reads, the mode/settings snapshot and
  the "in session and not opted out" rule are unchanged line for line.

### Item 2 — the empty catch around the haptics check

Moved verbatim (behaviour identical: `haptics` stays `null`, so `withDeviceDetails` sends no haptics answer) into
`_addDeviceDetails`, with the reason on the first line inside the catch, which is also what keeps
`tools/review.sh`'s empty-catch check quiet on an added line:

```dart
  bool? haptics;
  try {
    haptics = (await ref.read(hapticsCapabilitiesProvider.future)).supported;
  } catch (_) {
    // Devices without the haptics API fail this check; unknown (null) is
    // the right answer then.
  }
```

## The tests

`widget_test.dart`'s shared code, unchanged apart from the helper rename below:

- `test/support/fakes.dart` (215): `FakeClient`, `FakeDiscovery`, `SlowCapsHaptics`, `FakeMotionSensors`,
  `FakeDeviceStatus`.
- `test/support/pump_app.dart` (117): the `tv` and `connected` fixtures, `TestApp`, `pumpApp`, `settle`,
  `openSettings`, `closeSettings`, `scrollTo`, `tapVisible`, and the point-in-a-widget helper `_at` — now
  `at`, because it is shared by six files (tests only ever call it, no test name or body changed).
- `uprightSteering` and `lastTiltX` went into `gyro_mode_test.dart`, the only file that uses them.

Tests per file (old `widget_test.dart`: **73**; the eleven new files: **6 + 4 + 4 + 3 + 7 + 10 + 9 + 7 + 7 + 2
+ 14 = 73**, which `flutter test` on the eleven files confirms: "+73: All tests passed!"):

| File | Lines | Tests | Content (old group) |
| --- | --- | --- | --- |
| `connect_screen_test.dart` | 99 | 6 | connecting |
| `connection_test.dart` | 60 | 4 | connection (M6) |
| `controller_screen_test.dart` | 86 | 4 | the pad; analog sending (found on the Pixel Tablet, M8) |
| `diagnostics_test.dart` | 79 | 3 | the Diagnostics screen test; session readout (M6) |
| `game_controls_test.dart` | 139 | 7 (5 declarations, one looped ×3) | game-defined controls and the status panel (M10) |
| `gyro_mode_test.dart` | 195 | 10 (9 declarations, one looped ×2) | gyro mode |
| `haptics_test.dart` | 135 | 9 | haptics; haptic events from the TV |
| `settings_test.dart` | 119 | 7 | settings (M6) |
| `stick_mode_test.dart` | 180 | 7 | stick mode |
| `store_builds_test.dart` | 45 | 2 | store builds (M8) |
| `tablet_and_feedback_test.dart` | 241 | 14 | bigger buttons, tablets and feedback (M7) |

Every test keeps its name, body and expectations. Group names are kept as they were, so the runner still says
`connecting › opens the Connect screen when there is no saved TV`. Two group choices to confirm: the two
pad-related groups now share `controller_screen_test.dart`, and the loose Diagnostics test sits beside the
session-readout group in `diagnostics_test.dart`.

## Counts

**Phone tests: 262 before, 262 after.** 262 = `widget_test.dart`'s 73 + 189 in the other seven test files.
With the old file set aside (the state after `widget_test.dart` is deleted) `tools/check.sh phone` runs 262
tests and passes; with it still on disk the runner also runs its 73 a second time and reports 335, which is the
same suite counted twice.

Line counts, before → after:

| Before | After |
| --- | --- |
| `lib/src/providers.dart` 617 | `providers.dart` 39 + `providers/{connection 184, device 79, feedback 34, game_feedback 82, haptics 43, metrics 75, pad 145}` = 681 |
| `test/widget_test.dart` 1614 | `test/support/{fakes 215, pump_app 117}` + the eleven test files = 1710 |

The providers code grew by 64 lines: each of the seven files has its own import block (6 to 11 lines), the barrel
adds seven `export`s and the comment that explains why the log buffer stays, and the two named private functions
add their signatures and the catch comment. The tests grew by 96 for the same reason — thirteen files each need
their own import block, about 10 lines — which is the price of a file per feature; no test code is duplicated
(`uprightSteering`, `lastTiltX`, `at` and the fixtures are declared once, in the file that uses them or in
`test/support/`).

## Checks

`tools/check.sh format analyze phone`, with `widget_test.dart` still on disk (today's tree, before the delete):

```
PASS  format      (2s)
PASS  analyze     (5s)
PASS  phone       (335 tests, 19s)
All checks passed (27s).
```

335 is the 262-test suite plus `widget_test.dart`'s 73 run a second time. With the old file set aside — the state
after this report's Delete list is applied — the same command reported `PASS phone (262 tests, 14s)`.

`tools/review.sh` (this diff):

```
NOTE func     controller_app/lib/src/providers/device.dart:24 56 lines (>40): final isTabletProvider = Provider<bool>((ref)
NOTE func     controller_app/lib/src/providers/metrics.dart:32 44 lines (>40): final phoneMetricsProvider = Provider<PhoneMetrics>((ref)
review: 0 fail, 2 note
```

`tools/review.sh --strings`:

```
strings: 0 removed, 0 added, 22 unchanged or moved
```

## Computed values

There are no new or changed expectations (a pure move), so the values to check are the counts above: 73 = 73
tests, 6/4/4/3/7/10/9/7/7/2/14 per file, 262 = 262 phone tests, and the per-file limits (largest provider
file 184 of 300 aimed, largest test file 241 of 500).

## Questions

1. **The log buffer stays in `providers.dart`.** Moving `logProvider` into `providers/log.dart` would copy the
   pre-existing debug-build line `debugPrint(log.lines.last.toString())` into a new file, and `tools/review.sh`
   FAILs `leftover debugPrint(` on any added line in `lib/`, so the diff would carry a FAIL the brief forbids
   (it is the `debugPrint` leftover already in the tech-debt list). I kept the log section where it was, with a
   comment saying why. If you want the log seam moved, the `debugPrint` needs deleting first — it is its own
   one-line change (the same leftover also sits in `packages/party_host/lib/src/providers.dart:47`).
2. **The files that need `logProvider` import `../providers.dart`**, the barrel that exports them
   (`connection.dart`, `haptics.dart`, `game_feedback.dart`), so those files and the barrel import each other. It
   compiles and `dart analyze` is clean — it in fact insists on it (`unnecessary_import` if the same file also
   imports a sibling). It goes away with question 1: then `providers/log.dart` is imported directly and
   `providers.dart` is exports only. Say if you want that now instead.
3. `phone_metrics_test.dart` had to change one import (`widget_test.dart as app` → `support/pump_app.dart as
   app`). It is outside the two files the brief names, but inside `controller_app/test`, and nothing else in it
   changed.
4. The shared helper `_at(tester, key, fraction)` is now `at` in `support/pump_app.dart`, since six test files
   use it. No test name, body or expectation changed; say if you would rather it keep the underscore and be
   re-exported per file.
5. `controller_app/lib/src/log2.tmp` is a leftover of building the new `providers.dart` from the old one (the
   sandbox would not let me delete it). It is listed under Delete; it is not Dart, so no tool sees it.
6. `git status` also shows `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
   `generated_plugins.cmake` modified at 18:53, before my first edit (18:57). I did not touch them; they were
   regenerated when the job's worktree was set up. Not part of this diff.

## Commit message

```
m12 c2 G4: split the phone providers and its widget tests

providers.dart (617 lines) becomes seven files under lib/src/providers/,
one per responsibility, exported from providers.dart so every caller still
imports one file: device, connection, haptics, feedback, game feedback,
pad and metrics. The two long provider bodies are named private functions
(_addDeviceDetails, _updateMetrics), and the empty catch on the haptics
check now says why unknown is the right answer there.
widget_test.dart (1614 lines) becomes eleven test files of 45 to 241 lines
plus test/support/fakes.dart and pump_app.dart; the 73 tests keep their
names, bodies and expectations.
```

## Status row

`- **m12 c2 (cleanup, G4)**: `controller_app`'s `providers.dart` split into `lib/src/providers/` (7 files, 34–184 lines) and `widget_test.dart` into 11 test files plus `test/support/` (73 tests, same names); 262 phone tests, format/analyze/phone pass, `review.sh` 0 fail, `--strings` 0/0. Open: the log buffer stays in `providers.dart` until the `debugPrint` leftover (same in `party_host`) is deleted and it moves to `providers/log.dart`.`

## Delete

- controller_app/test/widget_test.dart
- controller_app/lib/src/log2.tmp
