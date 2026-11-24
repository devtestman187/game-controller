# M16 bugs4 nc1 report: the `night_end` message and the `night` capability

## Summary

STATUS: stopped. The protocol contract is in place and its tests pass. The connection gate test cannot pass yet: two exhaustive `switch (message)` statements outside this job's `allow:` list stop the connection package from compiling.

What changed:

- `packages/protocol/lib/src/night.dart` (new, a `part of 'messages.dart'`): `NightAwardRow` (id, name, points, winners, optional reason, toJson/fromJson/==/hashCode) and `NightEndMessage` (wireType `night_end`, optional `awards` and `standings` on read, ==/hashCode, dartdoc says when it is sent and to whom).
- `packages/protocol/lib/src/messages.dart`: `part 'night.dart';`.
- `packages/protocol/lib/src/codec.dart`: `NightEndMessage.wireType` registered in `_decoders`.
- `packages/protocol/lib/src/capabilities.dart`: `Capability.night = 'night'`, documented.
- `packages/protocol/lib/src/view_result.dart`: `ViewStanding.id` (optional `String?`, key `id`, written only when set, read as an optional string, in ==/hashCode).
- `packages/connection/lib/src/host_server.dart`: `NightEndMessage() => Capability.night` row in `capabilityFor`. The file was at 380 lines, so one more line made it 381. To stay within the 380 limit I joined the two-line doc comment of `capabilityFor` into one line (same words, no behaviour change). The new row is the only code change in the file.
- `packages/protocol/test/night_end_test.dart` (new): 7 tests (see below).
- `packages/connection/test/night_end_gate_test.dart` (new): one test per transport, two phones (one lists `night`, one is view-only).
- `packages/protocol/test/coverage_all_test.dart`: added the `night.dart - part of another library` skip line, by hand, in the generated file's format. I did not run `tools/coverage_imports.dart`, because it regenerates every package's test file.
- `docs/protocol.md`: a `night` row in the capability table, and a section `8e. The night's end` (fields, capability, when it is sent, the older-peer rule).

Tests first: before the lib code was written, `tools/mine.sh` failed on both new test files (compile errors: `NightAwardRow`, `Capability.night`, `NightEndMessage` and `id` did not exist). That is the fail-first evidence.

## Test values (computed for the expectations)

- Round-trip test: awards `Hit` (3 points, winners `c1`), `Fast` (2 points, winners `c1` and `c2`), `Quiet` (0 points, winners none, no reason). Standings: Mia `c1` #1 12 points, Dad `c2` #2 9 points, Robo #3 7 points with `isRobo`.
- Decode of a payload without `awards` or `standings`: both lists empty.
- Standing without id: `toJson()` has no `id` key, round-trips with `id == null`.
- Gate test: `sendToAll(start)` returns 2 (both phones list `view`); `sendToAll(nightEnd)` returns 1 (only the `night` phone). The newer phone holds one `NightEndMessage`; the older phone holds none, and holds the one `ViewStartMessage` as the newer one does.

## Checks run

- `tools/mine.sh` (last run): protocol suite `OK 7 tests packages/protocol`, analyze of `packages/protocol` clean. Result overall: FAILED, 2 checks. Both failures are the same cause, below.
- `tools/mine.sh` formats files; it reformatted my new test files and `night.dart`.

## Blocked: the connection package does not compile

`dart analyze` on `packages/connection` and the connection tests report `non_exhaustive_switch_statement` for the new sealed `Message` subtype:

- `packages/connection/lib/src/client_messages.dart:38` (`switch (message)`)
- `packages/connection/lib/src/host_connection.dart:202` (`switch (message)`)

Both are outside this job's `allow:` list, so I did not edit them. Each needs a `NightEndMessage` case (or the equivalent) so the switch stays exhaustive. Until then `packages/connection` tests fail to load, including `night_end_gate_test.dart` and `coverage_all_test.dart`. A `night_end_gate_test` pass has not been seen.

## Self-check (review-rules part A)

1. Host setups: the gate test uses a TV-style host (`startHost` with the test transports); the phone side is covered by the two phones. Not exercised: "Play on this phone" and "Show on this device" hosts, which this contract does not touch.
2. Kept state: none. `night_end` is sent once per night; nothing is kept in the message.
3. Combining with pause, host away, player away, Get ready, dropped link, results and leaving: not covered by this job. The brief says the host send and the phone card come later.
4. Stayed inside `allow:` except for the blocked switches (not edited).
5. Stopped at the switches (named above).
6. Looks: none; this job adds no UI.

## Questions

1. Allow the two switches to be updated (`client_messages.dart:38`, `host_connection.dart:202`), or should the connection package handle `NightEndMessage` in a later job?
2. `night.dart` holds two public types (`NightAwardRow`, `NightEndMessage`), which goes against the one-public-type-per-file rule. The brief named a single file, so I kept both there. Split them if you prefer.
3. `coverage_all_test.dart` was already stale: `identity.dart` is missing from its skip list. I did not fix it (outside this job). The generator would add it.
4. The `host_server.dart` doc comment was joined into one line to stay at 380 lines. If you would rather keep the two-line comment, the file needs a split first.

## Suggestions

- Split `host_server.dart` (380 lines, at the limit) before the next job adds a row.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

protocol: night_end message and the night capability (M16 bugs4 nc1)

Adds NightEndMessage (wire type night_end) with NightAwardRow, sent once per
night after the awards reveal to a phone that lists the new night capability.
ViewStanding gets an optional id so a phone can find its own row. The host
maps NightEndMessage to the night capability, and docs/protocol.md section 8e
describes the message and the older-peer rule. Connection switches on Message
still need a NightEndMessage case before the package compiles.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 bugs4 nc1: night_end contract and night capability done in protocol (tests pass); open: connection's two exhaustive Message switches (client_messages.dart, host_connection.dart) need a NightEndMessage case, then the gate test runs.

## Delete

- none
