# M12 step 2 — G4 report: server and client on MessageChannel, callers, tests on both transports

Job: [s2-g4.md](s2-g4.md). Contract: [../design/m12-transport.md](../design/m12-transport.md) §2–§4. Plan:
[s2-g1-plan.md](s2-g1-plan.md) §2 (call sites), §3 (test map), §4 (risks R1–R7). Where the code was:
[s2-g3-report.md](s2-g3-report.md). Step 2 ends here; nothing of step 3 (the host-phone player) was started.

Status: done. `tools/check.sh format analyze protocol connection metrics arena puzzle host phone tv` all
PASS (connection 176 tests, phone 262, tv 22, host 44). `tools/review.sh` has no FAIL on a line this job
added; it has four FAILs that were already there in two app files I had to touch (see Q5).

## Files

### `packages/connection/lib/src/`

| File | Lines | Change |
| --- | --- | --- |
| `host_types.dart` | 126 | `ControllerInfo.remoteAddress` is now `String?` (null for a local player), plus `bool isLocal` and their docs (D1). |
| `host_pairings.dart` | 224 | `KnownPairing.remoteAddress` is `String?`; `toInfo()` sets `isLocal: remoteAddress == null` (a network channel always has one) and `remember()` keeps the last network address when a local session reports none; `saved` writes `remoteAddress: k.remoteAddress ?? ''`. |
| `host_connection.dart` | 377 | The session holds a `MessageChannel` instead of a `WebSocket`: no binary check (the adapter closes it now, R5), `remoteAddress`/`isLocal` from the channel, `who` falls back to the new `localPeerLabel` (`'the local player'`) when there is no address, close code from `channel.closeCode`. |
| `host_server.dart` | 367 | `HostServer({required List<ChannelListener> listeners, …})`; `preferredPort` gone; `start()` starts each listener in turn, stopping the ones that started if one throws `ListenFailed` and rethrowing; `stop()` closes the sessions first (`1001 Host is closing`) and then the listeners (R7); the port line is written only for a listener with a port. The bind, the HTTP status page and the upgrade moved to `WebSocketListener` in G2, so `_bind`/`_onRequest`/`_onSocket` are gone; `_onChannel` makes a `HostConnection` and listens on `channel.incoming`. |
| `controller_client.dart` | 400 | `ControllerClient({required Connector connector, …})` as the private named parameter `required this._connector`; `connectTimeout` and its field are gone. 402 → 400 lines by shortening the `resume()` doc, so the file ends inside the brief's 400. |
| `client_connection.dart` | 214 | Holds a `MessageChannel?`; `open(session, messages)` asks `connector.open(target, isCancelled: () => session != _session)` and closes a channel that opened after the session changed; `ConnectFailed` carries `detail` and `osErrorCode`, so the `SocketException` pattern match is gone; `_onSocketDone` is `_onChannelDone` and reads the channel's close code. |
| `client_messages.dart` | 169 | `onData(String data)` no longer checks `is! String`: the channel never hands a binary frame up, it closes with `4003 Expected text frames` (R5). |

### Callers (no behaviour change)

| File | Change |
| --- | --- |
| `packages/party_host/lib/src/host_service.dart` | `listeners: [WebSocketListener(hostName: _hostName, log: log.sink('host'))]`; the listener keeps `defaultPort`. |
| `packages/party_host/lib/src/simulated_controllers.dart` | `connector: WebSocketConnector(log: logBuffer.sink('sim$n'))`. |
| `packages/party_host/test/live_stats_test.dart` | `listeners: [WebSocketListener(preferredPort: 0, hostName: 'Test TV')]` and `connector: WebSocketConnector()`. |
| `controller_app/lib/src/providers.dart` | `connector: WebSocketConnector(log: log.sink('client'))`. |
| `controller_app/test/widget_test.dart` | `FakeClient` passes `connector: WebSocketConnector()` to `super` (the analyzer's find; it never connects). |
| `packages/connection/bin/sim_controller.dart` | `connector: WebSocketConnector(log: (m) => stdout.writeln('  · $m'))`. |
| `packages/connection/tool/ask_rating.dart` | `listeners: [WebSocketListener(preferredPort: 0, hostName: 'Rating check')]`. |
| `tv_test_app/lib/src/ui/home/controllers_panel.dart` | `[info.platform, info.appVersion, ?info.remoteAddress].join(' · ')`: the address part disappears when there is none. |
| `tv_test_app/test/home_screen_test.dart` | New case: a controller with `remoteAddress: null, isLocal: true` shows `android · 0.6.0` and no ` · 192.168.` part. |

### Tests (`packages/connection/test/`)

| File | Change |
| --- | --- |
| `helpers.dart` | Every helper takes a `TestTransport` (no default) except `rawPeer`, whose channel is the point; `connectorFor` is public so a test can build a client by hand; `startHost` dropped its unused `log` parameter to stay at 5; `rawPeer` wraps a `WebSocket` or hands out an `InProcessLink` end and closes it with the test. One `InProcessListener` per test file, so a restarted host registers on it again. |
| `fake_host.dart` (new, 60) | `FakeHost implements Connector`: a scripted host on either transport, whose `onChannel` gets the host's end of every channel the phone opens and whose `address` is the phone's target. This replaces the four hand-written `HttpServer` fakes. |
| `haptic_test.dart` | 4 tests on both transports (the raw `WebSocket` one now uses `rawPeer`, the fake TV uses `FakeHost`). |
| `input_test.dart` | 8 on both, 4 once (ping window, the three demo tests: no channel). |
| `m6_test.dart` | 9 on both, 4 once (saved-pairing JSON, three `InputLatency` tests), 1 web-socket only (the restart that follows the port). Direct `HostServer(...)` constructions pass `listeners: [listenerFor(t)]`. |
| `m9_test.dart` | 8 on both, 6 once (two outbox tests, four gamepad-mapping tests). |
| `m10_test.dart` | 5 on both, 1 once (the local player, no channel). |
| `pairing_test.dart` | 12 on both (one is new), 1 web-socket only (the plain status page). `rawPeer` drives the version and before-hello rejections. |
| `reconnect_test.dart` | 8 on both (one is new), 2 web-socket only (same-port retry; address ordering). |
| `transport_test.dart` | Uses the helpers' `TestTransport` instead of its private `_Transport`; new connector test (26 runs). |

### Docs

- `docs/architecture.md`: new "Transport (M12 step 2)" section — the three interfaces, the two transports, why
  in-process (D1), and that in-process channels are marked local. Links `design/m12-transport.md`.

## Test runs per file, before → after

| File | Before | After | Both | Once | Web-socket only |
| --- | --- | --- | --- | --- | --- |
| `haptic_test.dart` | 4 | 8 | 4 | – | – |
| `input_test.dart` | 12 | 20 | 8 | 4 | – |
| `m6_test.dart` | 14 | 23 | 9 | 4 | 1 |
| `m9_test.dart` | 14 | 22 | 8 | 6 | – |
| `m10_test.dart` | 6 | 11 | 5 | 1 | – |
| `pairing_test.dart` | 12 | 25 | 12 | – | 1 |
| `reconnect_test.dart` | 9 | 18 | 8 | – | 2 |
| `host_address_test.dart` | 23 | 23 | – | 23 | – |
| `transport_test.dart` | 25 | 26 | 16 | 9 | 1 |
| **Total** | **119** | **176** | | | |

The plan's 141 is the eight M2–M10 files: 104 (52 on both) + 15 once + 4 web-socket only + 18
`host_address`. The file actually holds 23 `HostAddress` tests (18 in the plan's count; G2 added the
local-address ones), and the three new tests add 4 runs, so those eight files come to 150. `transport_test`
went 25 → 26 with the new connector case. 150 + 26 = 176.

Computed values: `expect(host.sendToAll(...), 2)` with three sessions (two paired) and `expect(unpairedGot, 0)`
stay as they were; the local-info test expects `isLocal` true and `remoteAddress` null on the in-process
transport, false and `'127.0.0.1'` on the web socket; the new connector test expects the cancel check to be
asked exactly twice (`expect(checks, 2)` — once before the connect, once after the socket opened) and the
host end to see `CloseCodes.goingAway`.

## New tests

1. `transport_test.dart`, "the web socket connector closes the socket when cancelled after it opened": a real
   `WebSocketListener`, an `isCancelled` that answers false once and true after, so the connect succeeds and
   the connector must close the socket and throw `ConnectFailed` (s2-g2 Q7); the listener's end is drained and
   shows `goingAway`.
2. `pairing_test.dart`, "shows the phone as local only on an in-process channel": the `ControllerInfo` for a
   local player.
3. `reconnect_test.dart`, "a host that stopped is reached again after it restarts": stop, watch the phone go
   `reconnecting`, start again, watch it reconnect and appear as `phone-1`. It takes a `freePort()` on both
   transports because a `WebSocketListener(preferredPort: 0)` that restarts binds a new port, and the phone
   keeps the address it paired with.

## Checks

- `tools/check.sh format analyze protocol connection metrics arena puzzle host phone tv` — all PASS;
  connection 176 tests, protocol 73, metrics 38, arena 30, puzzle 62, host 44, phone 262, tv 22.
- `dart analyze packages/connection` — No issues found (after `prefer_initializing_formals` pushed the
  connector to `required this._connector`).
- `tools/review.sh` — 4 FAIL, 6 NOTE. The FAILs are in `controller_app/lib/src/providers.dart` (617 lines;
  `flashOnPressProvider` 61 lines; `phoneMetricsProvider` 69 lines) and `controller_app/test/widget_test.dart`
  (1614 lines). Both files were already over the limit; this job adds one line to each. The NOTEs on my lines
  are the file sizes of `controller_client.dart` (400), `host_connection.dart` (377) and `host_server.dart`
  (367).

## Questions

1. **`ListenFailed` reads twice.** `host_service.dart` shows `'The server could not start: $e'` and
   `ListenFailed.toString()` is `'Could not start the server: …'`, so a taken port now reads "The server could
   not start: Could not start the server: …". Not changed (no message text in this job): either the caller
   shows `e.message` or the exception drops its prefix.
2. **R5 log line.** The client now closes a binary frame with `4003` instead of ignoring it, so a peer that
   sends one makes the client log its normal "closed by the host" line where it used to be silent. No peer
   sends binary frames; say if you want that line suppressed.
3. **`Future.delayed` in tests.** The brief says none in tests or lib. There were none to add, but the files I
   parameterised keep the waits they already had (`settle()`, the 16 ms status loop, the 20/50 ms ones, the
   300 ms "disconnect stops retrying" one). Removing them would rewrite what those tests measure; I read the
   rule as "don't reach for a delay to fix the new transport". The new tests have none.
4. **"Reports an unreachable host".** It used to bind and close a port; it now starts a host and stops it, so
   the same case means the same thing on both transports (`ConnectFailed` from a stopped listener or from a
   refused socket). Confirm that's the shape you want.
5. **Pre-existing review FAILs.** `providers.dart` and `controller_app/test/widget_test.dart` were already over
   the size limit and hold the two long providers; the constructor change forces one line in each. They want a
   split of their own, which is not this job.
6. **`client_connection.dart:134` `closeCode ?? 1000`.** Pre-existing NOTE (the 1000 default when a peer
   vanished without a close code). A named constant would clear it; not touched here.

## Suggestions

- Test the other half of item 3 explicitly: `SavedPairing` keeping the last network address after a local
  session (`PairingBook.remember`), which is only covered through `toInfo()` today.
- `ControllerClient._channel`/`_connection` still name two different things whose names read alike; worth a
  rename in a later step, when the host-phone player touches the same code.
- `HostServer.port` reports the first listener with a port, which is right for "the TV shows one address" but
  would need saying if a second network listener is ever added.
