## Summary

New `packages/party_host/test/touch_targets_host_test.dart`: 30 tests (5 screens x 3 sizes x 2 looks), all pass on the base
(`tools/mine.sh`: OK 30 tests, 1 file formatted, party_host analyzed clean). No lib file touched, no offender fixed.

- Screens: games (GamesScreen), lobby (JoinScreen via StubHome > Play > Shape Race > house), pause (pause card over a
  running race), results (ArenaResults in a night: Next, End night), award (AwardTile with its "i", then the
  explanation's OK button). All in the host frame (`framed`/`hostFrameBuilder`), as the phone host draws them.
- Sizes 568x320, 640x360, 375x667; menu and TV look through `pumpHostLook`.
- Measuring: HostButton, ToyButton, IconButton, InkWell, not counted again inside another tappable; the size is the
  on-screen size (corners through `localToGlobal`), because the frame scales the layout (frame px x scale = dp).
- `knownBelow48Host` keys carry the case: `'<screen>@<size>/<look> <Type> <key>'`, so each entry is checked in its own
  case and no state crosses tests. `roundingToleranceDp = 0.01` is documented. Sizes in the map are rounded to 0.1 dp.
- Computed values: every offender is in the table below; every other target (games cards etc.) is at least 48 dp.

### Offenders (menu look first, TV look second; smallest side shown is the height)

Height by size, menu/TV: 568x320 28.4/37.9 · 640x360 32.0/42.7 · 375x667 18.8/25.0 (the scale is .592, .667, .391 of
the frame px; the TV's 64 px button at 640x360 is 42.7 dp, so even the TV look is under 48 on every phone size).

| Screen | Widget | Widths (568 / 640 / 375) | Heights menu/TV (568 / 640 / 375) | File:line |
| --- | --- | --- | --- | --- |
| games | HostButton openPuzzleSettings | 166.9 / 188.0 / 110.2 | 28.4/37.9 · 32.0/42.7 · 18.8/25.0 | lib/src/ui/games_screen.dart:73 |
| lobby | HostButton joinStart | 89.0 / 100.3 / 58.8 | same heights | lib/src/ui/join_screen_widgets.dart:75 |
| lobby | HostButton joinBack | 86.5 / 97.5 / 57.1 | same heights | lib/src/ui/join_screen_widgets.dart:83 |
| lobby | IconButton hostTitleBarBack | 28.4 / 32.0 / 18.8 (square, both looks) | 28.4 · 32.0 · 18.8 | lib/src/ui/host_frame_screen.dart:156 (and host_screen.dart:114) |
| pause | HostButton pauseQuit | 82.9 / 93.4 / 54.7 | same heights | lib/src/ui/pause_menu_widgets.dart:73 |
| pause | HostButton pauseResume | 108.3 / 122.1 / 71.5 | same heights | lib/src/ui/pause_menu_widgets.dart:80 |
| results | HostButton next | 85.9 / 96.8 / 56.7 | same heights | lib/src/ui/arena_results.dart:137 |
| results | HostButton endNight | 122.2 / 137.7 / 80.7 | same heights | lib/src/ui/arena_results.dart:146 (puzzle results: puzzle_results_widgets.dart:179, not measured) |
| award | IconButton awardInfo-comeback (the "i") | 28.4 / 32.0 / 18.8 (square, both looks) | 28.4 · 32.0 · 18.8 | lib/src/ui/award_tile.dart:104 |
| award | HostButton awardExplanationClose (OK) | 50.6 / 57.0 / 33.4 | 28.4/37.9 · 32.0/42.7 · 18.8/25.0 | lib/src/ui/award_tile.dart:153 |

The exact value of every case is in `knownBelow48Host` (60 entries).

## Self-check (review-rules part A)

1. Hosts: only the phone host in the frame is measured (a phone host, sizes 568x320/640x360/375x667); TV host, joined
   phone and older peer are out of this job's scope (the TV look is covered at phone sizes). Test: all 30.
2. No kept state; nothing going on is not a case (each screen is mounted fresh).
3. Pause menu: measured as its own screen (pause); the other combinations (host away, Get ready, dropped link) are not
   measured here.
4. Only the allowed test file and this report were written.
5. No stop needed.
6. Every look: menu and TV in every case; the test measures sizes, it fixes no pixel height.

## Questions

- The footer, back arrow, "i" and pause buttons are 48 px in the frame, so below 48 dp on every phone size. A fix job
  must decide whether to enlarge the frame's controls or raise the frame's minimum scale (a design decision).
- The puzzle results card (puzzle_results_widgets.dart) and the night scoreboard are not in this test; say if wanted.
- The test is a measurement, not red-green: tests-first exempt (it records today's state).

## Commit message

touch targets: 48 dp measuring test for the phone-host screens

New test measures every HostButton, ToyButton, IconButton and InkWell on the
games, lobby, pause, results and award screens at 568x320, 640x360 and 375x667
in the menu and TV look, as on-screen dp. The 60 targets below 48 dp today are
listed in knownBelow48Host so a later job fixes them and removes the entries.

## Status row

n9b3: 48 dp measuring test for the phone-host screens done (30 tests, 60 offenders recorded in knownBelow48Host); open: fixing the offenders and measuring the puzzle results and night scoreboard.

## Delete

- none
