# f5 report: launch_home_test — two positive controls and the hosting guard

## Summary

Changed only `controller_app/test/launch_home_test.dart`. Repairs the two tests the wave 6 review
found passing on the base, and adds the hosting-guard test the review asked for. `tools/mine.sh`
passes: 12 tests in controller_app, all OK. `dart analyze` on the file: no issues.

Changes:

1. "Join a Game on the launch Home opens Connect": asserts `HomeText.joinGame` is on screen before
   `reachConnect`. On a launch that opens Connect directly the finder is empty and the test fails.
2. "a link that dropped after connecting does not return to Home": a positive control runs first on
   its own `pumpApp` (connecting, then failed, expects one Home). The dropped sequence then runs on a
   second `pumpApp` and still expects no Home.
3. New test "a connect that fails on the pad while this phone hosts does not open Home": a live
   `hostingProvider` (started with `playsHere: false`, "Show on this device"), then connecting and
   failed on the pad, expects no Home.

Test counts seen: `tools/mine.sh` reported `OK 12 tests controller_app`. Those 12 are the 4 loop
cases (2 looks × 2 sizes), 7 single tests (Join, Try, Back, paired live, paired gone, failed connect,
dropped link), and the new hosting test.

## Decisions

- Kept the dropped-link positive control in the same `testWidgets` as the dropped run, using a second
  `pumpApp`, as the brief asks ("on its own app, then a separate app"). The existing test at line 100
  ("a connect that fails on the pad shows Home once") is also a positive control for the failure
  path, but the brief's item 2 needs one inside the dropped test, so I did not rely on it.
- Hosting test: built the host with `hostingProvider.notifier.start(playsHere: false)`. That needs no
  player link or puzzle library, so the test avoids `pumpHostApp`, which cannot set `paired` or
  `discovered`. The overrides mirror `pumpHostApp`'s list (`phoneHostOverrides` with a temp directory,
  fake advertiser, sound and screen-awake). `hostContainer` from `support/host_app.dart` reads the
  container.
- The hosting test disposes its host with `tester.runAsync(host.dispose)` at the end, as
  `host_lifecycle_test.dart` does. Nothing disposes it if an `expect` fails first.
- Did not add a TV-look pass (the wave 6 "should" at launch_home_test.dart:27). The brief does not ask
  for it, and the file's `for` loop covers the menu looks only.

## Computed values

- `liveHost('tv-1')`: the paired launch finds `tv-1` live, so the pad opens.
- Positive control (dropped test, first app): `homes()` finds 1 Home after connecting → failed.
- Dropped run (second app): `homes()` finds 0 after connecting → reconnecting → failed.
- Hosting test: `host.live` is true; after connecting → failed on the pad, `homes()` finds 0.

## Self-check (review-rules part A)

1. Host setups: this test covers a phone on "Show on this device" (`playsHere: false`) with a
   joined-phone pad (paired, `liveHost`). A TV or PC host and "Play on this phone" are not covered
   here. Peer-version: not covered.
2. Kept state: `hostingProvider` starts null; the test sets it live and disposes it at the end.
3. Combination with pause menu, host away, player away, "Get ready", dropped link, results, leaving:
   covered for the dropped link (test 2) and the hosting guard (test 3) only.
4. Scope: only `controller_app/test/launch_home_test.dart` and this report changed.
5. Stops: none.
6. Looks: the loop still covers only `sunny` and `night` (menu looks). No TV-look pass was added.

## Not verified

- The new expectations were not run against the pre-change code, so "fails on the base" for the three
  edited tests is not measured here. The reasoning comes from the wave 6 review's notes on the base.
- `tools/mine.sh` printed `churn: reverted 3 generated file(s)`. Afterwards `git status` no longer
  shows `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h`, or `generated_plugins.cmake`
  as modified. Those were uncommitted changes before this job. The churn revert restored them, so
  the working tree no longer has them. The runner should check whether that was wanted.

## Commit message — a draft

Repair launch_home_test controls and guard hosting

Join a Game now asserts Home is on screen before it taps through. The dropped-link test gets a
positive control (a connect that fails returns to Home) on its own app, then runs the dropped
sequence on a separate app. A new test shows that a phone hosting ("Show on this device") does not
open Home when a connect fails on the pad, which exercises the guard in launch_route.dart.

## Status row

f5 done: launch_home_test has the Home assertion, the dropped-link positive control, and the hosting-guard test (12 tests pass, analyze clean). Open: the new expectations are not run against the pre-change code; the TV-look pass for the launch test (wave 6 should) is not added.

## Questions

1. The churn revert in `tools/mine.sh` restored three uncommitted `tv_test_app/windows/flutter` files to HEAD. Is that expected for this wave?
2. Should the hosting test get a TV-look pass too (wave 6 "should" at launch_home_test.dart:27)?

## Delete

- none

## Hand-over

Changed: `controller_app/test/launch_home_test.dart` (three repaired or added tests, imports for the host overrides). Written: this report. Nothing staged or committed.
