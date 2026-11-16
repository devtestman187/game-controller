# sentry1 stats option B: a phone that said no is left out of the upload

## Summary

Stats option B is in on the protocol, the phone and the host. A controller that said no to stats (or never said anything) is left out of the uploaded session; the file on disk and the Stats screen keep everything, with each player marked `share`.

- **Protocol**: new `stats_share` message (`StatsShareMessage(share)`) in a new part `stats_share.dart`, registered in `codec.dart`, described in `docs/protocol.md` §8c with a row in §11. No capability: an older host drops it as an unknown type, an older phone sends nothing.
- **Phone** (`connection`): `ControllerClient.setStatsShare(bool)` keeps the answer, sends nothing before the first call, sends at once while paired, and sends again inside every accepted pairing (a reconnect pairs again, so it is covered). `ClientHost.statsShare` is the getter the pairing path reads.
- **Host**: `host_connection.dart` forwards `stats_share` from paired controllers; `SessionRecorder.onMessage` records it with `SessionCollector.statsShare(id, share)`; `PlayerRecord.shares` defaults to false, a local player of the host always shares, and `playerJson` writes `'share'`.
- **Upload** (`metrics`): new pure `uploadableSummary(summary)`; `LiveStats.uploadNow` uploads its result instead of the saved summary. Players with `share != true` go with all their data; a round keeps `game`, `timeS`, `startS`, `players` (how many took part), `framesDrawn`/`framesLate`, tags and battery, and loses `winner`/`winners` entries for players who don't share.
- **Splits** (the files were over the 380-line rule and `docs/code-health.md` said "the next message means a split first"): `controller_client.dart` 399 → 350 plus `controller_client_host.dart` 64; `host_connection.dart` 392 → 364 plus `host_connection_info.dart` 44 (`toInfo`, `latencyLine` as library-private functions); `client_messages.dart` `onData` 60 lines → 35 plus `_onControlMessage` and `_onViewEvent` (226-line file). Both parts are `part of` their file, like `party_host/lib/src/ui`.
- `live_stats.dart` stays at exactly 380 lines: the change is one line (`up.upload(uploadableSummary(f.summary))`).
- `docs/code-health.md`: the connection split item moved to Done.

Tests run in this job: `tools/check.sh protocol` 120, `connection` 303, `metrics` 166, `host` 515, all PASS; `tools/check.sh format analyze` PASS; `tools/review.sh` 0 FAIL, 7 NOTE (sizes and two 40+ line functions, all but one pre-existing). 15 new tests: protocol 2, connection 8 (4 cases on each transport), metrics 4, host 1.

Nothing here needs a device check: no UI, no timing change. **Fixed, unverified: needs device check** — none.

## Decisions

- **The message is not capability-gated.** The design doc says so and the brief says "no capability needed"; §4 of the protocol only gates messages that *need* the other side to understand them, and a host that doesn't is exactly the "not sharing" case.
- **The answer lives on `ControllerClient`, not in `ClientSnapshot`.** It is the app's answer, not the link's: it must survive a reconnect and a new `connect()`, and a snapshot reset would drop it.
- **A re-pairing sends it again.** `_onPairResult` sends it after the input refresh, so a reconnect (which pairs again with the saved token) resends it with no extra code.
- **`stats_share` is only forwarded when paired.** Like `rating`: an unpaired connection has no player to record it for.
- **The recorder does not queue an answer that arrives before the session exists.** The session starts when the controller connects (a player joined), before the phone can get its `pair_result`, so the message always finds a session.
- **A round's `winners` may end up with one entry.** A team round whose other winner said no keeps the sharing member; the report reads `winners` as "a team", so the upload calls a 2-player win one winner. The alternative (dropping the whole win) would lose a sharing player's win.
- **Local players share.** Per the brief: the TV's keyboard player follows the host's own answer, and only the host's yes lets anything be uploaded.
- **The in-process player (Play on this phone) is not treated as local.** It is a controller over the in-process link and normally reports its own answer, which is the same instance's consent; nothing calls `setStatsShare` yet (see question 1), so today it counts as not sharing.

## Self-check (docs/review-rules.md part A, items 1-5)

1. **Every host setup.** Same code on every host: the answer is recorded by `SessionRecorder` from `server.messages`, whatever the host kind, and the phone's send path is transport-agnostic — `connection/test/stats_share_test.dart` runs every case on the webSocket and the inProcess transport (the in-process link is the phone host's own player). "Show on this device" and a joined phone use the same `ControllerClient`. An older host ignores the type (codec: unknown type → null, existing `codec_test` behaviour); an older phone sends nothing and counts as not sharing — `stats_share_test.dart` "a phone that gives no answer sends no stats_share".
2. **Kept state.** `ControllerClient._statsShare` starts null (nothing sent) and changes only through `setStatsShare`; it is kept across disconnects on purpose and is resent on every pairing — "the answer goes out again after a reconnect". `PlayerRecord.shares` starts false when the player joins and dies with the session; no timer, nothing runs when nobody is connected. `uploadableSummary` is pure. The one gap is a host pause/resume, which starts a new session and gets no new answer (question 1).
3. **How a new state combines.** It is a recorded flag, not a pause/hide/wait state, so it combines with none of them; it is read once, in `uploadNow`. The Stats screen and the saved file are unchanged, so the pause menu, the results and leaving behave as before (host suite: 515 PASS, including `live_stats_test.dart`'s saved-summary assertions).
4. **Stayed in the folder.** Only files from `allow:` changed (see the list below). `git status` also shows modified PNGs under `docs/design` and `site/shots` — they were already modified before this job and are not mine.
5. **Stopped rather than overstepped.** Nothing needed outside `allow:`. The two 380-line-rule splits were needed because both files were already over 380 and had to be touched; both are inside `allow`. No question blocked the job.

## Tests and the values they compute

- `packages/protocol/test/stats_share_test.dart` — the frame is exactly `{"v":1,"t":"stats_share","share":false}`; both answers round-trip; a missing or non-boolean `share` throws `ProtocolFormatException`.
- `packages/connection/test/stats_share_test.dart` (each case on both transports):
  - no `setStatsShare` call → no `stats_share` reaches the host. The ordering proof is an input sent after the pairing handler ran: frames keep their order, so the answer would have arrived first.
  - `setStatsShare(true)` before `connect` → exactly one answer, `share: true`, `controllerId 'phone-1'`.
  - a reconnect (the host drops every connection) → two answers, `[true, true]`.
  - `setStatsShare(false)` while connected → answers `[true, false]`, the first from the pairing, the second from the change.
- `packages/metrics/test/uploadable_test.dart`:
  - two players, one `statsShare(true)`, one never heard from, one round `timeS 10`, both players in `dpad`/`sticks`, winner = the silent player (number 2): saved `players` shares `[true, false]`; uploaded players `['yes']` with `share: true`; uploaded round `{'game': 'arena', 'timeS': 10.0, 'startS': 0.0, 'players': 2}` (winner 2 dropped, saved round keeps `winner: 2`); `durationS` 20 from `summary(20000)`; `frames` `{'drawn': 0, 'dropped': 0}`.
  - a team win `{'yes', 'no'}` among three players, only `yes` and `also` sharing: saved `winners` `[1, 2]`, uploaded `winner` 1 and `winners` `[1]`, `players` 3.
  - a local player (`local: true`) has `share: true`.
  - a hand-made summary with no `share` key: no players uploaded, round `{'game': 'arena', 'players': 4, 'timeS': 2.0}` (winner 1 dropped), `frames` kept, the input map not changed.
- `packages/party_host/test/live_stats_share_test.dart`: two phones, one `setStatsShare(true)`, one silent; one arena round, 10 s, winner = the silent phone. The saved summary shows `share: [true, false]` for `['phone-yes', 'phone-no']` and a winner; the upload has players `['phone-yes']` and a round with `game 'arena'`, `timeS 10.0`, `players 2` and no `winner`.

## Hand-over

- `controller_app` still has to call `ControllerClient.setStatsShare` from `shareStatsProvider`/`consentProvider` (question 1): until it does, a phone sends nothing and every player counts as not sharing, which is the safe direction but makes the feature inert on real phones.
- The upload-side filter is the only place consent is applied; a future uploader or a new upload path must call `uploadableSummary` too.
- `live_stats.dart` is at exactly 380 lines: the next change there needs the split that `docs/code-health.md` already asks for.
- `playerJson` is 44 lines (a NOTE, was 42) and `SessionCollector.roundEnded` 43 (untouched, already a NOTE).

## Questions

1. **Should the host remember each phone's answer across sessions?** A host pause (`LiveStats.pause`, B-019) ends the session; on resume a new session starts for players still paired, and the phone does not pair again, so it never resends and the player counts as not sharing in that session's upload. The smallest fix is a `SessionRecorder` map controller ID → answer, applied when the player joins (needs one line in `LiveStats._checkPlayers`, which is at its line limit). Not done: the brief's step 3 says the recorder records into the collector, and this is a design change.
2. **Is the in-process player (Play on this phone) to be treated as local (always sharing), or does it send its own answer?** The brief names only the TV's keyboard player. Today it sends its own answer once `controller_app` wires `setStatsShare`, which is the same instance's consent, so the two agree — unless the phone host's own player is meant to always share.
3. **Should a team round whose other winner said no still be listed as a team?** `uploadableSummary` leaves `winners: [1]` with one member (decision above); dropping `winners` and keeping `winner` would read the same in the report.

## Commit message

sentry1 stats-optb: upload only the players who share their stats

- protocol: new `stats_share` (controller → host), documented in §8c, no capability
- connection: `ControllerClient.setStatsShare` sends the answer on every pairing and on a change, nothing before the first call; the host forwards it from paired controllers
- metrics: `uploadableSummary` drops non-sharing players with their data and keeps the anonymous round totals including the player count
- party_host: `SessionRecorder` records the answer per player; `LiveStats.uploadNow` uploads the filtered copy, the file keeps everything marked `share`
- split `controller_client.dart`, `host_connection.dart` and `client_messages.dart`'s `onData` (the 380-line rule and code-health's "split first")

## Status row

sentry1 stats option B: done on protocol, phone client and host (recorded per player, upload filters, file unchanged); open: `controller_app` wiring of the consent answer, and the host pause/resume answer gap (question 1).

## Delete

- none
