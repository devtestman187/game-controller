# wave2-789 f6 — tests for the demo-closes-Home branches

## Summary

- Changed one file: `controller_app/test/launch_home_test.dart`. No lib file touched.
- Added two tests for the demo starting while Home is open:
  - the demo starts while the launch consent prompt is up: Home stays until the answer, then closes once;
  - the demo starts while this phone hosts live: Home stays open.
- Renamed "Try without a TV on Connect closes Home too…" to "Try without a screen on Connect closes Home too…". Body unchanged.
- The "a connect that fails on the pad while this phone hosts" test now disposes its host in `try/finally`, so a failing `expect` still stops the host.
- Added imports: `dart:async` (for `unawaited`), `flutter_riverpod` (for `ProviderScope`), and `controller/src/providers.dart` (for `demoProvider` and `launchConsentAskProvider`).
- Test counts seen with `tools/mine.sh`: first run had 1 failing test (`the demo starts while this phone hosts live`), then fixed; final run `OK 14 tests controller_app`.
- The 12 pre-existing tests + 2 new = 14.
- Analyze: 0 findings on the file after the fixes (the first run had 3 errors and 1 warning, all mine: missing imports and an unused `app` variable; all fixed).

Decisions:
- The demo is started through `demoProvider.notifier.start()` rather than by tapping "Try without a TV", because the consent prompt covers Connect (the button is not reachable while the prompt is up). This is the same call `connect_panels.dart` makes.
- For the live-host test, the Home route is pushed directly over the pad (the same way `phone_home_screen_test.dart` `openHome` does), after the host starts, so the launch's consent check sees a live host and asks nothing (`askLaunchConsent` returns early), and `_promptUp` clears on its own.
- The live-host test asserts the demo state (`demoProvider` is true) rather than the demo readout: the readout is not on screen while this phone hosts, so asserting it failed (measured). The demo state is the real trigger.
- Tests use the `sunny` look at the default 852x393 screen only; no layout is measured by these tests.

## Self-check (docs/review-rules.md part A)

1. Host setups:
   - TV or PC host: not covered by these tests (not part of this job).
   - Phone on "Play on this phone": not covered by these tests.
   - Phone on "Show on this device": covered by `the demo starts while this phone hosts live: Home stays open` (`playsHere: false`).
   - Joined phone: covered by `Try without a screen on Connect closes Home too…` and `the demo starts under the launch prompt…` (the unpaired/pad path).
   - Peer one build older: not covered by these tests.
2. Kept state, start and end: `_promptUp` / `_closeWaits` (start: prompt up on Home's first frame; end: `consentNo` then Home closed) — `the demo starts under the launch prompt: Home stays until the answer, then closes once`. Nothing going on: `Back on the launch Home exits and never returns to the pad` (existing).
3. Combinations:
   - Launch prompt: covered by the new prompt test.
   - Live host: covered by the new hosting test.
   - Dropped link: `a link that dropped after connecting does not return to Home` (existing).
   - Pause menu, host away, player away, "Get ready", results, leaving: not covered by this job.
4. Stayed in `allow:` (only `launch_home_test.dart`, plus this report).
5. Nothing to stop for.
6. Looks: the new tests use the `sunny` look at 852x393 only. The look-sized widget (Home) is not measured here, so the "menu look and TV look" check is not met by these two tests; the existing look tests in `phone_home_screen_test.dart` cover that.

## Hand-over

- Tests-first: exempt — these tests pin behaviour f4 already built (per the brief header).
- Verified by running: `tools/mine.sh` (format, analyze, touched test) → `OK 14 tests controller_app`.
- Not run: `tools/check.sh` (the script runs it after the job, per the brief).

## Questions

1. `tools/mine.sh` printed `churn: reverted 3 generated file(s)`. I did not check which files these were. At the start of this session `git status` showed four modified files (`docs/briefs/m16/wave2-789/run.log`, `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h`, `generated_plugins.cmake`). If the churn revert touched any of those, the runner should check them. I have not run any git command to find out.
2. Should a Home-over-pad test cover the "Play on this phone" and "Show on this device" setups with a consent prompt too? Not required by this brief.

## Suggestions

- Consider a look test (the TV look at 852x393 and the menu look at 375x667) for the Home-with-demo case, so item 6 of the self-check is met for this path.

## Commit message — a draft

```
test: pin Home for a demo under the prompt and a live host

The demo can start while the launch consent prompt is up, or while this
phone hosts live. Home must wait for the answer then close once in the
first case, and stay open in the second. Add a test for each.

Rename the "Try without a TV" test to "Try without a screen"; its body is
unchanged. Dispose the host in a finally in the failing-connect test, so
a failed expect still stops the host.
```

## Status row

M16 wave2-789 f6: launch-Home tests for the demo under the consent prompt and under a live host added, rename and host-dispose done; 14 tests pass. Open: none in this job; the full suite runs once at the end.

## Delete

- none
