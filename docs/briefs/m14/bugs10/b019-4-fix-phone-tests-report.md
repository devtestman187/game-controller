# b019-4 fix phone tests: the two phone gaps from the run review

## Summary

Two test gaps from the bugs10 run review, both test-only.

- `fake_stats.dart`: `FakeStats.failWith` (an `Object?`); while set, `pause()`
  and `resume()` throw it instead of counting, as `FakeUploader` fails its
  upload.
- `phone_host_stats_lifecycle_test.dart`: one case with `HostChoice.onDevice`
  (background → `pauses` 1; return → `resumes` 1, `pauses` 1), and one with a
  failing store (`StateError('the store is closed')`) which gives exactly
  `Stats pause failed: Bad state: the store is closed` and `Stats resume
  failed: Bad state: the store is closed`, counters 0, `takeException()` null.
- `_hostWithStats` takes `{HostChoice choice = HostChoice.onPhone}`; a helper
  reads the failure lines from `party.logProvider`.

Tests: the file 7 passed (5 + 2 new); `tools/check.sh format analyze phone`
PASS, PASS, PASS with 475 phone tests (473 + 2). Both cases pass on the
unmodified `lib/` code, as the brief's tests-first exemption expects.

Decisions:
1. `failWith` throws before the counter moves: a failed call did no work, so
   "threw" and "counted" stay apart without a second flag.
2. One `failWith` for both calls: the review wants both to fail together.
3. One test runs the whole lifecycle: the pauses-then-resumes log order needs
   both halves in one run.
4. The log comes from `party.logProvider`, which already feeds
   `PhoneHost.live`'s sink, so no new seam; the helper matches the two step
   prefixes, since the service also logs `Stats are off: ...`.

## Tests written (values as asserted)

- `"Show on this device" ends and retries the session too`: `playsHere` false,
  `pauses` 1 after paused, `resumes` 1 and `pauses` 1 after resumed.
- `a failing stats store is logged once and never thrown`: the two lines above,
  in that order, `pauses` 0, `resumes` 0, `takeException()` null, and the
  return completes (`host.away.value` false), so the callback did not throw.

## Self-check (review-rules part A)

1. **Every host setup.** The TV, PC and a joined phone build no `PhoneHost` and
   are untouched. "Play on this phone": the failing-store case (own player
   paired). "Show on this device": the new onDevice case. An older build: no
   protocol or message change, so nothing to test.
2. **When kept state starts and ends.** Nothing new is held: `failWith` lives
   on the fake only, and the job's one new runtime-free behaviour is the log
   line, which lands in the host's existing `LogBuffer` (500-line cap) and ends
   with the app's log. The host is disposed in every case.
3. **How a new state combines with the others.** Unchanged: this job adds no
   state to shipped code. The failure case shows a failing stats store leaves
   the presence alone (the round still comes back, `away` false).
4. **Stay in the job's folder.** Only `fake_stats.dart`, the phone test file
   and this report.
5. **Stop rather than overstep.** Not needed; nothing outside `allow:` was
   required.

## Hand-over

- `FakeStats.failWith` is the fake's only new member; every caller that does
  not set it behaves exactly as before (the other phone tests still pass).
- The onDevice case depends on `enterHostMode` waiting for `host.started` (m12
  bug 1108a): that host pairs no own player, so the presence is what the case
  drives.
- `phone_host_stats_lifecycle_test.dart` is 178 lines (cap 500), `fake_stats.dart`
  94 (cap 400).

Open: the device check the run review asks for (B-019 is still "Fixed,
unverified: needs device check"); findings 3, 5, 8, 9 and 10 of the review are
other jobs.

## Commit message

Phone tests: the failing stats store and "Show on this device" (B-019)

The run review found two gaps in the phone host's stats wiring: the
logged-never-thrown path of `_statsStep` had no test, because `FakeStats` could
not fail, and every case entered "Play on this phone", so the claim that both
host modes get the same lifecycle listener was unproven. `FakeStats` now has a
`failWith`, like `FakeUploader`, which `pause()` and `resume()` throw. One new
case drives a failing store through a background and return and checks two
failure log lines, no counter move and nothing thrown out of the framework
callback; another enters "Show on this device" and checks the same pause and
resume calls as onPhone. Phone suite 475 green, format and analyze clean.

## Status row

Bugs10: findings 4 and 7 of the run review fixed (FakeStats.failWith and the onDevice case, phone suite 475 green); open: the iPhone host device check, and findings 3, 5, 8, 9 and 10.

## Delete

- none
