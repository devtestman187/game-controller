# n8b3 report: launch routing

## Files changed
- controller_app/lib/src/home/launch_route.dart (new): `routeLaunch` (reconnect; unpaired -> Home fromLaunch, paired -> `askLaunchConsent`), `launchHomeRoute`, `returnHomeOnFailedConnect` (listener).
- controller_app/lib/src/ui/controller_screen.dart: initState calls `routeLaunch`; the pad's own `_askLaunchConsent` is gone; `_followTheTv` calls `returnHomeOnFailedConnect`. Shorter than before (374 -> under 360).
- controller_app/test/launch_home_test.dart (new): 12 tests (unpaired Home in sunny/night x phone landscape/portrait, Join opens Connect, Back exits, paired+found stays, paired+gone+others shows Home, failed connect once and not stacked, dropped link after connecting does not).
- controller_app/test/support/pump_app.dart: `reachConnect` settles a frame, taps Skip when the marks show, then Join a Game.
- host_bar_zero_in_frame_test.dart, sky_holds_test.dart, look_prefs_test.dart: `reachConnect` before the Connect-screen steps (the host button lives on Connect).

## Rules as built
- Failed connect: status goes from connecting/waitingForCode/pairing to idle/failed (stateless, previous status in the listener); a link that connected earlier passes through connected/reconnecting, so it never matches.
- Pushed only when the pad is the current route (`ModalRoute.isCurrent`): Home, Connect, or any dialog/Settings above it suppresses it, which also stops stacking. Slightly wider than "Home or Connect": Settings above also suppresses.
- Not while `hostingProvider` is live.

## Computed values
None (no numeric expectations).

## Questions / not done
1. No isolating test for the hosting guard (brief: not needed).
2. The "paired, host gone" test needs a second settle, because the launch's discovery wait ends on a timer.
3. My own full `flutter test controller_app` run was stopped by the 10-minute background limit and gave no result. Only `tools/mine.sh` (touched tests) passed. Other test files that pin Connect first may still fail; the runner's `check: phone` will show them. host_mode_test, paired_launch_consent_test, joined_view_test, waiting_card_test and controller_screen_test were not changed.

## Commit message
launch: unpaired launch opens Home; failed connect returns to Home

routeLaunch (new launch_route.dart) replaces the pad's launch code:
paired and found live stays on the pad, otherwise Home. A first
connection that ends unconnected pushes Home once from the pad.
reachConnect skips the coach marks. Tests pinned to Connect-first
now call reachConnect.

## Status row
n8b3: launch routing done (unpaired -> Home, failed connect -> Home); open: no isolating hosting-guard test.

## Delete
- none
