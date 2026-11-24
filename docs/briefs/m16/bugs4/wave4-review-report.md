# Wave 4 review: nh1 and nk1

## Summary

- Verdict: **small fixes**
- Counts: must 0 · should 4 · could 2
- 1. `night_end_client_test.dart:137`: the older-host test's "no event" check cannot fail (the host never sends a night_end).
- 2. `nh1-report.md:41`: claims the "Play on this phone" and "Show on this device" setups are covered; no test uses them.
- 3. `nh1-report.md:67`: says the three tv_test_app generated files left `git status`; `git status` still lists all three as modified.

## Findings

- **should** packages/connection/test/night_end_client_test.dart:137 `expect(events, isEmpty)` in the older-host test passes whatever the client does with a night_end, because that host never sends one → delete this expectation and the "no event" part of the test name, and keep the players checks at :138-139.
- **should** docs/briefs/m16/bugs4/nh1-report.md:41 self-check 1 says the "Play on this phone" and "Show on this device" setups are covered by `phone-2`, but night_end_send_test.dart:37 opens `phone-2` as a plain socket phone with no capability, and no test opens either of the two setups → reword the line to say those two setups are not tested.
- **should** docs/briefs/m16/bugs4/nh1-report.md:67 says the three `tv_test_app/windows/flutter/generated_plugin_registrant.*` and `generated_plugins.cmake` files "no longer appear in git status", but `git status --short` now lists all three as ` M` → reword to their current state, and have the designer check their content against what was there before the run.
- **should** docs/briefs/m16/bugs4/run.log:64 `mine.sh` "dropped generated churn outside its list" for nh1 and again for nk1 (run.log:66), reverting three files the jobs did not own → the runner should only revert files the job itself changed; this is a tool fix, not a change to nh1 or nk1.
- **could** docs/protocol.md:244 says a phone "shows it after the host reveal, on its results card", which nk1 does not build (nk1-report says no UI) → reword to say the results card is a later job. This file is not one the jobs touched.
- **could** packages/connection/lib/src/client_controls.dart:47 the doc says the stream gets night ends "only to a phone that listed [Capability.night]", but the client never checks its own listing; the host's gate (host_server.dart:232) does → say the host sends it only to a phone that listed night.

## Decisions to confirm

- nk1: `client_messages.dart:62-63` gates `night_end` on `isConnected` only. The rating, layout and status handlers also check the phone's own listing (`client_messages.dart:94,98,102`). This is harmless while hosts only send to listing phones, but a host bug would reach the phone. Confirm this is intended.
- nk1: `controller_identity.dart:53` makes every phone advertise `night`, including phones whose app has no card yet. The capability list is decoded as plain strings (`packages/protocol/lib/src/messages.dart:121`), so an older host should not fail on it. I did not run a host to confirm.
- nh1: `game_host.dart:103-106` says the night's end is "sent once", but neither `server_game_host.dart:258` nor `memory_game_host.dart:117` guards against a second call. The card job that calls it must send once.

## Could not check

- Test counts in the reports (controller_app 18, connection 53, connection 5, m14 6 of 6) are the workers' claims. `run.log` holds no test output, and I did not re-run tests (this job changes no code).
- Whether the "Play on this phone" and "Show on this device" setups receive a night_end at all: no code path for them was read.
- The contents of the three tv_test_app generated files before and after the run; I can only see their status (` M`).
- File sizes: `server_game_host.dart` (360 lines) and `host_fakes.dart` (365) come from nh1-report.md:63; I did not count them. No line I read in the changed lib files is over 120 columns.
- The "passes on the old code" check: run-findings.md does not exist, and the new test files do not compile on the old code, so they fail there.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

docs: wave 4 review of nh1 and nk1 (bugs4)

Review only, no code changed. Records four should findings (one
vacuous assertion in night_end_client_test.dart, two report lines that
overstate coverage or git status, and mine.sh reverting three generated
files outside the job's list) and two could findings.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 bugs4 wave 4 review: done (small fixes: 0 must, 4 should, 2 could). Open: Claude verifies the should findings; the vacuous older-host assertion and the nh1 coverage line need a worker fix; the mine.sh churn revert needs a runner fix.

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`. You can't delete files: the script deletes these after you finish.

- none
