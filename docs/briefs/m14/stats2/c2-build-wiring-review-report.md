# c2-build-wiring review

## Summary

`small fixes` — 0 must, 1 should, 4 could.
- The phone-wiring test asserts `loadIdentity(...).appVersion == appWithBuild(appVersion, buildNumber)`, and under the default `buildNumber` "dev" that is the bare `appVersion`, so it still passes if `storage.dart:49` goes back to `appVersion`; it failed on the old code only because the file did not compile (`app_with_build_test.dart:24`).
- `packages/metrics/lib/src/session_clean.dart:44` still documents a local build as "0.14.0+dev", a string both apps no longer send.
- `HostIdentity.appWithBuild` takes the build from `versionLabel`, a display string, so a label rewording drops the build from the stats (`host_identity.dart:68`).

## Findings

- **should** controller_app/test/app_with_build_test.dart:24 the test compares the identity's `appVersion` with the same `appWithBuild(appVersion, buildNumber)` expression that `storage.dart:49` calls, so under the local "dev" build the two are both "0.14.0" and the test would pass unchanged if the wiring were reverted → give `loadIdentity` (or the identity builder) the build number as a parameter and assert the literal "0.14.0+654", or drop the test and say the wiring is proved only by the const.
- **could** packages/metrics/lib/src/session_clean.dart:44 the doc says "a local build '0.14.0+dev'", but after this job both apps send the bare version when the build is not digits, so it describes a string the apps never send → reword it (a metrics job) or send "+dev", which `splitAppBuild` already strips.
- **could** packages/party_host/lib/src/host_identity.dart:68 the build number is a regex match on `versionLabel`, a display string, so any label rewording ("1.2.3 build 45", a TestFlight label) silently drops the build from the session's `build` cell → add a `build` field to `HostIdentity` (as it already has `appVersion`) and build the string from it in a later job.
- **could** controller_app/lib/src/app_info.dart:18 the "version+build" rule now lives in three places with two limits — any digit count here, digits in a trailing "(...)" at host_identity.dart:75, 1–9 digits at session_clean.dart:40 — so a 10-digit build would be sent and then read as no build → share one rule or match the 9-digit cap.
- **could** packages/party_host/lib/src/host_service.dart:132 and :160 the hello and the simulated controllers keep the bare `appVersion` as the brief asks, but no test pins that (the new host test reads only `hostApp` at host_app_with_build_test.dart:53) → add one assertion on the server's/sims' bare version to the new host test file.

## Decisions to confirm

- The phone-wiring test (report decision 2) is the test the brief asked for, but it cannot fail on a regression of the wiring; fixing that needs a build-number parameter on `loadIdentity`, which is a design call, so confirm keep-as-is or a later job.
- Local builds send "0.14.0", not c1's documented "0.14.0+dev" (report decision 1): the CSVs read the same either way, but the session JSON of a local build has no `build` key — confirm that is wanted over keeping a "dev" mark.
- The phone's hello now carries "+build", so a host's player rows, saved pairings and the TV's controller list (`tv_test_app/lib/src/ui/home/controllers_panel.dart:165`) show "0.14.0+654"; the brief's "everything else keeps appVersion" reads against its step 1 — confirm the display is acceptable.

## Could not check

- Whether the runner's fail-on-the-old-code check looks at each test or only at file load; `run.log` records only the job's exit and turns, and I did not re-run the files against the old code.
- Why `run.log:8` records result 4: the only paths outside `--allow` are `site/shots/*.png`, which `controller_app/test/site_shots_test.dart` writes whenever the phone suite runs and `run-jobs.sh` drops as churn, so the report's A4 line holds for authored files but not for the run's tree.
- The full phone suite: I ran the new controller test file, the host suite, format and analyze, but not `check.sh phone`, because it rewrites `site/shots` (files I may not change).

## Commit message

```
review: c2-build-wiring, "version+build" as the stats app string

Verdict small fixes: no musts, one should, four coulds. The phone-wiring test compares the
identity's appVersion with the very expression storage.dart calls, so with the local "dev" build
it passes even if the wiring is reverted; it failed on the old code only because the file did not
compile. The metrics doc still says a local build sends "0.14.0+dev"; the host takes the build
from a display label; the format rule now exists three times with two digit caps; and nothing
pins that the hello and the sims keep the bare version. Checks re-run: format, analyze, host (485
tests) green, new phone test file 3/3.
```

## Status row

m14 stats2 c2: reviewed — host and phone send "version+build" as the stats app string, format/analyze/host green (485 tests); open: one should (phone-wiring test cannot fail on a regression, needs a build parameter or a decision) and four coulds; docs/decisions.md unchanged.

## Delete

- none
