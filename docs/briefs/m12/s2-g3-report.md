# M12 step 2 — G3 report: the split (host and client), as a pure move

Job: [s2-g3.md](s2-g3.md). Maps: [s2-g1-plan.md](s2-g1-plan.md) §1b (§1b host, §1c client, §1d
shared state). Contract: [../design/m12-transport.md](../design/m12-transport.md) §3–§4 — G3 stays on
`WebSocket`; `MessageChannel` is G4.

Only `packages/connection/lib` and this report changed. No test file was touched. No message text,
log line, close code, timing or public API changed: the 119 connection tests pass unmodified, and
`HostServer` and `ControllerClient` still expose exactly the members they did at `HEAD`
(checked by grepping the old files out of `git show HEAD:` against the new ones).

## Files

New:

| File | Lines | What it holds |
| --- | --- | --- |
| `src/host_types.dart` | 117 | `ControllerState`, `ControllerInfo`, `HostSnapshot`, `ControllerMessage`, moved verbatim |
| `src/saved_pairing.dart` | 45 | `SavedPairing`, moved verbatim |
| `src/host_pairings.dart` | 215 | `KnownPairing` (was `_Known`) and `PairingBook` (the code, wrong-code counter, known pairings, tokens, player numbers) |
| `src/host_connection.dart` | 369 | `HostDetails`, the `HostSessionHost` interface and `HostConnection` (was `_Session` plus every per-connection method of `HostServer`) |
| `src/controller_identity.dart` | 42 | `ControllerIdentity`, moved verbatim |
| `src/client_types.dart` | 146 | `ClientStatus`, `ClientProblem`, `ClientSnapshot` (and the `_keep` helper), moved verbatim |
| `src/client_input.dart` | 61 | `ClientInput`: what `sendInput` remembers and the next `InputStateMessage` |
| `src/client_controls.dart` | 76 | `ClientControls`: the four game streams, haptics count, layout and status |
| `src/client_metrics.dart` | 62 | `OutboxResult` and `MetricsOutbox`: the metrics outbox and acks |
| `src/client_host.dart` | 61 | the `ClientHost` interface (what the channel and the handlers may do with the client) |
| `src/client_connection.dart` | 217 | `ClientConnection`: session and socket numbers, connecting, heartbeat, drop and close codes |
| `src/client_messages.dart` | 169 | `ClientMessages`: what arrives from the TV, decoded and applied |

Rewritten:

| File | Lines | What it holds |
| --- | --- | --- |
| `src/host_server.dart` | 374 | `HostServer` with the same public API; binding, upgrade, snapshots and the `_SessionHost` adapter |
| `src/controller_client.dart` | 398 | `ControllerClient` with the same public API; retry, tokens, snapshots and the `_ClientHost` adapter |

Edited:

- `lib/connection.dart`: `export 'src/client_types.dart'`, `'src/controller_identity.dart'`,
  `'src/host_types.dart'`, `'src/saved_pairing.dart'` — the public types that used to come out of
  the two big files and now live in their own. The internal files (`host_pairings`,
  `host_connection`, `client_*`) are not exported.
- `src/game_host.dart`: added `import 'host_types.dart';` (the three types it uses moved out of
  `host_server.dart`; Dart imports are not transitive).

Line counts before the split: `host_server.dart` 839, `controller_client.dart` 830.

## Where every member went — host

| Old member (`host_server.dart` at HEAD) | New place |
| --- | --- |
| `ControllerState`, `ControllerInfo`, `HostSnapshot`, `ControllerMessage` (+ `supports`) | `host_types.dart`, unchanged |
| `SavedPairing` (+ `toJson`, `fromJson`) | `saved_pairing.dart`, unchanged |
| `HostServer` constructor and fields `hostId`, `hostName`, `appVersion`, `preferredPort`, `heartbeatInterval`, `heartbeatTimeout`, `pairingWindow`, `maxWrongCodes`, `latencyLogInterval`, `onPairingsChanged`, `maxSavedPairings`, `capabilities` | `host_server.dart`, unchanged |
| `nowMs`, `changes`, `messages`, `snapshot`, `pairingCode`, `port` | `host_server.dart`, unchanged (`pairingCode` and `snapshot` now read `_pairings.code`) |
| `start`, `stop`, `dispose`, `dropAllConnections`, `sendToAll`, `send`, `capabilityFor`, `_accepts` | `host_server.dart`, unchanged |
| `newPairingCode` | `host_server.dart`, body now `_pairings.newCode()` |
| `pairings` getter | `host_server.dart` => `_pairings.saved`; the body moved to `PairingBook.saved` |
| `forgetDisconnected` | `host_server.dart`; the loop moved to `PairingBook.forgetDisconnected(live)` |
| `reserveLocalPlayer`, `releaseLocalPlayer` | `host_server.dart`; the numbers moved to `PairingBook.reserveLocalPlayer` / `releaseLocalPlayer` |
| `_bind`, `_onRequest`, `_onSocket` | `host_server.dart`, unchanged (still `WebSocketTransformer`) |
| `_emit`, `_pairingsChanged`, `_now`, `_noLog` | `host_server.dart`, unchanged |
| `_newCode({previous})` | `PairingBook.newCode()` + top-level `_codeFrom(random, {previous})` |
| `_newToken()` | `PairingBook.newToken()` |
| `_pickPlayer(int?)` | `PairingBook.pickPlayer(previous, {required taken})` |
| `_trimPairings()` | `PairingBook._trim(live)`, called from `remember` |
| `_code`, `_wrongCodes`, `_known`, `_random` fields | `PairingBook` (`_code`, `_wrongCodes`, `_known`, `_random`) |
| `_tick()` | split: `HostServer._tick` keeps the interval and the latency log; the per-connection part is `HostConnection.tick(now, {heartbeatTimeout, pairingWindow})` |
| `_latencyLine(_Session, now)` | `HostConnection.latencyLine(now)` |
| `_send(_Session, Message)` | `HostConnection.send(Message)` |
| `_close(_Session, code, reason)` | `HostConnection.close(code, reason)` |
| `_onClosed(_Session)` | `HostConnection.onClosed()` |
| `_onData(_Session, Object?)` | `HostConnection.onData` (frame check) + `_decode` + `_handle` (the switch) |
| `_onPong`, `_onHello`, `_onPair`, `_onInput`, `_onMetrics`, `_accept`, `_forward`, `_ended` | `HostConnection`, same names, same bodies minus the `_Session` parameter |
| `_who(_Session)` | `HostConnection.who` getter |
| the two `ControllerInfo(...)` builds inside `_controllers` | `HostConnection.toInfo(now)` and `KnownPairing.toInfo()`; `_controllers` in `host_server.dart` now just collects and sorts |
| inline live-id set in `forgetDisconnected`/`_ended`, inline taken-numbers set in `_pickPlayer` | `HostServer._liveIds` and `HostServer._takenPlayerNumbers` |
| `_duration(Duration)` | `host_connection.dart`, unchanged |
| `class _Session` (fields `socket`, `remoteAddress`, `openedAtMs`, `lastHeardMs`, `hello`, `paired`, `closed`, `rttMs`, `rttWindow`, `input`, `inputAtMs`, `nextPingId`, `since`, `player`, `latency`) | `HostConnection`, same fields; `socket` is now private (`_socket`) |
| `class _Known` (fields `hello`, `token`, `remoteAddress`, `lastSeen`, `player`) | `KnownPairing`, same fields, now package-public |

New in `host_server.dart` for the split: `_liveIds`, `_takenPlayerNumbers`, `_reservePlayerNumber`,
`_forward(ControllerMessage)` (the old `_forward` built the `ControllerMessage` itself; that part
moved to `HostConnection._forward`) and the `_SessionHost` adapter.

## Where every member went — client

| Old member (`controller_client.dart` at HEAD) | New place |
| --- | --- |
| `ControllerIdentity` (+ `copyWith`, `toHello`) | `controller_identity.dart`, unchanged |
| `ClientStatus`, `ClientProblem`, `ClientSnapshot` (+ `isConnected`, `hostLabel`, `copyWith`, `toString`, `_keep`) | `client_types.dart`, unchanged |
| `snapshot`, `changes` | `controller_client.dart` => `_snap`, `_changes`, unchanged |
| `tokens`, `inputsSent`, `hapticEvents`, `hapticsReceived`, `layout`, `layouts`, `status`, `statuses`, `ratingAsks`, `metricsWaiting`, `hostTakesMetrics` | `controller_client.dart`, same names, now reading `_tokens`, `_input`, `_controls`, `_metrics` |
| `_haptics`, `_ratingAsks`, `_layouts`, `_statuses` controllers | `ClientControls` (`hapticEvents`, `ratingAsks`, `layouts`, `statuses`) |
| `_layout`, `_status`, `_hapticsReceived`, `_setLayout`, `_setStatus`, `_resetGameControls` | `ClientControls` (`layout`, `status`, `hapticsReceived`, `setLayout`, `setStatus`, `reset`) |
| `_outbox`, `_acked`, `maxOutbox`, `_onMetricsAck`, the queueing half of `sendMetrics` | `MetricsOutbox` (`waiting`, `unacknowledged`, `add`, `acknowledge`, `maxOutbox`); `ControllerClient.maxOutbox` stays as `MetricsOutbox.maxOutbox` |
| `_inputSeq`, `_buttons`, `_dx`, `_dy`, `_ax`, `_ay`, `_left`, `_right`, `_inputsSent`, `_sendInputState` | `ClientInput` (`statesSent`, `remember`, `nextState`); `sendInput` keeps its signature and calls `remember` + `nextState` |
| `_session`, `_socketId`, `_ws`, `_welcomed`, `_opening`, `_heartbeat`, `_lastHeardMs`, `_lastHeardAt`, `_nextPingId`, `_codec` | `ClientConnection` |
| `_open` | split: the address loop stays in `ClientConnection.open(session, messages)`; taking over the fresh socket is `ClientConnection._attach`; the `ClientMessages` object is made by `ControllerClient._open` |
| `_onConnectFailed`, `_onSocketDone`, `_beat`, `_dropSocket` | `ClientConnection` (`_onConnectFailed`, `_onSocketDone`, `_beat`, `dropChannel`) |
| the `replaceQuietChannel` part of `resume` | `ClientConnection.replaceQuietChannel(now)` |
| `_onData`, `_onWelcome`, `_onPairResult`, `_onPong`, `_resendMetrics` | `ClientMessages`, same bodies (`onData`, `_onWelcome`, `_onPairResult`, `_onPong`, `_resendMetrics`), plus `_decode` |
| `_rttWindow` | `ControllerClient._rtt`, handed to `ClientMessages` (the summary only makes sense next to the rest of the snapshot) |
| `identity`, `onTokenChanged`, `heartbeatInterval`, `heartbeatTimeout`, `connectTimeout`, `retryDelays`, `_wallClock`, `_tokens`, `_log`, `_clock`, `_changes`, `_snap`, `_everPaired`, `_pendingCode`, `_retry`, `_now`, `connect`, `submitCode`, `updateAddress`, `retryNow`, `resume`, `disconnect`, `dispose`, `sendMetrics`, `sendRating`, `sendInput`, `_saveToken`, `_scheduleRetry`, `_giveUp`, `_teardown`, `_send`, `_set`, `_noLog`, `_sameList` | `controller_client.dart`, unchanged |

## Members changed to make the split work (and why)

The brief asks to name every member I had to change. These are all of them:

1. **`_Session` => `HostConnection`, `_Known` => `KnownPairing`.** The package's file-private rule
   means the moved types can't be `_`-private any more, so they get real names. Both are still not
   exported from `connection.dart`.
2. **`_Session.socket` => private `HostConnection._socket`.** Only `send` and `close` touch it, so
   making it private keeps it out of a class that is visible inside the package.
3. **`HostConnection.toInfo(now)` and `KnownPairing.toInfo()`.** New methods that hold the two
   `ControllerInfo(...)` constructions which used to sit inline in `HostServer._controllers`. Same
   arguments, same order; needed to keep `host_server.dart` under 400 lines.
4. **`HostConnection.tick(now, {heartbeatTimeout, pairingWindow})` and `latencyLine(now)`.** The
   old `HostServer._tick` and `_latencyLine(_Session, now)`, with the session as `this` and the two
   durations passed in because the book no longer owns them.
5. **`HostServer._forward(ControllerMessage)` instead of `_forward(_Session, Message, now,
   {delayMs})`.** Building the `ControllerMessage` moved into `HostConnection._forward`; the server
   now only adds it to the stream. Same messages, same `receivedAtMs` and `delayMs`.
6. **`HostServer._tick` no longer drops connections itself.** It calls `tick` on each connection
   (it still owns the `Timer` and the latency log interval, so the log cadence is unchanged).
7. **`PairingBook` takes `Random` in its constructor and computes the code in its initializer
   list** (top-level `_codeFrom(random)`), because the plan forbids `late` and the code must differ
   from nothing (`previous: null`) at construction. `newCode`/`countWrongCode` pass
   `previous: _code`.
8. **`PairingBook.add`-style results: `MetricsOutbox.add` returns `OutboxResult`.** `ignored`,
   `kept` or `droppedOldest`, so the client keeps its `'Metrics: dropped the oldest unsent
   segment (more than $maxOutbox waiting)'` log line and its early return. The outbox adds one
   batch at a time, so `droppedOldest` happens at most once, as in the old `while` loop.
9. **`ClientHost` is the plan's list with three deliberate differences.** `tokens` +
   `tokenChanged` became `tokenFor(hostId)` / `saveToken(hostId, token)`: the map and the app's
   callback stay owned by `ControllerClient`, and the handlers only need "read one" and "write
   one". Two members are added: `welcomed` (the channel resets it on every connect, the welcome
   sets it) and `hostTakesMetrics` (the handlers ask the client's rule instead of repeating it).
   `dropChannel` is as planned.
10. **`ClientConnection.open(int session, ClientMessages messages)` + `_attach`.** The messages
    object is per channel (it holds that channel's `ClientMessages`), and `_attach` is the second
    half of the old `_open`, extracted so neither function is over 40 lines.
11. **`ClientMessages` takes `{rtt, controls, input, metrics}`** in addition to the host, because
    those four own state the handlers update.
12. **`ClientInput.remember(buttons, …)` and `nextState(sentAtMs)`** instead of the fields and
    `_sendInputState`; `statesSent` is the old `_inputsSent`.
13. **`ClientControls.reset()`** is the old `_resetGameControls`; `close()` is what `dispose` used
    to do with the four controllers.
14. **`_SessionHost` and `_ClientHost` adapters instead of `implements` on the public classes**
    (a deviation from plan §1d, which shows `HostServer implements HostSessionHost` and
    `ControllerClient implements ClientHost`). Implementing them on the public classes would add
    ~12 public members to each — including `PairingBook pairings`, which clashes with today's
    public `List<SavedPairing> get pairings` — and the brief forbids new public API. Both adapters
    live in the owner's own file, so they can reach its private members and delegate; nothing in
    the public surface changed.
15. **Lazy getters instead of `late`**: `ClientHost get _host => _clientHost ??= _ClientHost(this)`
    and `ClientConnection get _connection => _channel ??= ClientConnection(…)`. `_lastHeardAt` is
    initialised in `ClientConnection`'s initializer list (`: _lastHeardAt = wallClock()`), and
    `PairingBook`'s code in its initializer list, so no `late` is needed anywhere.
16. **`ClientConnection.send` is used for the hello** (the old `_send`), so the "no channel yet"
    guard and the log text `'Send failed: …'` stay exactly as they were.

## Checks

- `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets`:
  **PASS** — 198 files, 0 changed.
- `dart analyze` (whole workspace): **1 info**, `packages/metrics/lib/src/segment.dart:319`
  (`use_null_aware_elements`), a file this job didn't touch and which was already there.
  `dart analyze packages/connection`: **No issues found!**
- `dart test` in `packages/connection`: **PASS, 119 tests** (same 119 as before the split:
  89 original, 25 transport, 5 host-address). No test file was edited.
- `flutter test` in `packages/party_host`: **PASS, 44 tests**.
- `flutter test` in `controller_app`: **PASS, 262 tests**.
- `tools/review.sh`: **1 FAIL, 6 NOTE** (was 1 FAIL, 8 NOTE before the last two trims):
  - FAIL size `game_host.dart` 538 lines — **pre-existing**: 537 lines at `HEAD`
    (`git show HEAD:…/game_host.dart | wc -l`), and my only change there is one `import` line.
    It is flagged because the import makes the file part of this diff. It is not a new file and
    not part of the split; making it a FAIL-free diff means splitting `game_host.dart`, which is
    outside this gate.
  - NOTE size `controller_client.dart` 398, `host_server.dart` 374, `host_connection.dart` 369 —
    all under the hard 400, over the 300 aim.
  - NOTE number `client_connection.dart:140` (`closeCode ?? 1000`), `host_pairings.dart:132` (the
    `16` in `newToken`) and `:212` (the `10000` in `_codeFrom`). All three moved verbatim from
    the old files; no new bare number was written in this job. Naming them (`_codeRange`,
    `_tokenBytes`, `CloseCodes.normal`) is a small, separate job.
- `tools/check.sh format analyze connection host phone` is the check the brief names; this
  sandbox would not let me invoke it (`tools/check.sh` needs approval that I can't give), so I ran
  the five checks it is made of, above, one by one.

## Questions and things I wasn't sure about

1. **Adapters instead of `implements`** (point 14 above) is the one place I left plan §1d:
   implementing `HostSessionHost`/`ClientHost` on the public classes would add public members and
   collide with `HostServer.pairings`. I chose no public API change. Confirm, or say that the
   interfaces should be reshaped (e.g. `PairingBook get pairings` renamed) to make `implements` work.
2. **`HostSessionHost` has 11 members, the plan lists ten**: `pairedControllerIds` is the extra.
   `HostConnection._accept` needs the live controller ids to call `PairingBook.remember(…, live:)`,
   and the book, not the server, does the trimming. If the ten are a hard list, the alternative is
   to trim from the server after the accept, which reads worse.
3. **`ClientHost`'s three differences** (point 9): `tokenFor`/`saveToken` instead of
   `tokens`/`tokenChanged`, plus `welcomed` and `hostTakesMetrics`. Same reason: keep the public
   API and the state where they are. Flag it if you want the plan's exact shape.
4. **`hostTakesMetrics` could be derived from `snapshot`** in the handlers (removing one interface
   member), but the rule "connected and the host listed metrics" belongs to the client. I kept it.
5. **`controller_client.dart` is 398 lines** — the client's public API plus the adapter leaves no
   slack. Getting to the 300 aim means moving real behaviour (the retry state machine, or the
   token/`ClientSnapshot` bookkeeping), which is not a pure move. I'd rather not do that at G4,
   where the channel work will add lines anyway; say if you want it done.
6. **`game_host.dart` is 538 lines** and was 537 before this job; it is the one FAIL in
   `tools/review.sh` and it is pre-existing. It needs its own split (it is not in the plan).
7. **Function sizes**: `ClientConnection.open` and `ClientMessages._onPairResult` grew past 40
   lines during the move (the `_host.…` prefixes), so I extracted `_attach` and captured the
   snapshot once. `review.sh` no longer flags either. Every other function is the same length as
   before or shorter.
8. **`_codec` now exists twice on the client side** (`ClientConnection` and `ClientMessages`), one
   `MessageCodec()` each. It is const and stateless, so this is only a name, not behaviour; sharing
   one instance would need a fifth thing passed into `ClientMessages`.
9. **The working tree already had `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}`
   and `generated_plugins.cmake` modified before this job started** (they are generated). I didn't
   touch them. `flutter test` in `party_host`/`controller_app` runs `pub get`, which did not
   change any tracked file.
