# M12 bug 1107f fit — G4 report: the phone's menus get their room back

Done at G4, the gate the brief names: (1) rule D — where the phone's bar is above, a screen with nothing to go back to
draws no title bar, so the game picker's body starts right under the phone's bar (the TV keeps the picker's "Play" title
bar); (2) rule E — the menus' outer top padding below the title bar is 12 where that bar is above and 24 elsewhere, and
one function decides it for every menu. The picker now fits at 852x393 without scrolling (it scrolled 43 px) and the
level list still does, the join screen's right side fits, and the settings page scrolls as it always did.

**One item is short: the join screen's left side still scrolls 11 px.** Rule E gives it back 12 of the 23 px rule C
took from it, and I did not invent a third lever (Question 1). Everything else in the brief is done, tested and
checked; the height table and the numbers for that 11 px are below.

The brief's item 4 asked me to delete `controller_app/test/bug_1107f_after_test.dart` and
`controller_app/test/probe_metrics_test.dart`: neither is in the tree (the script deleted them after the last job).
The two temporary files this job added are in Delete instead.

## Files changed

- `packages/party_host/lib/src/ui/host_screen.dart` (120 lines) — `hostMenuPadding(barHeightPx)` with the two
  constants `hostMenuPaddingPx` (24) and `hostMenuTopPaddingPx` (12) is the one place rule E is decided; `HostScreen`
  draws no title bar where the bar is above and `Navigator.of(context).canPop()` is false (rule D), keeping only a
  spacer for that bar, and the bar itself moved into `_HostTitleBar` so `build` stays short.
- `packages/party_host/lib/src/ui/games_screen.dart` (200 lines) — `GamesScreen` is a `ConsumerWidget` now; the
  picker's and the level list's `ListView` padding comes from `hostMenuPadding(ref.watch(hostBarHeightProvider))`.
- `packages/party_host/lib/src/ui/join_screen.dart` (348 lines) — the join screen's outer padding is
  `hostMenuPadding(...)` too.
- `packages/party_host/test/host_title_bar_test.dart` (115 lines) — 8 tests (was 4): the picker has no title bar on the
  phone and its body starts at the bar's bottom; a phone menu leaves 12 and a TV menu 24; the level list, join screen
  and settings keep their bars below the phone's; a TV picker keeps its title bar at 0 (both as a root and pushed from
  home); the stats screen draws its bar at 0 on the TV.
- `controller_app/test/host_title_bar_test.dart` (183 lines) — 6 tests (was 5): the picker starts under the phone's
  bar with no title bar, the level list and join screen keep theirs, "Show on this device" loses the picker's too, and
  the phone's menus leave 12 at the top (picker and level list).
- `controller_app/test/host_menu_fit_test.dart` (**new**, 64 lines) — the fit at 852x393 on "Play on this phone": the
  picker and the level list have `maxScrollExtent` 0, and the join screen's right side too.
- `controller_app/test/support/test_font.dart` (**new**, 33 lines) — loads Roboto (regular, medium, bold) and the icons'
  font from the Flutter SDK's font cache into the test engine, so text wraps and splits lines as a device's does and a
  fit can be measured; without it the test's own box font makes every menu read far too tall.
- `controller_app/test/probe_fit_test.dart` (**new**, 99 lines, temporary) — the measurements behind the height table;
  it holds one printing test and is deleted after this job.
- `controller_app/test/bug_1107f_pictures_test.dart` (**new**, 45 lines, temporary) — draws the two pictures; deleted
  after this job.
- `docs/briefs/m12/bug-1107f-after.png` — redrawn: the level list at 852x393 on a phone.
- `docs/briefs/m12/bug-1107f-picker.png` — new: the game picker at 852x393 on a phone.
- `docs/briefs/m12/bug-1107f-fit-report.md` — this report.

## Rule D: no title bar where there is nothing to go back to

`HostScreen` decides it in one line: `barHeightPx <= 0 || Navigator.of(context).canPop()`. On the phone the game picker
is the first route of the games' own navigator (`HostGames` in the app), so it can't pop and gets no bar; every screen
above it can, and keeps one. On the TV and the Windows app `hostBarHeightProvider` is 0, so nothing changes there: the
TV app pushes the picker from its home screen and keeps the "Play" title bar either way. The rule is written on the
class, so a screen added later that becomes a root takes it too.

## Rule E: 12 at the top, one place

`hostMenuPadding(barHeightPx)` returns `EdgeInsets.fromLTRB(24, 12, 24, 24)` where the bar is above and
`EdgeInsets.all(24)` where it is not. The picker, the level list and the join screen call it; no screen decides a
value. The settings page keeps its own `fromLTRB(24, 8, 24, 24)` (it was already tighter than 24, and it may scroll),
and the stats screen keeps its 16 on the TV, which has no bar to win room from.

## The height table, at 852x393 on "Play on this phone"

px as measured in the widget tests with Roboto loaded (the test's own box font would read a few dozen px too tall).
"Body" is what a menu's list gets; "scrolls" is `maxScrollExtent` (0 = it fits without scrolling). Before = the last
job's "after".

| | body before | scrolls before | body after | scrolls after |
| --- | --- | --- | --- | --- |
| Game picker | 285 | 43 | 341 (no title bar: 393 − 52) | **0** |
| Level list (Shape Race) | 285 | 0 | 285 | 0 |
| Join screen, each side's panel | 121 | 23 (left), 0 (right) | 133 | 11 (left), 0 (right) |
| Puzzle settings | 285 | 467 | 285 | 467 |
| Stats | TV only, no bar: unchanged | — | — | — |
| The round and its results | the round fills the screen: unchanged (tested) | — | — | — |

What is behind the numbers: the picker's content is 280 px tall and its viewport goes from 237 (285 − 48) to 305
(341 − 36), so it fits with 25 px to spare. The level list's viewport goes 237 → 249 and its content fits in both. The
join screen's left panel holds 144 px (16 + the "◀ Left" heading 32 + 12 + the own player's 36 + 8 + "Room for 1 more"
24 + 16) against a panel of 133: 11 px over. The right panel holds 100 and fits.

## The 11 px that is left (Question 1)

The title bar took 23 px from the join screen's left panel (121 → its content 144), and rule E's 12 at the top gives
back 12. To reach 0 it needs 23: the levers I did not take are (a) 0 at the top of a menu where the bar is above
instead of 12 — that alone fits the left side with 1 px to spare, and costs the menus nothing else, since the title bar
already ends with its 56-high row; (b) the join screen's panels keep 8 at the top instead of 16; (c) the join screen
loses its title bar on the phone as the picker does (56 px, but it has a back arrow and a Back button). All three are
design decisions, so the brief goes back to you. The test for the right side is in `host_menu_fit_test.dart`; the left
side is not asserted (its comment says why).

## Tests, each failing first

With the two lines taken away again (rule D forced on, `hostMenuPadding` back to 24) the new tests failed on the bug's
own symptoms, then were restored:

| Test | Failing on the old code with |
| --- | --- |
| host_title_bar: 'the picker on the phone has no title bar, so its body starts under the bar' | 'Found 1 widget with key hostTitleBar' |
| host_title_bar: 'a phone menu leaves 12 at the top, where its bar gives the room' | `Actual: EdgeInsets.all(24.0)` |
| host_title_bar: 'a menu keeps 12 at the top where the phone bar is above, and 24 where it is not' | `Actual: EdgeInsets.all(24.0)` |
| host_title_bar: 'every host screen with a title bar leaves the phone bar free…' (its new last line) | the picker still had a title bar |
| phone host_title_bar: 'the picker starts under the bar, and the level list and the join screen keep their titles' | 'Found 1 widget with key hostTitleBar' |
| phone host_title_bar: '"Show on this device" loses the picker's title bar too' | 'Found 1 widget with key hostTitleBar' |
| phone host_title_bar: 'the phone's menus leave 12 at the top of their bodies…' | `Actual: EdgeInsets.all(24.0)` |
| host_menu_fit: 'the phone's picker and level list fit at 852x393 without scrolling' | `Expected: <0> Actual: <43.0>` |

The tests that hold the TV and the existing behaviour (title bar at 0 for the TV picker and stats, 24 for a TV menu,
the level list and the join screen's bars below the phone's, the right side's fit) passed before and after, as
regression guards.

The eight new or changed tests and what each shows:

| Test | Shows |
| --- | --- |
| host_title_bar: 'a menu keeps 12 at the top where the phone bar is above, and 24 where it is not' | rule E's two values, from the one function |
| host_title_bar: 'the picker on the phone has no title bar, so its body starts under the bar' | rule D: no `hostTitleBar`, the picker's list at 52 and 540 − 52 high |
| host_title_bar: 'a phone menu leaves 12 at the top, where its bar gives the room' | the picker's list padding is `fromLTRB(24, 12, 24, 24)` |
| host_title_bar: 'a TV menu keeps its 24 at the top' | the same list on a TV: `EdgeInsets.all(24)` |
| host_title_bar: 'every host screen with a title bar leaves the phone bar free, and its back arrow pops' | the level list and join screen at 52, the arrow in the clear and popping, and the picker still without a bar |
| host_title_bar: 'the settings screen leaves the phone bar free too' | the settings screen's bar and its Reset button below 52 |
| host_title_bar: 'the stats screen draws its title bar at the top, as its TV screen always did' | top == 0 (stats is TV only) |
| host_title_bar: 'a TV host keeps the picker's title bar at the top, where its app bar was' | top == 0 as a root and pushed from home |
| phone host_title_bar: 'the picker starts under the bar…' | the real app: no title bar, the picker's list at `topBarHeightPx` and 393 − 52 high, then the level list's and join screen's bars at 52 |
| phone host_title_bar: 'the title bar back arrow is in the clear and pops to the picker…' | unchanged (the level list's arrow) |
| phone host_title_bar: '"Show on this device" loses the picker's title bar too' | rule D on the second host choice |
| phone host_title_bar: 'the phone's menus leave 12 at the top of their bodies…' | the picker's and level list's padding in the real app |
| phone host_title_bar: 'the round keeps the whole screen…' | unchanged |
| phone host_title_bar: 'the hosted menus show no focus look…' | unchanged (rules A and B still hold) |
| host_menu_fit: 'the phone's picker and level list fit at 852x393 without scrolling' | `maxScrollExtent` 0 for both |
| host_menu_fit: 'the join screen's right side fits at 852x393 without scrolling' | the right side's 0 |

## Test counts, before and after

Measured with `tools/check.sh` on this machine.

| Check | Before | After |
| --- | --- | --- |
| host | 128 | **132** (one plain test on `hostMenuPadding`, three widget tests; one existing test gained a line) |
| phone | 367 (368 with the last job's temporary capture test) | **372**, of which 2 are the temporary files above: **370** once they go |
| tv | (the check prints no count) | unchanged |
| format, analyze | PASS | PASS |

## Checks run

- `tools/check.sh format analyze host phone tv` — PASS, all five (format 1 s, analyze 10 s, host 132 in 15 s, phone 372
  in 28 s, tv 9 s).
- `tools/review.sh` — `review: 0 fail, 1 note`: `join_screen.dart` 348 lines (lib limit 400, aim 300), as before.

## The pictures

Both are 852x393, drawn the same way as before: the real app in "Play on this phone", rendered from the engine's own
layer to a PNG, with Roboto and the icon font loaded so the text and icons are not boxes (without the icon font the
bar's Settings and Diagnostics buttons would be boxes).

- `docs/briefs/m12/bug-1107f-picker.png` — the picker with the phone's bar (P1, `Hosting · <code>`, D-pad/Gyro/Sticks,
  Settings, Diagnostics), then the two game cards straight under it with no "Play" title bar, then Puzzle settings and
  its note. It is the picture of rule D.
- `docs/briefs/m12/bug-1107f-after.png` — the level list: the phone's bar, then the title bar with its back arrow and
  "Shape Race" below the bar, then Easy's four buttons and Medium's two, with 12 px at the top of the list.

## Questions

1. The join screen's left side still scrolls 11 px at 852x393 (23 from the title bar, 12 given back). Which lever do
   you want: 0 at the top of the menus where the bar is above (fits with 1 px to spare), 8 inside the join screen's
   panels, or no title bar on the join screen? I left the layout as the brief describes it.
2. The fit test and the pictures need a real font: the test bundle's own font has a square for every letter, so the
   level list wraps into rows a device never shows and reads 39 px too tall. I load Roboto and the icon font from the
   Flutter SDK's font cache (`FLUTTER_ROOT/bin/cache/artifacts/material_fonts`), so it holds on any machine with the
   toolchain; the other way is to put the two faces in the repo. Is the SDK cache acceptable, or should a font be
   bundled?
3. Rule D uses `Navigator.of(context).canPop()` for "nothing to go back to". That is exactly the phone's picker (the
   first route of the games' navigator) and it is false for any root screen a later host screen might become. Keep the
   derived test, or should `HostScreen` take a field naming a root screen?
4. The stats screen is TV-only (your Q3 answer), so its phone test became the TV one (bar at 0) and its 16 px body
   padding is untouched. Is that the coverage you want for it?
5. `games_screen.dart` is 200 lines with the picker and the level list in it; the `hostMenuPadding` calls added four
   lines. Nothing to split yet, but the picker and the level list are two screens in one file.

## Suggestions

- Bundle the two Roboto faces (regular and medium) and the icon font as test assets in a small later job: the pictures
  and the fit test would then not depend on the SDK cache's layout, which flutter may move.
- If rule E ever grows (a tablet's different padding, a second bar), `hostMenuPadding` can take the box as well, but it
  is one function today and one place to change.

## Self-check (review rules, part A)

1. **Every host setup.** TV and the Windows app: title bar at 0 everywhere, the picker's included, and menus 24 —
   'a TV host keeps the picker's title bar at the top, where its app bar was' and 'a TV menu keeps its 24 at the top';
   phone "Play on this phone": no picker title bar, the body at 52, menus 12 — phone 'the picker starts under the
   bar…' and 'the phone's menus leave 12…'; "Show on this device": '"Show on this device" loses the picker's title bar
   too'; a joined phone: nothing in this diff touches a joined phone's app or the protocol, and 'the hosted menus show
   no focus look…' still passes; a build one older: no message, field or file format changed, so nothing to test.
2. **When kept state starts and ends.** No state is added: `hostBarHeightProvider` and the screens' scroll positions
   are as they were, and `hostMenuPadding` is a pure function of the bar height, recomputed on each build — 'a menu
   keeps 12 at the top where the phone bar is above, and 24 where it is not' shows both sides of it.
3. **How a new state combines.** Nothing pauses, hides or blocks input; the layout only changes where the bar is
   above. The pause menu is a dialog above the routes and not a `HostScreen`, so it is untouched — 'the hosted menus
   show no focus look, and a button lights only under a thumb' and 'the title bar back arrow is in the clear and pops
   to the picker, with the host still on' pass unchanged.
4. **Stay in the job's folder.** Every file above is inside `allow:` (`packages/party_host`, `controller_app/test`, the
   two pictures and this report); nothing else was edited.
5. **Stop rather than overstep.** D and E are done exactly as briefed; the 11 px the join screen's left side is short
   is reported as Question 1 rather than fixed with a lever of my own, and the two files the brief named for deletion
   are noted as already gone.

## Commit message

Fit the phone's menus: no picker title bar, 12 at the top

Where the phone's bar is above, a screen with nothing to go back to
draws no title bar, so the game picker's body starts right under that
bar, and the menus' own top padding drops from 24 to 12 — both decided
once, in HostScreen. The TV is unchanged: its picker keeps the "Play"
title bar and its menus keep 24. At 852x393 on a phone the picker now
fits without scrolling (it scrolled 43 px) and the level list still
does; the join screen's left side is still 11 px over, reported.

## Status row

M12 bug 1107f fit at G4: the phone's picker draws no title bar and the menus' top padding is 12 there (24 on the TV),
both from `HostScreen`, so at 852x393 the picker and the level list fit without scrolling and the join screen's right
side does too; open: the join screen's left side still scrolls 11 px, and whether a font should be bundled for the fit
tests and the pictures.

## Delete

- controller_app/test/probe_fit_test.dart
- controller_app/test/bug_1107f_pictures_test.dart

## Claude's follow-up (Nov 8)

Q1: the join screen's own gaps (16/12/12 → 8) and its panels' padding (16 → 12) tighten where the phone's bar is above (`join_screen.dart`, `join_screen_widgets.dart`); the fit test now checks both sides at 0 (it failed first at 11). A full side of two players may still scroll a few px. Q2 the SDK font cache is fine. Q3 keep `canPop()`. Q4 yes. Q5 logged in code-health. The two temporary tests are deleted. Checks: host 132, phone 370, all PASS; review 0 fail.
