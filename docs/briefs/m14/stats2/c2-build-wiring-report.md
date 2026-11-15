# M14 stats2 c2-build-wiring — report

## Summary

The host and the phone now send "version+build" as their stats app string;
before, only the bare `appVersion` reached the stats although `versionLabel`
("0.14.0 (654)") and `buildNumber` ("dev" locally) already held the number.

- `controller_app/lib/src/app_info.dart`: new `appWithBuild(version, build)`,
  joining the two with a plus when `build` is digits, else the bare `version`.
- `controller_app/lib/src/storage.dart`: `loadIdentity` sets the controller
  identity's `appVersion` to `appWithBuild(appVersion, buildNumber)`.
- `packages/party_host/lib/src/host_identity.dart`: new getter `appWithBuild`
  = `appVersion` plus the digits in `versionLabel`'s trailing "(...)", else
  `appVersion` ("(dev)").
- `packages/party_host/lib/src/host_service.dart`: `LiveStats(hostApp:)` takes
  `identity.appWithBuild`; the hello, sims, logs and UI keep `appVersion`.
- New tests: `controller_app/test/app_with_build_test.dart` (3) and
  `packages/party_host/test/host_app_with_build_test.dart` (3).

Tests: both new files failed on the old code ("undefined getter
'appWithBuild'", a load failure for each file), then passed 3/3 and 3/3; no
existing test pinned the changed strings, and the full suites pass unchanged.

Decisions: digits-only rule on both sides rather than a "dev" special case
(guidelines §2); the phone test checks the wiring
(`loadIdentity(...).appVersion == appWithBuild(appVersion, buildNumber)`), as
the const is "dev" under test; the host test reads
`(service.stats as LiveStats).hostApp`, the cast the existing host-service
test already uses; `party_host` repeats the rule instead of importing the
app's function (guidelines §1); everything else keeps `appVersion`.

## Details

Computed values (checked against the rule):
- `appWithBuild('0.14.0','654')` = "0.14.0+654"; `('0.14.0','dev')` = "0.14.0";
  `('0.14.0','')` = "0.14.0".
- `HostIdentity(appVersion: '0.11.0', versionLabel: '0.11.0 (123)')`
  `.appWithBuild` = "0.11.0+123"; label "0.11.0 (dev)" = "0.11.0".
- Local runs: `buildNumber` is "dev", so the phone's identity appVersion stays
  "0.14.0" locally; with CI's BUILD_NUMBER=654 it is "0.14.0+654".

Decisions:
- **Digits-only rule instead of a "dev" special case.** Both sides append only
  when the build part is all digits, so "dev" and "" fall out of the same rule
  (guidelines §2: no special cases) and a malformed number never reaches stats.
- **The phone test asserts the wiring, not a literal.** The build number is a
  compile-time const, so under test it is "dev"; the test therefore checks
  `loadIdentity(prefs).appVersion == appWithBuild(appVersion, buildNumber)`,
  which differs from the old behaviour in any build that defines one.
- **The host test reads `(service.stats as LiveStats).hostApp`**, the cast the
  existing `live_host_service_test.dart` already uses (`StatsService` has no
  `hostApp`); the service is built but not started.
- **No host-side import of the app's function.** `party_host` may not import
  an app (guidelines §1), so the getter repeats the rule on `versionLabel`.
- **Everything else keeps `appVersion`**: hello (`host_service.dart:132`),
  simulated controllers (`:160`), startup log (`:222`) and the log export
  header (`host_log_export.dart:18`) still say the bare version / the label.

Self-check (review-rules.md part A):
1. Host setups: TV/PC host and a phone hosting both build `HostIdentity`, so
   both send "version+build" (host test); the phone's own controller identity
   does too (phone test). Joined phones and one-build-older peers only read
   `appVersion` in the hello, unchanged.
2. Kept state: nothing held, timed or remembered — the strings are values
   passed once at construction.
3. New state: none; no pause, hide or wait path touched.
4. Stay in the job's folder: only files under `allow:` were written.
5. Stop rather than overstep: nothing outside `allow:` was needed.

## Hand-over

- The TV app (`tv_test_app`) already supplies `appVersion` and `versionLabel`
  to `HostIdentity`, so it gets "version+build" with no change; not in `allow:`.
- The phone's host identity (`controller_app/lib/src/host/phone_host_setup.dart`)
  passes `versionLabel` from `app_info.dart`, which holds the build number, so
  a phone hosting a game now records "0.14.0+654" as the session's app.
- The player rows in a session still record the phone's hello `appVersion`,
  which now also carries "+build": that is the brief's step 2 intent.
- `docs/decisions.md` was not touched (outside `allow:`); if the "version+build"
  format should be a written decision, it needs a later brief.
- `tools/review.sh` was not run here; `tools/check.sh format analyze host phone`
  passes.

## Commit message

Send "version+build" as the stats app string

The stats recorded only the bare app version, so two builds of one version
were indistinguishable in a session's host_app cell (and in a phone's player
rows). The host now passes HostIdentity.appWithBuild to LiveStats: appVersion
plus the digits in the version label's "(...)", e.g. "0.11.0+123", and the
bare version when the label says "(dev)". The phone builds its controller
identity's appVersion with the new appWithBuild(version, build), which appends
the number only when it is digits. The hello, the logs and the UI keep the
bare version. New tests cover both sides and the service wiring.

## Status row

c2-build-wiring done: host and phone stats app strings are "version+build", tests green; open: nothing in this job (TV app's identity is unchanged and already carries the build via versionLabel).

## Delete

- none
