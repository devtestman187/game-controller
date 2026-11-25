# n8b2 report: PhoneHomeScreen

tests-first: the new test file is new code with no earlier behaviour to fail on (the screen did not exist).

## Files
- `controller_app/lib/src/home/launch_consent.dart` (new): `askLaunchConsent(context, ref)`, the guard and ask of
  controller_screen.dart:107-112 / connect_screen.dart:62-68; returns the future of `askConsents`. Callers untouched.
- `controller_app/lib/src/home/phone_home_screen.dart` (new): `PhoneHomeScreen(fromLaunch)`, `homeSearchWait` (3 s).
  Find from `discoveryStateProvider` plus a timer started on the first frame; Join = `openConnect`; Play/Display =
  `launchHosting` after a mounted check; Settings and the name row push `SettingsScreen`; Search again =
  `discoveryProvider.restart()`. First frame asks consent; a connection under the prompt waits for the answer.
  PopScope: `fromLaunch` Back calls `SystemNavigator.pop`, else Back pops to the pad.
- `controller_app/test/phone_home_screen_test.dart` (new): 14 tests (16 reported by mine.sh with two looks cases each).

## Decisions
- Home closes itself with `Navigator.removeRoute(ModalRoute)`, not `pop`: it removes only its own route, so a Connect
  screen above it (which closes on the same connection with its own `maybePop`) is never double-popped, and a
  `fromLaunch` PopScope does not turn the close into an app exit.
- A connection is ignored while this phone hosts a live game (same rule as ConnectScreen).

## Computed values
- Search timing: the first frame starts the timer; `openHome` settles 500 ms; the test pumps 1 s (1.5 s, still
  searching, no highlight) then `homeSearchWait` (4.5 s > 3 s, Play highlighted).
- Highlight colours compared with `ToyLook.colors.good` (Join when found, Play when none or on a discovery error).

## Self-check
1. TV/PC host, phone hosts: Play here and Display here tests; joined phone: "a connection closes Home";
   older peer: n/a (no protocol change).
2. Consent flag: "Home asks once, and a second Home asks nothing".
3. Pause menu, host away, Get ready, results: not touched (Home is pushed only by tests). Dropped link: "a connection
   closes Home" starts from an idle link.
4. Stayed in the allowed files.
6. Looks: menu 568x320 and 375x667, TV 852x393 and 375x667 ("the looks" tests); no fixed heights added.

## Questions
1. The pad (ControllerScreen) alone overflows by 12 px on the right in the TV look at 568x320 (pumpApp paired, before
   Home is pushed). Not Home's; the TV-look test uses 852x393 instead. Needs its own job.
2. Host tests use `pumpHostApp` (unpaired, so a Connect screen sits under Home) because `pumpHostApp` has no `paired`.
3. The name row, with no nickname, is found by its "Tap to add your name" text.

## Commit message
PhoneHomeScreen: Home wired to Connect, hosting, Settings, consent

Adds PhoneHomeScreen (fromLaunch exits the app on Back, otherwise pops to
the pad) around HomeView: Join opens Connect, Play/Display start hosting
with no sheet, Settings and the name row open Settings. Find = hosts found,
none after homeSearchWait (3 s) or on a discovery error. askLaunchConsent
is the one consent ask for Home and, later, the pad. Not reachable from
launch yet (n8b3).

## Status row
n8b2 done: PhoneHomeScreen, askLaunchConsent and homeSearchWait with tests; open: routing from launch/pad (n8b3), coach marks (n8d1), pad overflow in TV look at 568x320.

## Delete
- none
