# bugs10 run review: B-019 (stats session on the phone host's app lifecycle)

## Summary

Verdict: **one fix batch**. Counts: **1 must, 6 should, 5 could**.

The five that matter most:
1. The phase-1 tests (`live_stats_lifecycle_test.dart`, the whole `pause()`/`resume()`
   core) were never run: the job's report says every runner command needed
   approval, so there is no count for them anywhere in the run.
2. `run-base` is phase 1's own commit, so `git diff <run-base>..HEAD` — the range
   every later review of this run is told to read — contains only the phone wiring.
3. `resume()` uploads but starts no session, and nothing tests pause → resume with
   the host's own player still paired: play after the return is unrecorded until
   some presence change (the phone's link timeout may supply one, or not).
4. The "a failure is logged, never thrown" path of the phone wiring has no test
   (`FakeStats` cannot fail).
5. `STATUS.md` still says bugs10 is not started and names a wave-3 review job that
   was dropped in f6cc9de.

Mark in the batch: **"Fixed, unverified: needs device check"** for all of B-019
(both phases: phase 1's cause was read from the code, phase 2's is the same
behaviour on a device), and additionally "tests never executed" for phase 1.
Owner-only questions: the iPhone host check, and whether a pause with remote
phones connected on "Show on this device" may end their session mid-round.

## Findings

Findings 4 and 7 are pinned by controller_app (phone) tests; 3, 5, 8, 9 and 10 by
`party_host` tests (host suite); 1, 2, 6 and 12 by no test (a run, or a document).

- **must** packages/party_host/test/live_stats_lifecycle_test.dart:159 the five phase-1 tests have never been executed (its report says every `flutter`/`dart`/script command needed approval), so `pause()`, `resume()`, the earlier `endSession` hand-over and the `dispose()` reorder have no evidence at all → run `tools/check.sh host` once and paste the count into the report; until then B-019 is unverified, not fixed (from: b019-1-stats-core)
- **should** docs/briefs/m14/bugs10/run-base:1 the base is 5467267, phase 1's own commit, so the run's whole change as the reviews read it (`diff run-base..HEAD`) holds only 42 lines of `phone_host.dart` and phase 1 is invisible → point `run-base` at 5467267's parent, or start the run's base before wave 1 (from: across jobs)
- **should** packages/party_host/lib/src/live_stats.dart:266 `resume()` only uploads, and `_checkPlayers` (line 174) starts a session only on a presence change, so after a pause with the host's own player still paired no session runs until a join/leave, which the phone test cannot see (its own test 1, line 171, accepts `session == null`) → call the presence check from `resume()` (start a session when players are still here) and add a pause → resume case with the own player kept (from: b019-1-stats-core)
- **should** controller_app/lib/src/host/phone_host.dart:181 `_statsStep`'s logged-never-thrown path has no test — `FakeStats.pause`/`resume` (fake_stats.dart:63, 68) cannot fail, so the only documented defence of a framework callback is unproven → give `FakeStats` a `failWith` (as `FakeUploader` has) and assert one log line and no throw (from: b019-2-phone-wiring)
- **should** packages/party_host/lib/src/live_stats.dart:318 a failing `uploadNow`, started by the `unawaited(uploadNow())` at the end of `endSession` inside `dispose()`, can arm a new 5-minute `_retry` after `dispose()` has already cancelled it (line 357), so a timer and an upload outlive the host → cancel `_retry` in the `finally` as well (or set a disposed flag uploadNow checks) and test dispose with a failing uploader (from: across jobs)
- **should** docs/briefs/m14/STATUS.md:7 the bugs10 paragraph still says "briefed, NOT started, waiting for the owner's go" and names "wave 3 b019-review", which f6cc9de dropped → replace it with the run's outcome and the open iPhone host check (from: across jobs)
- **should** controller_app/test/phone_host_stats_lifecycle_test.dart:203 every case enters `HostChoice.onPhone` (host_app.dart:173 is the default), so the report's self-check item 1 ("both phone host modes get the same listener. Test (e)") cites a test that only covers "Play on this phone" → add one case with `HostChoice.onDevice`, or drop the claim (from: b019-2-phone-wiring)
- **should** packages/party_host/lib/src/live_stats.dart:250 `endSession` clears `_ending` and `current` after its `await`, so a session that starts and ends during that write loses its `current` summary and its `_ending` → clear only when `_ending` is still `s` (from: across jobs)
- **could** packages/party_host/lib/src/live_stats.dart:1 the file is now 360 lines (326 before phase 1), over the guidelines' ~300, and the brief's own 380 cap hid the growth → split the upload queue and the ping sampling out at the next stats job (from: across jobs)
- **could** packages/party_host/lib/src/stats_service.dart:43 `pause()` ends and saves the session, which the name does not say, next to the round's pause, host away and player away → name it for what it does (`endForBackground`/`resumeForForeground`) or say "ends" in the name's first line (from: across jobs)
- **could** packages/party_host/test/live_stats_lifecycle_test.dart:245 the TV case waits 800 ms of real time and `waitFor` polls on `DateTime.now`, against guidelines §9's "no real time in tests" (the older `live_stats_test.dart` does the same) → drive the gap with `fake_async`, or keep it and record the exception in code-health (from: b019-1-stats-core)
- **could** docs/briefs/m14/bugs10/run-findings.md:1 it points at `flash-b019-2-phone-wiring-review.log`, which is not in the folder, and the review brief it refers to (`b019-2-phone-wiring-review.md`) stays committed with no report → delete that brief or fix the path in the next run's notes (from: across jobs)

## Open questions

- Phase 1's checks never ran for lack of approvals — run `host` before the batch's fixes land, or accept the batch as the evidence? Suggested: a first small job runs `tools/check.sh host` alone (it pins findings 3, 5, 8, 10).
- Phase 1 decision 3 (skip a session-gap rule keyed on `host.players` when the own player leaves the game) — leave it skipped? Suggested: yes, skip; the in-process player's presence ends with its link, and the rule would change TV hosts.
- Phase 2 decision 1 (a test-only `stats` parameter on the shipped `PhoneHost.live`) — keep the seam? Suggested: keep; it follows `nowMs` and is the guidelines' "inject an observer interface".
- On "Show on this device", a pause ends the session while remote phones are still connected and mid-round — intended? Suggested: yes (the host's timers stop), but say so in the owner row.
- Which STATUS row wording goes into STATUS.md? Suggested: phase 2's row plus "phase 1's tests never run" as the open item, and the iPhone host check as "Fixed, unverified: needs device check".
- The iPhone host device check (background mid-session, reopen, see it uploaded) is still open — whose? Suggested: the owner's next device pass; nothing in the batch can do it.

## Numbers against targets

- b019-1's brief asked for "tests seen failing and passing with counts": **no counts** (its report says the commands never started). Target missed; 5 new tests, evidence unknown.
- b019-2's brief: cases (a)–(e) all present; reported **473 phone tests (468 + 5)**, format and analyze clean, `review.sh` 0 fail 0 note. Met as reported (not re-run here).
- Run change as measured: 2 commits, 5 files, +277 / −5; `phone_host.dart` 218 lines (cap 380, met), new phone test 125 (cap 500, met), `live_stats_lifecycle_test.dart` 273 (cap 500, met).
- `packages/party_host/lib/src/live_stats.dart` 360 lines: over the guidelines' ~300, under the brief's 380.
- No `party_host` (host suite) count exists anywhere in the run: the target of "a count for every suite a job touched" is missed for phase 1.

## Could not check

- Any test result: `flutter`/`dart`/`tools/*.sh` need approval here, so nothing was run (phase 1's report hit the same wall).
- Whether `AppLifecycleListener` delivers `onPause`/`onResume` in the widget tests as claimed depends on b019-2's pass claim, which could not be reproduced.
- Real iOS/Android lifecycle sequences and the upload after resume: device-only.

## Commit message

Bugs10 run review: B-019 findings, the phase-1 evidence gap first

B-019 is two jobs (stats core, phone wiring) and was reviewed as one change
against the guidelines, the review rules and the briefs. The core finding: the
phase-1 tests were never executed, so the pause/resume behaviour rests on the
phone-side fake counts alone. Also: the run base is phase 1's own commit, so the
recorded diff hides half the feature; resume() starts no session for an own
player still paired; the never-throw path is untested; a failing upload can
leave a retry timer after dispose; STATUS.md still says the run was not started.
Everything else is small and ranked behind those.

## Status row

Bugs10 done: B-019 wired in both phases (stats core + phone lifecycle), phone suite 473 green as reported; open: the host suite was never run for phase 1, and an iPhone host device check.

## Delete

- none
