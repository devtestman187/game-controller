# M12 step 2 — G1 plan: the transport change

Job: [s2-g1.md](s2-g1.md). Contract: [m12-transport.md](../design/m12-transport.md). Read with it:
[m12.md](../design/m12.md) §2.1 and §5a, [coding-guidelines.md](../coding-guidelines.md), `packages/connection`
(lib and test), and the call sites from the brief's `git grep`. Line numbers are today's files, before the split.
No code in this job.

## 0. Facts that change the brief's picture

- `tv_test_app` never names `HostServer` or `ControllerClient`; it goes through `party_host`. So the call sites
  in contract §2 are exactly: `host_service.dart`, `simulated_controllers.dart`, the phone app's
  `providers.dart`, `bin/sim_controller.dart`, `tool/ask_rating.dart`, and `party_host`'s `live_stats_test.dart`.
- `HostService` never passes `preferredPort` (`host_service.dart:102`), so `defaultPort` has to become the
  listener's default (Q4). `connectTimeout` is set by no caller outside `helpers.dart:52`, so the connector's
  4 s default is what production uses today.
- `HostAddress` cannot be local today: the constructor throws on an empty list (`host_address.dart:10`),
  `display` reads `ordered.first` (`:74`) and `label` falls back to `display` (`:77`). `HostAddress.local` needs
  a private constructor and a display rule (Q1).
- The client ignores a binary frame (`controller_client.dart:590`); the server closes one with 4003
  (`host_server.dart:465`). Contract §1 makes both close (R5).
- 89 tests in `packages/connection` today; only 52 of them open a channel (section 3).

## 1. Split map

Every new file goes in `packages/connection/lib/src/`. Public types are exported from `connection.dart`; the
internal classes (marked *internal*) are not exported and used only inside the package.

### 1a. Transport (contract §1)

| File | Types | What it takes | Est. lines |
| --- | --- | --- | --- |
| `transport/message_channel.dart` | `MessageChannel` | contract §1, nothing from today's code | 45 |
| `transport/channel_listener.dart` | `ChannelListener`, `ListenFailed` | contract §1 | 40 |
| `transport/connector.dart` | `Connector`, `ConnectFailed` | contract §1 | 45 |
| `transport/connect_error.dart` | `describeError` | `controller_client.dart:832-839`, moved whole (still exported) | 20 |
| `transport/web_socket_channel.dart` | `WebSocketChannelAdapter` | `host_server.dart:430`, `:447-460`; `controller_client.dart:560-564` | 110 |
| `transport/web_socket_listener.dart` | `WebSocketListener` | `host_server.dart:410-427` (`_bind`), `:429-445` (`_onRequest`) | 140 |
| `transport/web_socket_connector.dart` | `WebSocketConnector` | `controller_client.dart:526-563` | 100 |
| `transport/in_process_link.dart` | `InProcessLink` | new | 120 |
| `transport/in_process_listener.dart` | `InProcessListener` | new | 60 |
| `transport/in_process_connector.dart` | `InProcessConnector` | new | 35 |

### 1b. Host: `host_server.dart` (813) → five files

| File | Types | What it takes (today) | Est. lines |
| --- | --- | --- | --- |
| `host_types.dart` | `ControllerState`, `ControllerInfo` (+`isLocal`), `HostSnapshot`, `ControllerMessage` | `host_server.dart:12-170` | 145 |
| `saved_pairing.dart` | `SavedPairing` | `:99-143` | 50 |
| `host_pairings.dart` | `PairingBook` (*internal*) | `_known` `:248`, `_code`/`_wrongCodes` `:253-254`, `newPairingCode` `:300-306`, `pairings` `:308-330`, `forgetDisconnected` `:332-346`, local numbers `:392-406`, `_pickPlayer` `:606-619`, `_trimPairings` `:621-629`, `_newCode`/`_newToken` `:770-778`, `_Known` `:805-813` | 175 |
| `host_connection.dart` | `HostConnection` (*internal*, today's `_Session`), `HostSessionHost` (*internal interface*), `HostDetails` (*internal*) | `_Session` `:785-803`, `_onSocket` `:447-460`, `_onData` `:462-525`, `_forward` `:527-530`, `_onHello` `:532-539`, `_onPair`/`_accept` `:541-601`, `_send`/`_close`/`_onClosed`/`_ended` `:668-710`, `_tick`/`_latencyLine` `:633-666`, `_who` `:768` | 285 |
| `host_server.dart` | `HostServer` (implements `HostSessionHost`) | ctor `:178-204`, `start`/`stop`/`dispose` `:272-298`, senders `:348-390`, `capabilityFor` `:377-385`, `_tick` loop `:633-654`, `_controllers` `:712-762`, `snapshot`/`port` `:264-270`, `_emit` `:764-766` | 240 |

### 1c. Client: `controller_client.dart` (839) → nine files

The contract's suggested seam (message handling / reconnect and retry) runs through the same mutable state, so
this split is instead: value types, wire, messages, the three passive helpers, and the client itself.

| File | Types | What it takes (today) | Est. lines |
| --- | --- | --- | --- |
| `controller_identity.dart` | `ControllerIdentity` | `controller_client.dart:11-50` | 45 |
| `client_types.dart` | `ClientStatus`, `ClientProblem`, `ClientSnapshot` | `:52-192` | 150 |
| `client_host.dart` | `ClientHost` (*internal interface*) | new: what the two files below need from `ControllerClient` | 65 |
| `client_input.dart` | `ClientInput` (*internal*) | `:282-289`, `sendInput`/`_sendInputState` `:396-432` | 85 |
| `client_controls.dart` | `ClientControls` (*internal*) | `:248-249`, `:307-317`, `:349-366` | 80 |
| `client_metrics.dart` | `MetricsOutbox` (*internal*) | `:252-260`, `sendMetrics` `:321-342`, `_onMetricsAck` `:368-377`, `_resendMetrics` `:379-389` | 100 |
| `client_connection.dart` | `ClientConnection` (*internal*) | state `:264-290`, `_open`/`_onConnectFailed` `:526-584`, `_onSocketDone` `:706-733`, `_beat` `:735-749`, `_dropSocket` `:790-799` | 190 |
| `client_messages.dart` | `ClientMessages` (*internal*) | `_onData` `:586-645`, `_onWelcome` `:647-670`, `_onPairResult` `:672-704` | 150 |
| `controller_client.dart` | `ControllerClient` (implements `ClientHost`) | ctor `:200-218`, getters `:291-326`, `sendRating` `:344-347`, `connect` … `dispose` `:437-522`, `_scheduleRetry` `:751-772`, `_giveUp` `:774-788`, `_teardown`/`_set` `:801-823` | 285 |

### 1d. How private state is shared (no `part` files)

1. **Value types** (`host_types`, `saved_pairing`, `client_types`, `controller_identity`) hold no state; they
   move unchanged, plus `ControllerInfo.isLocal` (contract §2).
2. **Owned state moves with its class.** `PairingBook` owns the known pairings, the code, the wrong-code count,
   the local numbers and the `Random` (`host_server.dart:243-254`), so `HostServer` builds it in its initializer
   list from constructor parameters and `late String _code` (`:253`) disappears. `ClientInput`,
   `ClientControls` and `MetricsOutbox` own their fields and stream controllers and take no callback; the client
   creates them as field initialisers and keeps the wiring, so no `late` is needed on either side.
3. **One small internal interface per side** for what a per-connection object needs from its owner:
   - `HostSessionHost` (`host_connection.dart`), implemented by `HostServer`: `HostDetails details`,
     `PairingBook pairings`, `int nowMs`, `log`, `emit`, `forward(ControllerMessage)`,
     `replaceOther(HostConnection, int code, String reason)`, `reservePlayerNumber(int? previous)`,
     `sessionEnded(HostConnection)`, `pairingsChanged()` — ten members, each one today's call from the switch.
   - `ClientHost` (`client_host.dart`), implemented by `ControllerClient`: `log`, `nowMs`, `snapshot`,
     `setSnapshot`, `takePendingCode`, `everPaired` (get/set), `tokens`, `tokenChanged(hostId, token)`,
     `identity`, `send(Message)`, `dropChannel({int? closeCode})`, `scheduleRetry`, `giveUp`.
   `HostConnection`s are made in the server's `_onChannel` with `this`; `ClientConnection` and `ClientMessages`
   are made per connection in `_open`, so neither needs an init-order shortcut.
   `HostServer` and `ControllerClient` stop importing `dart:io`; `describeError` moves to `src/transport/` so the
   connector can log the same text without a sideways import.

Total: 22 new files plus the two rewritten ones (`host_server.dart`, `controller_client.dart`), about 715 + 895
+ 1150 lines, against 813 + 839 today.

## 2. Call sites outside lib/src/transport

| File | Change |
| --- | --- |
| `packages/connection/lib/connection.dart` | export the ten transport files and `host_types`, `saved_pairing`, `controller_identity`, `client_types`; the library doc gains the transport paragraph |
| `packages/party_host/lib/src/host_service.dart:102` | add `listeners: [WebSocketListener(hostName: _hostName, log: log.sink('host'))]`, nothing else |
| `packages/party_host/lib/src/simulated_controllers.dart:53` | `connector: WebSocketConnector(log: logBuffer.sink('sim$n'))` |
| `packages/party_host/test/live_stats_test.dart:37` | `listeners: [WebSocketListener(preferredPort: 0, hostName: 'Test TV')]`; `:69` gets `connector: WebSocketConnector()` |
| `controller_app/lib/src/providers.dart:128` | `connector: WebSocketConnector(log: log.sink('client'))` |
| `packages/connection/bin/sim_controller.dart:62` | `connector: WebSocketConnector(log: (m) => stdout.writeln('  · $m'))` |
| `packages/connection/tool/ask_rating.dart:13` | `listeners: [WebSocketListener(preferredPort: 0, hostName: 'Rating check')]` |
| `docs/architecture.md` | new "Transport (M12 step 2)" section: three interfaces, two transports, why D1 (G4) |
| `packages/connection/test/helpers.dart` + six test files | test map, section 3 |

Nothing else changes: `tv_test_app` never names `HostServer` or `ControllerClient`, and `ServerGameHost`
(`game_host.dart:221`), `LiveStats` (`live_stats.dart:66`) and `HostService` only read the snapshot.

## 3. Test map

Before: 89 tests in 8 files (host_address 18, input 12, m6 14, m9 14, m10 6, pairing 12, reconnect 9, haptic 4).

| File | Total | On both transports | Once (no channel) | Web-socket only |
| --- | --- | --- | --- | --- |
| `haptic_test.dart` | 4 | 4 | – | – |
| `input_test.dart` | 12 | 8 | 4 | – |
| `m6_test.dart` | 14 | 9 | 4 | 1 |
| `m9_test.dart` | 14 | 8 | 6 | – |
| `m10_test.dart` | 6 | 5 | 1 | – |
| `pairing_test.dart` | 12 | 11 | – | 1 |
| `reconnect_test.dart` | 9 | 7 | – | 2 |
| `host_address_test.dart` | 18 | – | 18 | – |
| **Total** | **89** | **52** | **15** | **4** |

- **Once** (no channel involved; wrapping them in the transport loop would prove nothing):
  `input_test.dart:104, 115, 122, 130`; `m6_test.dart:144, 172, 187, 194`; `m9_test.dart:108, 115, 145, 153,
  161, 179`; `m10_test.dart:94` (local player only).
- **Web-socket only**: `pairing_test.dart:146` plain status page (no HTTP in-process); `m6_test.dart:54`
  host restarts on the same port and the test skips to the new port (`:86-89`); `reconnect_test.dart:26`
  asserts `host.port == port` (`:38`); `reconnect_test.dart:153` address ordering, and `InProcessConnector`
  rejects a network target. `host_address_test.dart` stays unparameterised (contract §3) and gains about three
  `HostAddress.local` cases (JSON `isLocal`, no display, not a network target).
- **Both, but they need a hand-driven peer** (today a raw `WebSocket`): `pairing_test.dart:116, 124`,
  `input_test.dart:42`, `haptic_test.dart:51, 62`, `reconnect_test.dart:88, 103`. Helpers gain
  `MessageChannel rawPeer(HostServer host, TestTransport t)` (web socket: `WebSocket.connect` wrapped in
  `WebSocketChannelAdapter`; in-process: the listener's `connect()`) and a test `Connector` that hands the fake
  host's end of an `InProcessLink` to a real `ControllerClient`. Question 5.
- Helpers: `enum TestTransport { webSocket, inProcess }`; `startHost`, `newClient` and `addressOf` take one
  (default `webSocket`, so a missed call site still compiles). `startHost` keeps one `InProcessListener` per
  test, so a host that restarts re-registers on the same listener (`reconnect_test.dart:42` runs on both).
  `newClient` builds `WebSocketConnector(connectTimeout: 1 s, log: …)` or `InProcessConnector(listener)`;
  `addressOf` returns `127.0.0.1:port` or `HostAddress.local(hostId: host.hostId)`.

After: 52 tests run twice, so 104 + 4 + 15 + 18 = **141 runs** (was 89). Plus the new `test/transport_test.dart`
(contract §3: order, close code and reason on both ends, send after close, close twice, done once, binary frame
web-socket only, `connect()` before start and after stop, no delivery inside `send`, `stop()` leaves channels
open): about 16 runs, 2 per case that runs on both channels.

## 4. Behaviour risks on the in-process channel

- **R1 A frame before `listen`.** `InProcessListener.connect()` hands the host end to the server synchronously,
  so the server can answer before the client subscribes. A non-sync `StreamController` buffers events and done,
  so no frame is lost and order holds; `transport_test` checks both, and that a frame never arrives inside
  `send`. Today's expiry path is `host_server.dart:455` (listen right after upgrade).
- **R2 Close before hello, or before listen.** `InProcessLink.close` records code and reason first, then closes;
  `closeCode`/`closeReason` are readable after `incoming` is done, and the client's `onDone` still runs
  (`controller_client.dart:560-563`). A refused channel keeps 1001 (`host_server.dart:448-451`).
- **R3 Log lines.** The server keeps every string in the same order. The port line (`host_server.dart:276`) is
  written only for a listener with a port, so the TV log is unchanged and the in-process listener adds no line.
  `_who` (`:768`) uses `hello?.name ?? remoteAddress`, with a named `localPeerLabel` when the address is null —
  a new line only for local peers. The client's two connect lines (`:534`, `:542`) move into
  `WebSocketConnector` with the same sink, so text and tag stay.
- **R4 Heartbeats.** Same `Timer.periodic` (`host_server.dart:278`) and same order inside `_tick`
  (`:635-645`); `lastHeardMs` still updates on every frame (`:464`). Round trips in-process are about 0 ms, so
  rtt and input delay read about 0; every test asserts a bound, not a value (`pairing_test.dart:33`,
  `m6_test.dart:223`), and `InputLatency` copes with a 0 ms round trip (`latency.dart`).
- **R5 Binary frames.** Today the server closes 4003 (`host_server.dart:465`) but the client **ignores** binary
  (`controller_client.dart:590`). With the check in the adapter, the client now drops with 4003 →
  `ClientProblem.protocolError` (`:716`). The contract asks for this; no peer sends binary today. It is the one
  intended behaviour change of the step.
- **R6 Send after close.** The adapters' `send` does nothing once closing, so the existing try/catch stays for
  the socket's own errors (`host_server.dart:668-675`, `controller_client.dart:808-816`) and no log line is
  added or lost.
- **R7 End of a session.** `_close` still ends the session before closing the channel (`:678-683`); a peer that
  sends a frame and closes keeps order, because the link delivers in order. `stop()` closes sessions before the
  listeners (`:282-291`), so the phone sees 1001 `Host is closing` exactly as today, then `ConnectFailed` from
  the stopped listener — which `_onConnectFailed` (`:569-584`) turns into `reconnecting` when it had paired.

## 5. Questions (contract items that don't fit the code as written)

1. `HostAddress.local`: `label => name ?? display` (`host_address.dart:77`) and `display` = `label` for a local
   address (`:74`) recurses when `name` is null (the `name` parameter is optional, contract §2). What should
   `display`/`label` return then — a fixed word (which?) or make `name` required for local?
2. `ControllerInfo.remoteAddress` is a non-nullable `String` (`host_server.dart:53`, filled at `:725` from
   `_Session.remoteAddress`) but a local channel's address is null (contract §1). Plan: keep `String`, use `''`
   when null, `isLocal` tells the UI. Confirm, or make it nullable?
3. `ListenFailed` and `ConnectFailed` have no `toString` (contract §1). `HostService.start` shows
   `'The server could not start: $e'` (`party_host/lib/src/host_service.dart:198-200`), so today's readable
   `SocketException: …` text would become `Instance of 'ListenFailed'`. Add `toString() => message`, or does the
   caller switch to `ListenFailed.message`?
4. `WebSocketListener`'s `preferredPort` has no default in the contract; `HostService` (`host_service.dart:102`)
   relies on today's default `defaultPort` (`host_server.dart:182`). Plan: `this.preferredPort = defaultPort`.
5. Running the seven hand-driven-peer tests on both transports needs the helpers described in section 3
   (`rawPeer`, a test `Connector`, the listener per test) — the brief's `startHost`/`newClient`/`addressOf` don't
   hand a test the in-process listener. Go ahead, or keep those seven web-socket only?
6. Eleven tests use no channel (listed in section 3). The contract's loop rule only covers transport tests;
   plan: run those once, outside the `group(t.name, …)` loop. Confirm.

## 6. Gates

- **G2** — `transport/` fully implemented (interfaces, both adapters, link, listener, connector,
  `connect_error`), `test/transport_test.dart` green, `enum TestTransport` added to helpers but
  `startHost`/`newClient`/`addressOf` unchanged, so the server and client still compile as they are.
- **G3** — `HostServer` and `ControllerClient` on `MessageChannel`; the host and client splits from section 1
  done; helpers take a transport; the six test files parameterised; the 141 runs green. The checks here are
  package-scoped (`dart analyze packages/connection`, `dart test packages/connection`): the seven call sites in
  section 2 still use the old constructors, so the repo-wide build only comes back at G4.
- **G4** — call sites, `docs/architecture.md`, every check (`tools/check.sh`, the app tests) green.

No change to the gates. The only note is the G3 check scope above; moving the seven one-line call-site edits
into G3 would keep every gate green and is suggested in the report, not done here.
