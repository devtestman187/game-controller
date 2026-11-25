# f4 report: finish the Home-first launch

tests-first: exempt for the test-only fixes; the Home close has its own new test in launch_home_test.dart.

## Files changed
- controller_app/lib/src/home/phone_home_screen.dart: Home closes when demo mode turns on ("Try without a TV" on Connect), by the same `_close` rule as a connection (not while hosting live; after the consent prompt via `_closeWaits`).
- controller_app/test/launch_home_test.dart: new test, unpaired launch, Join, Try without a TV: Connect and Home gone, pad with the demo readout on screen.
- controller_app/test/connect_screen_test.dart: the remembered-host-gone case now expects Home, then `reachConnect`, then Connect and no client calls.
- controller_app/test/launch_consent_test.dart: the consent question sits on Home over Join a Game, so Connect is reached only after it is dismissed; then back lands on Home, Join opens Connect, no dialog (one ask per launch kept).
- controller_app/test/host_gyro_test.dart: gyro mode is turned on explicitly (see below).
- controller_app/test/support/site_shots.dart: unpaired `pumpPhone` calls `reachConnect`, so join.png still shows Connect.
- store_builds_test.dart needed no change: it passes with the Home close.

## host_gyro_test: test fix, not a regression
padOnScreenProvider is true whenever the phone does not host, and the pad (ControllerScreen) still sits under Home and Connect. The cause was timing: the launch restore of the saved gyro mode waits for a first sensor reading; an unpaired launch now spends more than that wait going through Home to Connect inside pumpApp, so the restore timed out ("No gyroscope readings", mode stayed dpad) before the test fed samples. The test now calls `setMode(PadMode.gyro)` itself, holds still, then tilts. No lib change.

## Computed values
None (no new numeric expectations).

## Checks
tools/mine.sh: ok, 6 files formatted, 1 package analyzed, 66 tests controller_app. Earlier the five named files were run alone and all passed.

## Questions
None.

## Commit message
Home closes on demo mode; fix five tests for the Home-first launch

"Try without a TV" on Connect now closes the Home beneath it, so the pad
with the demo link shows (same close rule as a connection).
Tests: remembered-host-gone expects Home, consent test follows the
Home route chain, gyro test turns the mode on itself, site shot join.png
reaches Connect through Home.

## Status row
f4: Home closes on demo; five tests fixed for the Home-first launch; nothing open.

## Delete
- none
