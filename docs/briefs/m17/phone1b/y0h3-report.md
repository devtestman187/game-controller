# y0h3 report: lobby old-app tests

## Summary

Done. The night frame test's phones now list the choices capability, so no old-app line draws in those frames. The old-app test has a guard that fails on the old behaviour, looped over both looks, and a test for the host-own controller and a player with no phone session.

Files changed:
- `packages/party_host/lib/src/testing/samples.dart`: `phoneInfo` takes an optional `capabilities` list, empty by default, passed to `ControllerInfo`.
- `packages/party_host/test/night_start_frame_test.dart`: imports `protocol`; the four default phones are built with `capabilities: [Capability.choices]`.
- `packages/party_host/test/night_start_old_app_test.dart`: the "no line when every phone lists the capability" test is replaced by "the old-app line names only the phone that does not list the choices capability", which pumps three phones (two current, one without the capability) and expects exactly one line, `Chris has an old app...`. Both new tests loop `HostLook.values` through `group`, as `shop_demo_test.dart` does. `_pumpNight` now mounts through `pumpHostLook` with an optional `look` (default menu) and returns the fake. The new local test has an `isLocal` controller (no capabilities) and a keyboard local player from `fake.gameHost.addLocalPlayer`; it expects no "old app" text at all.
- `packages/party_host/test/night_screens_test.dart`: not changed.

Test counts: `tools/mine.sh` ran the touched tests: 44 tests in `packages/party_host`, all OK. The first run failed on two of my own mistakes, fixed: a missing `remoteAddress: null` in the local controller, and an unused `host_harness.dart` import. The first run also reported "The Dart compiler exited unexpectedly" for `night_start_frame_test.dart`; the second run compiled it and passed, and I did not find a cause.

Computed values: the guard expects the sentence "Chris has an old app and will play with simple buttons." once, and `textContaining('old app')` to find exactly one widget. The old-phone count in the local test is 0: no line is found.

Decisions:
- Kept the brief's `phoneInfo` change even though it makes six parameters (see Questions).
- The "player with no phone session" is a keyboard local player (`addLocalPlayer`), not a dropped or away player; it has no controller, so it is excluded by construction.
- Other tests in the file still mount the menu look only; the brief asked for the loop in the new tests.

## Self-check (review-rules part A)

1. Host setups: covered by the existing frame tests at 640x360, 852x393, 1024x768, 1280x800 and 1920x1080 (menu look) and the new guard and local tests in both looks. Lobby setups for a TV and a phone host are not a separate case here.
2. Kept state: none added.
3. Combinations with pause, host away, "Get ready", dropped link, results, leaving: not covered by this job.
4. Stayed inside `allow:`.
5. No stop needed.
6. Looks: the new guard and local tests run in the menu and TV looks; the other old-app tests run the menu look only.

## Hand-over

- Not run: the fail-first claim for the guard is by reading the assertions (a missing line fails `findsOneWidget`; a line for every phone fails `textContaining` `findsOneWidget`). I did not run the test against the old code.
- `night_screens_test.dart` was not touched, so `tools/mine.sh` did not run it.

## Questions

1. `phoneInfo` now has six parameters, one over the five-parameter limit in the coding guidelines. Should it take a value object, or is the brief's change enough?
2. Should the "player with no phone session" case also cover a dropped (away) player, which is a separate route in the server game host?
3. Should the other old-app tests in this file also move to both looks?

## Commit message — a draft

phone1b y0h3: old-app tests name only phones without choices

The night frame test's four phones now list the choices capability,
so no old-app line draws in those frames. phoneInfo takes an optional
capabilities list, empty by default, for that.
The guard test now pumps current and old phones together and expects
the line only for the old one, in both looks. A new test checks that
a host-own controller and a player with no phone session are neither
named nor counted.

## Status row

phone1b y0h3: done (old-app guard looped over both looks, written to fail on a missing or always-shown line but not run against the old code; host-own and no-session local player covered; frame test passes with choices; mine.sh 44 OK). Open: phoneInfo is six parameters, away players not covered, night_screens_test.dart not run.

## Delete

- none
