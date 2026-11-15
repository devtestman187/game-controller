# M14 stats2 fix3-apps: review

## Summary

Verdict: **small fixes**.

must 1 · should 0 · could 1.

- The change is right and where it says: one commit (`d27b9ed`), the five `allow:` files plus the report; format 0 changed, `dart analyze` on the five files finds no issues, `tools/check.sh host` gives 490 tests and `phone` 484, as the report says.
- The caps hold: `loadIdentity(prefs, build: '654')` → `'0.14.0+654'`, `'123456789'` → `'0.14.0+123456789'`, `'1234567890'` → `'0.14.0'`; `_tenDigit.appWithBuild` → `'0.11.0'`; `(stats as LiveStats).hostApp` follows the identity, and the welcome's `server.appVersion` stays bare.
- The must is a brief contradiction, not a wrong fix: three of the five new host tests (`host_build_cap_test.dart:52,67,72`) pass on the old code, because item 1(c) asks for assertions on behaviour that was already right; the report says so and no lib change can make them fail.

## Findings

- **must** packages/party_host/test/host_build_cap_test.dart:52,67,72 the nine-digit, welcome and sim tests pass on the code as it was (`_buildInLabel`'s old `\d+` kept nine digits, and `host_service.dart:132,160` already sent the bare `appVersion`), against the brief's "each new test ... must fail on the code as it was", and `controller_app/test/identity_build_test.dart:25`'s "dev" case would too → Claude either records 1(b)'s allowed case and 1(c) as by-nature guards in the brief/REVIEW, or the nine-digit case folds into the ten-digit test; no lib change makes them fail.
- **could** packages/party_host/test/host_build_cap_test.dart:67 the name says "build in the label or not" but the test runs only the 9-digit label, so its "(dev)" half is never exercised here → drop "or not" from the name, or add a "(dev)" identity and assert the same bare `'0.11.0'`.

## Decisions to confirm

- Decision 1 (a private `_maxBuildDigits` in each writer) is forced, not a preference: `packages/metrics/lib/metrics.dart:9-20` exports neither `maxBuildDigits` nor `splitAppBuild`, so a shared one needed a file outside `allow:`; the two writers are the only places that build `version+build` (`storage.dart:53`, `host_service.dart:152`).
- Decision 2 (`build` as `String`) keeps `appWithBuild`'s digits-only rule in one place and lets the test pass CI's `'654'` unchanged; `loadIdentity` is now at the guideline's five-parameter limit.
- Decision 3 ((c) in the host test): `(stats as LiveStats).server.appVersion` is `HostDetails.appVersion` (`host_server.dart:362`), the field the welcome carries, so the assertion is on the value a phone would receive.
- Decision 4 (a real socket and a 5 s timeout) follows `live_host_service_test.dart:69,109`; the test subscribes to `service.changes` before the sim's connect can complete, so no event is missed.

## Could not check

- Tests-first order: the job is one commit (`git log 1755692..d27b9ed` lists only `d27b9ed`), so fail-then-pass is the report's word.
- That exactly 2 of 5 host tests failed on the old code: reasoned from the old regexes in the diff, not run (I may not check the old tree out).
- `tools/review.sh`'s "0 fail, 1 note": not re-run; the 9 at `app_info.dart:23` is `_maxBuildDigits`'s value.
- There is no `run-findings.md` in this folder, so no runner entries for this job.

## Commit message

Review: stats2 fix3-apps caps correct; 3 host tests pass on old code

- Read the change against the guidelines, the review rules and its brief.
- One commit, five allow: files plus the report; format clean, analyze
  clean, host 490 and phone 484 as reported.
- The caps and loadIdentity's build parameter hold on every computed
  value; the welcome and the sims still get the bare version.
- One must: three of the five new host tests pass on the old code,
  because the brief's 1(c) asks for unchanged behaviour; Claude rules.

## Status row

- M14 stats2 fix3-apps reviewed: findings 3, 5 (both writers) and 10 are done and correct, host 490 / phone 484 green, format and analyze clean; open: the brief's "each new test must fail on the old code" against item 1(c) (3 of 5 host tests pass on it, needs Claude's ruling) and the welcome test's "or not" name.

## Delete

- none
