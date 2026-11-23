# M16 w4d: the `players` list holds local and away players

## Summary

- Done: a `players` message now lists every player the round knows: paired phones, away players whose slot is held, and local players (TV keyboard, host phone's own player), in number order.
- `HostServer.playerSource` (new public field, host_server.dart) is set by `ServerGameHost` and cleared in `dispose`. `playerRows` uses it when set, else the paired sessions (now the private `_sessionRows`).
- `ServerGameHost._playerRows` maps `players` to rows: id, number, name `nickname ?? ''`, character `character ?? PlayerCharacter.forPlayer(number)`.
- `_checkPlayers` calls `server.broadcastPlayers()` after `_lastPlayers = now`, only when the roster changed.
- docs/protocol.md 8d: the list is every player the round knows, paired, away while the slot is held, and local.
- New test file identity_rows_test.dart: 3 tests (local player ×2 transports, away player on the socket).
- Frames' `pl` and `chars` are unchanged; no reservation work.
- Checks: `tools/check.sh format analyze connection host` all PASS (format, analyze, connection 349 tests, host).
- No existing test needed changing: none failed. identity_host_test.dart and identity_reservation_test.dart run with no game host or with no local/away player, so their lists are the same as before.

## Decisions

- Q4/Q5 as the owner decided on Nov 23; no other design choice was needed.
- The away test ends the slot with `goOnWithout`, not the grace timer: no real time, and the grace is set to one minute so the clock never fires.
- The away test runs on the socket only. The in-process link keeps no slot (m12 code health N5, as player_away_messages_test says), so an away row can't appear there. Its first run showed "Host stuck at []" on inProcess, which confirmed this.
- A duplicate identical `players` list can now go out at a pairing (the session's `playersChanged` and `_checkPlayers` both send). The brief calls this harmless; I left it.
- `playerSource` is set in the constructor, not in the `players` getter, so a host with no game keeps today's rows.

## Test values (computed or observed)

- Old code, before the lib edits: `identity_rows_test` failed 4 of 4 runs: local ×2 with "Bad state: No element" (the local row was missing); away on the socket with "Bad state: No element"; away in-process with "Host stuck at []" (the test was then gated to the socket).
- Phone 1 pairs first, so it is number 1; phone 2 (the dropped one) is number 2. The test asserts `number == 2` and `character == PlayerCharacter.forPlayer(2)`.
- The local player's number comes from `reserveLocalPlayer`; the test asserts `character == PlayerCharacter.forPlayer(keyboard.number)` and does not hard-code the number.
- After `goOnWithout('phone-2')` the last list is `['phone-1']`.
- `check.sh`: format PASS, analyze PASS, connection PASS (349 tests, 17 s), host PASS (242 s).
- `mine.sh` printed "OK 4 tests packages/connection" for the touched test file. I count 3 tests in identity_rows_test.dart, so this is not reconciled (see Questions).

## Self-check (review-rules part A)

1. Host setups: TV/PC host, the local-player test on both transports (`identity_rows_test`); joined phone, away test on the socket; phone one build older, unchanged and passing (`identity_host_test`, "the phone one build older has heard none of it"). "Play on this phone" and "Show on this device" are not covered by a new test.
2. Kept state: the away row starts when the drop is noted and ends with `goOnWithout` (away test). With nothing going on the list is the paired sessions (existing tests, no game host).
3. Combinations with pause menu, host away, "Get ready", results and leaving: not tested here. The job changed no frame, pause or round code.
4. Stayed inside allow:, with one side effect (see Hand-over).
5. Stopped rather than overstepped: see Questions 1 and 2.
6. Looks: no UI changed; not applicable.

## Questions

1. An away player's character is not kept: `AwaySlots` builds its `GamePlayer` without a character (away_slots.dart:139), so `players` (and the `players` row) show the default `PlayerCharacter.forPlayer(number)` for an away player who wore another. Should the slot keep the character? That is in away_slots.dart, outside allow:, so I did not change it.
2. Should the session-side `playersChanged` call (host_connection.dart:289 and the join path) skip when a game host runs, so a pairing sends one `players` list, not two?
3. `mine.sh` said "OK 4 tests" for my touched file, but the file has 3 tests. Is the count from the runner, or does it count something else?

## Hand-over

- Files changed:
  - `packages/connection/lib/src/host_server.dart`: new public field `playerSource` (5 lines with its doc). File is now 376 lines (limit 380).
  - `packages/connection/lib/src/host_players_broadcast.dart`: `playerRows` uses `playerSource`, else `_sessionRows` (the old rows, moved).
  - `packages/connection/lib/src/server_game_host.dart`: sets `server.playerSource` in the constructor, clears it in `dispose`, adds `_playerRows`, and broadcasts in `_checkPlayers` on a change. File is now 357 lines.
  - `docs/protocol.md`: the 8d `players` paragraph (line 220) now says every player the round knows.
  - `packages/connection/test/identity_rows_test.dart`: new file, 3 tests, all failed on the old code before the lib edits.
  - `docs/briefs/m16/identity1-w4/w4d-report.md`: this report.
- Side effect, not caused by a file I chose to edit: `tools/mine.sh` printed "churn: reverted 3 generated file(s)". Before the job, git status showed `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h` and `generated_plugins.cmake` as modified. Those three are no longer listed in `git status`, so the script reverted them to HEAD. I did not touch them and did not restore them (git checkout is not allowed here). Whoever owns those files should check this.
- The `docs/briefs/m16/identity1-w4/DRIVER-NOTES.md` and `run.log` changes from before the job are still there.

## Commit message

Subject: M16 w4d: the players list holds local and away players

The `players` message listed only paired phones. A local player (the TV
keyboard, the host phone's own player) and an away player, whose slot the
round holds, were missing, so a phone's list could not match the frame's `pl`.
ServerGameHost now sets HostServer.playerSource to its players, each with its
default character when it has none, and broadcasts the list when the roster
changes. Frames and reservations are unchanged.
protocol.md 8d says the list holds every player the round knows.
New identity_rows_test.dart covers a local player, an away player and the
away slot's end.

## Status row

M16 w4d (players list): done: the list holds paired, away and local players, with the default character for local and away players, plus tests and protocol.md 8d. Open: an away player's character is not kept (AwaySlots), a pairing sends two identical lists, and the mine.sh test count is unexplained.

## Delete

- none
