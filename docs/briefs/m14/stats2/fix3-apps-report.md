# M14 stats2 fix3-apps: findings 3, 5 and 10

## Summary

- **Finding 3 (phone test that cannot fail):** `loadIdentity` now takes `String build = buildNumber` and uses it for `appWithBuild(appVersion, build)`. A test can name a build, so `loadIdentity(prefs, build: '654').appVersion` is asserted against the literal `'0.14.0+654'` instead of against the expression the code calls. Existing call sites (no `build:`) are unchanged; the parameter list stays at five.
- **Finding 5 (two digit caps):** both writers now stop at the reader's 9 digits. `app_info.dart`'s `_buildCount` is `^[0-9]{1,9}$`, and `host_identity.dart`'s `_buildInLabel` is `\(([0-9]{1,9})\)$`, each with a `_maxBuildDigits = 9` constant documenting that `metrics`' `splitAppBuild` drops a longer one. A ten-digit build from either app now sends the bare version instead of a build the stats silently discard.
- **Finding 10 (hello untested):** the new host test asserts the bare version on what the host service actually sends: `server.appVersion` (the field the welcome is built from, with an identity whose label carries 9 digits) and a connected simulated controller's `appVersion` in `state.host.controllers` (platform `sim`). Both pass on the old code by design — they guard today's behaviour, they don't fix it.
- **Tests first:** both new files were written and run against the old code. `identity_build_test.dart` failed to compile ("No named parameter with the name 'build'", 3 arguments-mismatch errors); `host_build_cap_test.dart` failed 2 of 5 (`'0.11.0+1234567890'` where `'0.11.0'` was expected, in the `appWithBuild` test and in the service's `hostApp`). After the implementation both pass (3 and 5 tests).
- Checks: `tools/check.sh format analyze host phone` → all PASS (host 490 tests, phone 484). `tools/review.sh` → 0 fail, 1 note (the `9` in `app_info.dart:23`, which is the named `_maxBuildDigits` constant itself).

### Decisions

- **The cap is a private constant in each app's writer, not a shared one in `metrics`.** Finding 5 offered both; this job's `allow:` only has the two writers' files, so capping them (option 1) is the change that fits, and neither app gains an import of another package's internal limit. Each constant's doc names `splitAppBuild` so the two values stay tied.
- **`loadIdentity`'s `build` is a `String`, not an `int`.** It has to carry the local build's `'dev'` and reach `appWithBuild` unchanged, so the existing rule (`digits only, else bare`) stays in one place.
- **`(c)`'s two assertions live in the host test, not the phone test.** The hello's app version and the sims' come from `HostIdentity.appVersion` in `host_service.dart`, so only `party_host` can observe them; the phone's own hello is covered by the `loadIdentity` tests through the same `appWithBuild`.
- **The sim is observed through the host service, over localhost**, as `live_host_service_test.dart` already does (real socket, 5 s timeout). There is no other seam: `SimulatedControllers` is not exported and `ClientSnapshot` does not carry `appVersion`.

### Computed values

- `loadIdentity(prefs, build: '654').appVersion` = `'0.14.0' + '+' + '654'` = `'0.14.0+654'` (`appVersion` constant is `'0.14.0'`).
- `build: '123456789'` (9 digits, allowed) → `'0.14.0+123456789'`; `build: '1234567890'` (10, dropped) → `'0.14.0'`.
- `build: 'dev'` → `'0.14.0'` (not all digits).
- `_nineDigit` label `'0.11.0 (123456789)'` → `appWithBuild` = `'0.11.0+123456789'`; `_tenDigit` label `'0.11.0 (1234567890)'` → `'0.11.0'` (no match: after `'('` there are 10 digits before `')'`, so `[0-9]{1,9}` cannot reach the closing `)`).
- Service with `_tenDigit`: `(stats as LiveStats).hostApp` = `'0.11.0'`.
- Service with `_nineDigit`: `(stats as LiveStats).server.appVersion` = `'0.11.0'` (the welcome keeps the bare app version).
- Simulated controller (identity `_nineDigit`) in `state.host.controllers`, platform `sim`, connected: `appVersion` = `'0.11.0'`.

### Self-check (review-rules part A)

1. **Every host setup** — the change is in the "version+build" string only; a TV/PC host is `host_build_cap_test.dart`'s service tests, a phone hosting uses the same `HostIdentity` and service (same tests), a joined phone's hello is `identity_build_test.dart`. No setup differs; an older peer receives either `'0.11.0'` or `'0.11.0+123'`, both of which it already tolerated.
2. **When kept state starts and ends** — not affected: no timer, slot, cache or flag is added; the cap is a pure function of the build string.
3. **How a new state combines with the others** — not affected: nothing pauses, hides or blocks input.
4. **Stay in the job's folder** — only the five `allow:` files changed (two of them new).
5. **Stop rather than overstep** — nothing outside `allow:` was needed; the metrics side of finding 5 (`session_clean.dart:46`'s doc) is left to the job that owns that file.

### Questions / suggestions

1. Finding 5's other half (`session_clean.dart:46` says a local build sends `0.14.0+dev`) is untouched here: that file is outside `allow:`.
2. `maxBuildDigits` now exists three times (metrics, `app_info.dart`, `host_identity.dart`). When someone can change `metrics`, the cleanest end state is the option finding 5 names: one `appWithBuild` in `metrics` used by both writers.
3. `app_with_build_test.dart:24` still compares against `appWithBuild(appVersion, buildNumber)`; it is not editable here, but with `identity_build_test.dart` in place it is now redundant — a later job could drop it.

## Hand-over

- Changed: `controller_app/lib/src/app_info.dart`, `controller_app/lib/src/storage.dart`, `packages/party_host/lib/src/host_identity.dart`; new: `controller_app/test/identity_build_test.dart`, `packages/party_host/test/host_build_cap_test.dart`.
- Left open in this batch: findings 1, 2, 4, 6, 7, 8, 9, 11–14, and finding 5's `session_clean.dart` doc.
- Review note left on purpose: the literal `9` at `app_info.dart:23` is `_maxBuildDigits`'s value; `metrics`' identical constant carries the same note.
- No existing test file was edited and nothing outside `allow:` was touched.

## Commit message

Cap both apps' build numbers at the stats' 9 digits

- appWithBuild and HostIdentity.appWithBuild drop a build longer than 9
  digits, which metrics' splitAppBuild reads as no build.
- loadIdentity takes a build number (default buildNumber) so a test can
  check the literal "0.14.0+654" instead of the expression it calls.
- New identity_build_test and host_build_cap_test; the latter also
  asserts the welcome and the simulated controllers keep the bare
  app version (stats2 findings 3, 5, 10).

## Status row

M14 stats2 fix3: findings 3, 5 (apps' writers) and 10 done; finding 5's `session_clean.dart` doc and findings 1, 2, 4, 6-9, 11-14 open.

## Delete

- none
