# M12 bug 1107f — G4 report: no highlighted buttons on a touch menu, and the title under the phone's bar

Done at G4, the gate the brief names, with the brief's three items. (1) Rules A and B: on a touch-first host
nothing shows a focus look until a pad moves the focus; a press through `ControllerMenus` shows it, a thumb hides it
again, and a button is ringed and filled while a finger is on it; one seam says which host is touch-first and one
shared style draws the look for every host button, card, row and step — nothing reads the platform. (2) Rule C: every
host screen with a title bar now takes it from one shared `HostScreen`, which leaves the phone's own bar (52 px) free
above it, so a title and a back arrow never sit under the bar again; the round keeps drawing behind the bar as
before. (3) The level list was redrawn at 852x393 on "Play on this phone" into `docs/briefs/bug-1107f-after.png`.

No file outside `allow:` was edited. Two test files are temporary (the picture's capture and the measurements) and
are listed in Delete.

## Files changed

- `packages/party_host/lib/src/providers.dart` (389 lines) — three providers with dartdoc citing the rules:
  `hostTouchFirstProvider` (`false`, so the TV and the Windows app are unchanged; the phone overrides it),
  `hostFocusLookProvider` with `HostFocusLookNotifier` (`build` = `!touchFirst`; `padUsed()` shows the look,
  `touched()` hides it again, and only when the host is touch first), and `hostBarHeightProvider` (`0`; the phone
  overrides it with its bar's height).
- `packages/party_host/lib/src/ui/host_button.dart` (102 lines) — `hostRingPx` (4) and `hostButtonLook(context,
  {showFocus, fill})`: the one style for a lit host button, the primary fill and a 4 px primary ring while the state
  is `pressed`, or `focused` when `showFocus`; `fill` is the rest of the time. `HostButton` is a `ConsumerWidget` and
  its style is the old sizes/paddings/font `.merge(hostButtonLook(…))`; its label now takes the theme's font family
  (Question 2).
- `packages/party_host/lib/src/ui/host_screen.dart` (**new**, 82 lines) — the shared title bar: a `Material` with
  `MediaQuery.paddingOf(context).top + hostBarHeightProvider` above a `kToolbarHeight` row (back arrow when the route
  can pop, the title with ellipsis, the screen's actions), and the body below it with the top media padding removed
  (so a `SafeArea` in the body doesn't take it twice). Keys `hostTitleBar` and `hostTitleBarBack`; `hostTitleBarPaddingPx`
  (16) for the room around the title and after the actions.
- `packages/party_host/lib/src/ui/host_focus_scope.dart` (**new**, 36 lines) — the phone app's touch-first wrapper: a
  translucent `Listener` whose `onPointerDown` hides the look, and, while it is hidden, a `Theme` with
  `focusColor: Colors.transparent` so Material's own focus overlay (list rows, dialogs) goes too. A host that isn't
  touch first gets its child untouched.
- `packages/party_host/lib/src/ui/games_screen.dart` (200 lines) — `GamesScreen` and `ShapeRaceScreen` are built from
  `HostScreen`; `_GameCard` is a `ConsumerWidget` and its style is `ButtonStyle(shape, padding).merge(hostButtonLook(…))`.
- `packages/party_host/lib/src/ui/join_screen.dart` (348 lines) — the `AppBar` is gone: `HostScreen(title: 'Shape Race ·
  …', body: SafeArea(…))`.
- `packages/party_host/lib/src/ui/puzzle_settings_screen.dart` (156 lines) — `HostScreen(title: 'Puzzle settings',
  actions: [Reset to defaults], body: …)`; `_Step`'s style is `.merge(hostButtonLook(…))` with no fill, so it keeps
  the tonal default it had.
- `packages/party_host/lib/src/ui/stats_screen.dart` (293 lines) — `HostScreen(title: 'Stats', actions: [share,
  export], body: …)`.
- `packages/party_host/lib/src/ui/stats_screen_widgets.dart` (167 lines) — `_SessionButton` is a `ConsumerWidget`; its
  style is `.merge(hostButtonLook(…, fill: selected ? primaryContainer : surfaceContainerHigh))`.
- `packages/party_host/lib/src/ui/controller_menus.dart` (266 lines) — `_press` starts with
  `ref.read(hostFocusLookProvider.notifier).padUsed()`: a pad working the menus shows the look.
- `packages/party_host/lib/party_host.dart` (43 lines) — exports the two new files (after `host_button.dart`).
- `controller_app/lib/main.dart` (50 lines) — the `MaterialApp.builder` wraps every route in `party.HostFocusScope`,
  so the pause menu and its dialogs are inside it too.
- `controller_app/lib/src/host/host_overrides.dart` (71 lines) — `hostTouchFirstProvider = true` and
  `hostBarHeightProvider = topBarHeightPx` (52) in `phoneHostOverrides`.
- `packages/party_host/test/host_focus_look_test.dart` (**new**, 91 lines) — three tests (below).
- `packages/party_host/test/host_title_bar_test.dart` (**new**, 77 lines) — four tests (below).
- `packages/party_host/test/support/host_harness.dart` (240 lines) — the harness mounts what a host app mounts: its
  `builder` is now `HostFocusScope(child: ControllerMenus(child: …))`, the phone app's order. No existing expectation
  changed (a non-touch-first host gets its child untouched, so every other test is unaffected).
- `controller_app/test/host_title_bar_test.dart` (**new**, 150 lines) — five tests on the real app (below).
- `controller_app/test/bug_1107f_after_test.dart` (**new**, 76 lines, temporary) — renders the level list at 852x393
  and writes `docs/briefs/bug-1107f-after.png`; deleted after this job.
- `controller_app/test/probe_metrics_test.dart` (**new**, 4 lines, temporary) — the scratch file the height numbers
  below were measured with; it holds no tests and is deleted after this job.
- `docs/briefs/m12/bug-1107f-after.png` — the picture of item 3.
- `docs/briefs/m12/bug-1107f-fix-report.md` — this report.

## The sweep: every focusable thing on the host's screens

"What it shows now" is the *fill and the ring* (not a style read for invented states): the resting fill, or the lit
look (`primaryContainer` + a 4 px `primary` ring).

| Screen | Focusable | TV / PC host | Phone: "Play on this phone" | Phone: "Show on this device" |
| --- | --- | --- | --- | --- |
| Game picker | Shape Race card (`autofocus`), Arena card, Puzzle settings | first card ringed from the first frame | all rest; a pad's press rings one; a thumb hides it; a pressed one is lit while the finger is down | same (the picker is the same screen) |
| Level list | Any `<level>` puzzle (`autofocus` on the first), each puzzle button | first button ringed from the first frame | rest; a pad rings one; a thumb hides it; lit under a finger | same |
| Join screen | Start (the focus is moved to it), Back; the two side panels are `InkWell` tap targets | Start ringed | Start rests; the sides' Material highlight is hidden until a pad moves the focus | same |
| Puzzle settings | Reset to defaults in the bar; every `−` and `+` step | first step ringed | rest; a pad rings one | same |
| Stats | Share, Export in the bar; each session row | first ringed | rest; a pad rings one | not reachable from the phone (TV only) |
| Round's results | Play again (`autofocus`), Change teams, Back | Play again ringed | rest; a pad rings one; lit under a finger | same |
| Pause menu (a dialog) | Resume (`autofocus`), Quit | Resume ringed | rest, and Material's own focus overlay is transparent too until a pad moves the focus | same |

The look is one flag, so it holds across screens: once a pad has moved the focus, every screen after it carries the
look until a thumb touches this phone — which is rule A read literally. Nothing else about these widgets changed: the
same buttons, the same sizes, the same fills when not lit (`fill` is passed explicitly where the old style relied on
the tonal default).

## Rule C: the title bar, and what it costs

One `HostScreen` draws every host screen's title bar, so a screen added later gets the phone's room by construction
(no `AppBar` is left in `packages/party_host`). The inset is `MediaQuery.paddingOf(context).top +
hostBarHeightProvider`: 52 on the phone (4 + 48, `topBarHeightPx`), 0 on the TV and the Windows app, where the bar
sits at the top of the screen exactly where the app bar it replaces was.

Height at 852x393 (the owner's phone), in px. "Body" is what a menu's list gets below the title bar; "scrolls" is a
list's `maxScrollExtent` (0 = it fits without scrolling). Measured with the probe file, whose font stands in for
Roboto (the test bundle has none), so the figures are within a few px of a device.

| | body before | scrolls before | body after | scrolls after |
| --- | --- | --- | --- | --- |
| Game picker | 337 | 0 | 285 | **43** |
| Level list (Shape Race) | 337 | 0 | 285 | 0 |
| Join screen, each side's panel | 173 | 0 | 121 | **23** (left), 0 (right) |
| Puzzle settings | 337 | 415 (a page that scrolls) | 285 | 467 |
| Stats | TV only, no bar: unchanged | — | — | — |
| Round's results | the round fills the screen: unchanged (tested) | — | — | — |

So a menu loses 52 px: the body goes from 393 − 56 (the old app bar) to 393 − 108 (the phone's bar 52 + the title
bar's 56). With that, the level list still fits without scrolling; the picker now scrolls 43 px and the join screen's
left side 23 px, and the settings page scrolls 52 px more than it did. Question 1 asks whether that is the accepted
cost or whether the room should be won back.

## Tests, each failing first

The phone's five were run against the fix taken away (the two overrides commented out) and failed on the bug's own
symptoms:

- `controller_app/test/host_title_bar_test.dart` — 'the picker, the level list and the join screen keep their titles
  below the bar': `Expected: <52.0> Actual: <0.0>` (the title bar started at the very top, under the bar's chip and
  labels).
- the same file — 'the title bar back arrow is in the clear and pops to the picker, with the host still on':
  `Expected: a value greater than or equal to <52.0> Actual: <4.0>` (the arrow was inside the bar's own 4 px padding).
- the same file — '"Show on this device" keeps its title bar below the bar too': the same 52 vs 0.
- the same file — 'the hosted menus show no focus look, and a button lights only under a thumb': the card drew
  `primaryContainer` with the 4 px ring where the test wanted the resting fill and no ring (bug 1107f itself).
- `packages/party_host/test/host_focus_look_test.dart` and `packages/party_host/test/host_title_bar_test.dart` use
  what the fix adds (`hostFocusLookProvider`, `hostRingPx`, `hostBarHeightProvider`, `hostTitleBar`), so on the old
  code they fail to compile by construction, as the previous job's log tests did.

Two of my own test bugs were theirs, not the fix's, and are fixed: the pressed-state test needed `kPressTimeout`
before Material lights a button, and the harness had to mount `HostFocusScope` (without it the "a touch hides it"
step had nothing to hide it).

The twelve tests, and what each shows:

| Test | Shows |
| --- | --- |
| host_focus_look: 'a touch-first host shows no focus look until a pad moves the focus' | rule A's three beats: resting on the first frame with the focus on the card, lit after a pad's press, resting again after a thumb |
| host_focus_look: 'a button under a finger lights up, and drops it when the finger lifts' | the pressed half of rule A: lit while the finger is down, resting again on release, and the cancelled press opens nothing |
| host_focus_look: 'a TV host shows the focus look on its first screen, and a touch does not take it away' | rule B's default: a TV host is as it was, and a pointer doesn't hide the look there |
| host_title_bar: 'every host screen with a title bar leaves the phone bar free, and its back arrow pops' | picker, level list and join screen: title bar top == 52, the title below it, the arrow in the clear and popping to the picker |
| host_title_bar: 'the settings screen leaves the phone bar free too' | the settings screen's title bar and its Reset button |
| host_title_bar: 'the stats screen leaves the phone bar free too' | the stats screen's title bar |
| host_title_bar: 'a TV host draws its title bar at the top, where its app bar was' | rule C's TV half: top == 0 |
| phone host_title_bar: 'the picker, the level list and the join screen keep their titles below the bar' | the real app: `topBarHeightPx` for each title bar, no overlap with the chip, the mode labels, Settings or Diagnostics, and the body's exact height (393 − 52 − 56) |
| phone host_title_bar: 'the title bar back arrow is in the clear and pops to the picker, with the host still on' | the arrow is hit-testable below the bar and pops up the games without stopping the host |
| phone host_title_bar: '"Show on this device" keeps its title bar below the bar too' | the second host choice gets it too |
| phone host_title_bar: 'the round keeps the whole screen: the board still fills it behind the bar' | rule C's other half: no title bar on the round, the board still 852x393 |
| phone host_title_bar: 'the hosted menus show no focus look, and a button lights only under a thumb' | rules A and B through the real app: the override, the shared look and the pressed look |

## Test counts, before and after

Measured with `tools/check.sh` on this machine:

| Check | Before | After |
| --- | --- | --- |
| host | 121 | **128** (three focus-look tests, four title-bar tests) |
| phone | 362 | **368** (five title-bar/focus tests, and the temporary capture test) |
| tv | (the check prints no count) | unchanged |
| format, analyze | PASS | PASS |

No existing test changed an expectation. The harness gained the phone app's `HostFocusScope`; every other test file
is untouched and passes as it was.

## Checks run

- `tools/check.sh format analyze host phone tv` — PASS, all five (format 1 s, analyze 5 s, host 128 in 15 s, phone 368
  in 27 s, tv 9 s).
- `tools/review.sh` — `review: 0 fail, 9 note`: `providers.dart` 389 lines (lib limit 400, aim 300),
  `join_screen.dart` 348 lines, and seven numeric literals that were there before this job (the card's 20s, the
  button's 32/12/20/15, the stats table's 14), which my line shifts only moved.

## The picture

`docs/briefs/m12/bug-1107f-after.png`, 852x393, the level list of a phone on "Play on this phone": the phone's bar
(P1, `Hosting · <code>`, D-pad/Gyro/Sticks, Settings, Diagnostics), then the title bar with its back arrow and "Shape
Race" below the bar, then the levels; no pad. It comes from a golden-style widget render of the real app (the
temporary `bug_1107f_after_test.dart`: the app's route rendered to an image through its `RenderRepaintBoundary`), not
from a device. A widget test draws text in Ahem, which has a box for every letter, so the capture loads a system
font's two faces for the theme's family and the icons' own font; without that the shot would show boxes where the
labels are.

## Questions

1. Rule C costs the menus 52 px, and the numbers above say what that means at 852x393: the picker now scrolls 43 px
   and the join screen's left side 23 px (the level list still fits, the settings page scrolls 52 px more than
   before). Is that the cost to accept, or do you want the room won back — a 48-high title bar and/or the menus'
   own 24 px top padding trimmed on the phone? I didn't take that decision.
2. `HostButton`'s label now names the theme's font family (`textTheme.labelLarge?.fontFamily`). It changes nothing on
   a device (the theme names the platform's font), but a style that names none gets the test renderer's box font, so
   the shot would have been unreadable. Keep it, or drop it as out of scope?
3. `StatsScreen` is only reachable from the TV app's home screen, never from the phone, so on a phone it takes no
   room. Should the phone get its own way in (and then lose the same 52 px), or does the brief's "stats" mean the
   TV's screen, which is unchanged?
4. The join screen's two side panels are `InkWell` tap targets, not host buttons: their focus look is Material's own
   overlay (transparent while the touch-first look is hidden), not the shared ring. Should they take
   `hostButtonLook` too, or is a panel not a button?
5. `providers.dart` is at 389 lines after the three providers (limit 400, aim 300): the next host provider probably
   wants its own file. Not done here.

## Suggestions

- If the scroll is unwanted, the cheapest fix is to drop the menus' 24 px top padding on a touch-first host (the
  title bar already gives the room), which returns the picker's 43 px and the join's 23 px without touching rule C.
- A later job that reserves room for another bar (a header, a clock) can reuse `hostBarHeightProvider` rather than
  adding a second inset.

## Self-check (review rules, part A)

1. **Every host setup.** TV/PC: title bar at 0 and the focus look from the first frame — `host_title_bar_test`
   'a TV host draws its title bar at the top, where its app bar was' and `host_focus_look_test` 'a TV host shows the
   focus look…'; phone "Play on this phone": `controller_app/test/host_title_bar_test.dart`'s three bar tests and the
   focus test; "Show on this device": '"Show on this device" keeps its title bar below the bar too'; a joined phone:
   its pad drives the menus and shows the look — `host_focus_look_test` 'a touch-first host shows no focus look until
   a pad moves the focus'; a build older: no message or field changed, so nothing to test.
2. **When kept state starts and ends.** `hostFocusLookProvider` starts hidden on a touch-first host and shown
   elsewhere; `padUsed()` shows it, `touched()` hides it (only on a touch-first host), and it is a plain root-scope
   flag with no timer, no round and no players involved — `host_focus_look_test`'s first two tests walk both edges.
   `hostBarHeightProvider` is a constant override.
3. **How a new state combines.** The flag pauses, hides and blocks nothing: the `Listener` is translucent (a finger
   still presses through it — `controller_app/test/host_mode_test.dart`'s solo round taps cards and Start under it),
   the transparent `focusColor` only changes a colour, and it sits above every route so it applies to the pause menu
   and its dialogs — `host_focus_look_test` 'a button under a finger lights up…' shows a press reaching the card.
4. **Stay in the job's folder.** Every file above is inside `allow:`; the report and the picture are the two outputs
   the brief names.
5. **Stop rather than overstep.** Done at G4 only; the 52 px cost and the label's font line are reported as Questions
   1 and 2 rather than decided, and nothing outside `allow:` was touched.

## Commit message

Light host buttons under a thumb; put titles below the phone bar

A host button is lit while a finger presses it, and, on a host that
isn't touch-first, while the focus is on it: one shared style now
draws every host button, card, row and step, where four copies did
before, and one seam says which host is touch-first (the phone; the TV
and the Windows app keep the look from the start). On a touch-first
host nothing is lit until a pad moves the focus, and the next thumb
hides it again, Material's own focus overlay included. Every host
screen with a title bar takes it from one shared screen that leaves
the phone's bar free above it, so the title and its back arrow are
below the bar, never under it; the round still draws behind the bar.

## Status row

M12 bug 1107f fixed at G4: a touch-first host shows no focus look until a pad moves it and lights a button only under
a thumb, one shared look and one touch-first seam replace the four copied styles, and every host screen's title bar
sits below the phone's bar with its back arrow in the clear (the menus lose 52 px of body, which makes the picker and
the join screen scroll a little); open: whether to win that room back, and the stats/join-panel questions.

## Delete

- controller_app/test/bug_1107f_after_test.dart
- controller_app/test/probe_metrics_test.dart
