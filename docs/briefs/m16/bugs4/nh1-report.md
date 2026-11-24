# M16 bugs4 nh1 — GameHost.showNightEnd

## Summary

- Added `GameHost.showNightEnd(NightEndMessage message)` (abstract, documented: sent once when the awards reveal ends or is skipped, to every paired phone that lists `Capability.night`, with or without a view).
- `ServerGameHost.showNightEnd` is `server.sendToAll(message)`. The gate is already in `host_server.dart` `capabilityFor`: `NightEndMessage() => Capability.night`, so a phone without the capability gets nothing. No change was needed there.
- `MemoryGameHost` and `FakeGameHost` (`host_fakes.dart`) record each call in `shownNightEnds`, as `showResults` does with `shownResults`.
- New test file `packages/connection/test/night_end_send_test.dart`, two tests per transport (in-process and socket), written first. Before the lib change it failed to compile: `showNightEnd` isn't defined on `ServerGameHost` (2 analyzer errors, load failure).
- After the change: `tools/mine.sh` reports `OK 5 tests packages/connection`, `OK 1 tests packages/party_host`, and `RESULT: ok`.
- `flutter test packages/connection/test/m14_test.dart`: All tests passed (6 of 6 reported; the showResults test is "a round's end shows each viewer its own result, and the view stays open").

## Self-check (review-rules part A)

1. Host setups: a TV/PC host is the `ServerGameHost` over a real server in the new test (both transports). A phone on "Play on this phone" / "Show on this device" and a peer one build older are covered by the `phone-2` phone that lists no capability and gets nothing. A joined phone that lists `night` gets it (`phone-1`). Not covered: the party_host screen itself; the brief excludes it.
2. Kept state: `showNightEnd` keeps no state. Nothing going on: the second test calls it with no view (`hasViewers` is false) and the listing phone still gets exactly one message.
3. Combinations: the send is independent of the view, the pause menu, host away, "Get ready", links and leaving; no new state. Covered by the no-view test. Not tested against a dropped link, since the message is sent through the existing `sendToAll` path.
4. Stayed in allow:. Yes: 4 lib files, 1 new test file, this report.
5. Stopped: nothing stopped.
6. Look: no UI change in this job, so no look to check.

## Computed test values

- Awards: `NightAwardRow(id: 'fast', name: 'Fastest', points: 3, winners: ['phone-1'])`.
- Standings: `ViewStanding(id: 'phone-1', number: 1, name: 'Mia', points: 15, ...)`.
- Expectations: the listing phone gets 1 `NightEndMessage`, equal to the sent one (`==`), winner `phone-1`, award points 3, standing points 15. The phone without the capability gets 0. In the second test, `hasViewers` is false and the listing phone gets 1 message for one call.

## Files changed

- `packages/connection/lib/src/game_host.dart` — new abstract `showNightEnd`, with its doc.
- `packages/connection/lib/src/server_game_host.dart` — `showNightEnd` = `server.sendToAll(message)`.
- `packages/connection/lib/src/memory_game_host.dart` — `shownNightEnds` list and `showNightEnd` recording into it.
- `packages/party_host/lib/src/testing/host_fakes.dart` — `shownNightEnds` list and `showNightEnd` recording into it (`FakeGameHost`).
- `packages/connection/test/night_end_send_test.dart` — new; the two tests above.
- `docs/briefs/m16/bugs4/nh1-report.md` — this report.

Line counts after the change: `game_host.dart` 128, `server_game_host.dart` 360, `memory_game_host.dart` 183, `host_fakes.dart` 365. All under 380.

## Problem to check: churn revert touched tv_test_app

On the first `tools/mine.sh` run the script printed `churn: reverted 3 generated file(s)`. At the start of this session, `git status` showed these as modified: `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h`, and `generated_plugins.cmake`. After the run they no longer appear in `git status`, so the script most likely restored them to HEAD and discarded whatever changes were there. I did not touch them, and I can't restore them: git commands that change anything are not allowed for me. Please check whether those three files had changes you need; if so, they must be recovered from another source.

## Hand-over

- The brief's step 3 named `m14_test.dart`; it passes.
- The brief's `check: format analyze` is covered by `tools/mine.sh`, which passed. The full workspace analyze is left to the runner, as the brief says.
- Commit message draft and the status row are below.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

connection: GameHost.showNightEnd sends the night's end to night phones

Adds GameHost.showNightEnd(NightEndMessage), sent once when the awards
reveal ends or is skipped. The server sends it to every paired phone
that lists Capability.night (the gate already exists in capabilityFor),
with or without a view running. The memory host and FakeGameHost record
each call in shownNightEnds. Test: night_end_send_test.dart, written first.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 bugs4 nh1 done: GameHost.showNightEnd sends to night-capable phones with or without a view (tests pass); open: the client side (nk1) and the party_host card are not in this job.

## Delete — the files to delete, one `- path` line each (only files you may change), or `- none`. You can't delete files: the script deletes these after you finish.

- none

## Questions

1. The churn revert in `tools/mine.sh` seems to have restored three tv_test_app generated files that were modified before this job. Do you want them recovered, and from where?
2. The brief's `check:` line names `format analyze` for the whole job, but the runner analyzes the whole workspace only once per wave. Is `tools/mine.sh` enough for this job's gate?

## Suggestions

- The `FakeGameHost` and `MemoryGameHost` `shownNightEnds` lists give the party_host tests a way to assert the night's end without a real server. The nk1 job can use them.
