# M12 step 2 contract: transport

The interfaces for [m12.md §2.1](m12.md) (fixes B2). They're Claude's contract: the worker implements them as written. A change goes back to Claude first.

**Goal:** `HostServer` and `ControllerClient` stop knowing about WebSockets. They talk through a `MessageChannel`. A WebSocket and an in-memory link are two ways to make one. Pairing, tokens, heartbeats, close codes, RTT and latency work exactly as they do today on both. Every `connection` test that isn't about sockets themselves runs on both transports.

## 1. Types (all in `packages/connection/lib/src/transport/`, exported from `connection.dart`)

```dart
/// One open, ordered, text-only connection between a host and a controller
/// (PRD v2 P1). Implementations: WebSocketChannelAdapter, and the two ends
/// of an InProcessLink.
abstract interface class MessageChannel {
  /// The peer's network address for logs and saved pairings, shown as the
  /// user would type it (displayIp). Null for an in-process peer.
  String? get remoteAddress;

  /// True when the peer runs in this process: the host phone's own player
  /// (D1). Such a channel has no network address.
  bool get isLocal;

  /// Text frames from the peer, in order. Single subscription. May carry an
  /// error (logged by the owner); closes once the channel is closed by
  /// either side. A binary frame closes the channel with
  /// CloseCodes.protocolError, "Expected text frames".
  Stream<String> get incoming;

  /// Sends one text frame. Does nothing once the channel is closing.
  void send(String text);

  /// Closes the channel with [code] (CloseCodes) and [reason]. Calling it
  /// again does nothing. Completes when the close is done; never throws.
  Future<void> close(int code, [String? reason]);

  /// After [incoming] is done: the close code and reason, whichever side
  /// closed. Null before then, or if the peer vanished without one.
  int? get closeCode;
  String? get closeReason;
}

/// Accepts channels for a HostServer: the WebSocket listener on the LAN,
/// or the in-process listener the host phone's own player connects to.
abstract interface class ChannelListener {
  /// Starts accepting. Each new channel goes to [onChannel]; the server
  /// owns it from then on. Throws ListenFailed if it can't start.
  Future<void> start(void Function(MessageChannel channel) onChannel);

  /// Stops accepting. Channels already handed over stay open: the server
  /// closes them. Calling it when stopped does nothing.
  Future<void> stop();

  /// The port phones reach this listener on, once started. Null for a
  /// listener without one (in-process).
  int? get port;
}

/// Opens a channel to a host for a ControllerClient.
abstract interface class Connector {
  /// Opens a channel to [target], trying its addresses in order. Stops
  /// trying, and closes anything it opened, as soon as [isCancelled] is
  /// true. Throws ConnectFailed with the last error when nothing opens.
  Future<MessageChannel> open(HostAddress target, {required bool Function() isCancelled});
}

/// A listener couldn't start (every bind attempt failed).
final class ListenFailed implements Exception {
  ListenFailed(this.message);
  final String message;
  @override
  String toString() => message; // HostService shows it as is
}

/// A connector couldn't open a channel. [osErrorCode] is the socket's OS
/// error, when there was one (the client shows "is the firewall on?" from it).
final class ConnectFailed implements Exception {
  ConnectFailed(this.detail, {this.osErrorCode});
  final String detail;
  final int? osErrorCode;
  @override
  String toString() => detail;
}
```

### Implementations

| Type | File | What it does |
| --- | --- | --- |
| `WebSocketChannelAdapter` | `transport/web_socket_channel.dart` | Wraps a `dart:io` `WebSocket` and its remote address. The only place, with the two below, that imports `WebSocket`. |
| `WebSocketListener` | `transport/web_socket_listener.dart` | Today's `_bind` (dual-stack first, preferred port then any) and `_onRequest` (upgrade on `webSocketPath`, the plain status page otherwise). Constructor: `preferredPort` (default `defaultPort`, as today), `hostName` (for the page), `log`. |
| `WebSocketConnector` | `transport/web_socket_connector.dart` | Today's loop in `ControllerClient._open`: each of `target.ordered`, `connectTimeout`, the log lines. Constructor: `connectTimeout` (default 4 s, named constant), `log`. Rejects a local target with ConnectFailed. |
| `InProcessLink` | `transport/in_process_link.dart` | A connected pair: `MessageChannel get host`, `MessageChannel get controller`. Both ends `isLocal`, `remoteAddress` null. Frames are delivered asynchronously (never inside `send`), in order. Closing either end closes both, with the same code and reason on both. |
| `InProcessListener` | `transport/in_process_listener.dart` | `ChannelListener` with `port` null, plus `MessageChannel connect()`: makes a link, hands its host end to the server, returns the controller end. Throws ConnectFailed when not started. |
| `InProcessConnector` | `transport/in_process_connector.dart` | `Connector` over one `InProcessListener`. Accepts only a local target. |

## 2. Changes to existing types

- `HostServer({required List<ChannelListener> listeners, ...})` replaces `preferredPort`. `start()` starts every listener (any failure: stop the started ones, rethrow). `stop()` stops them and closes every session as today. `port` and `HostSnapshot.port` come from the first listener with a port. `running` means started. Session code takes a `MessageChannel`; the session's address is `channel.remoteAddress`.
- `ControllerInfo` gets `bool isLocal` (from the channel), and `remoteAddress` becomes `String?`: null for a local player, never `''` as a stand-in. Callers that show it handle null. `SavedPairing.remoteAddress` keeps the last network address; a local session doesn't overwrite it.
- `ControllerClient({required Connector connector, ...})` replaces `connectTimeout`. `_open` asks the connector; `ConnectFailed.osErrorCode` replaces the `SocketException` check. Everything after the channel opens is unchanged. `describeError` stays for the connector's messages.
- `HostAddress.local({required String hostId, required String name})`: the target for the host phone's own player. `isLocal` true, `addresses` empty, `port` 0. `display` and `label` are `name` (no address to show). `uriFor` and `ordered` aren't used for it (the web socket connector rejects it). JSON round-trips `isLocal`.
- `HostServer` and `ControllerClient` no longer import `dart:io` for sockets. `HostServer` may keep `dart:io` only if something else needs it: say what in the plan.
- Callers updated in the same job (G4): `party_host` (`LiveHostService` builds `HostServer` with `[WebSocketListener(...)]`, the simulated controllers get a `WebSocketConnector`), `controller_app` (its client gets a `WebSocketConnector`). No behaviour change in either app: the host phone's own player comes in step 3.

## 3. Rules for this step

- Files: `host_server.dart` (813 lines) and `controller_client.dart` (839) are split along responsibilities as part of this job, each file ≤300 (hard limit 400). Suggested seams, to be confirmed in the G1 plan: host: the server's lifecycle and public API / the per-session state and message handling / pairing and saved pairings / the public value types (HostSnapshot, ControllerInfo, ControllerMessage, SavedPairing). Client: lifecycle and public API / the message handling / reconnect and retry / the value types (ClientSnapshot, ControllerIdentity, ClientStatus, ClientProblem).
- No public name changes beyond §2. Every message, close code, log line and timing stays the same.
- No `Future.delayed` or timers in the in-process link: asynchrony comes from the stream (a non-sync `StreamController`).
- Tests: `test/helpers.dart` gets `enum TestTransport { webSocket, inProcess }`; `startHost`, `newClient` and `addressOf` take one, required (no default: a missed call site must not compile). Tests that drive a raw peer use `rawPeer(host, transport)` and a test `Connector`; tests that open no channel run once, outside the loop. Each test file runs its tests once per transport (`for (final t in TestTransport.values) group(t.name, ...)`), except the tests about sockets themselves (port fallback, the plain status page, binary frames, address ordering, `host_address_test.dart`), which stay web-socket only. The plan lists which.
- New contract tests in `test/transport_test.dart`, run against both channel types: order kept; close code and reason seen on both ends; `send` after close does nothing; `close` twice does nothing; `incoming` done once. Web socket only: a binary frame closes with protocolError. In-process: `connect()` before `start()` and after `stop()` throws ConnectFailed; a frame is never delivered inside `send`. Listener: `stop()` leaves handed-over channels open.
- `docs/architecture.md` gets a short transport section (the three interfaces, the two transports, why: D1).

## 4. Gates (decided at G1, Nov 6; plan: [s2-g1-plan.md](../briefs/m12/s2-g1-plan.md))

- **G2** the `transport/` types and `test/transport_test.dart`. `HostServer` and `ControllerClient` untouched.
- **G3** the split of `host_server.dart` and `controller_client.dart` per the plan's §1b–1d, as a pure move: still on `WebSocket`, no behaviour or test change, every check green.
- **G4** the server and client on `MessageChannel`, the callers, the parameterised tests, `docs/architecture.md`, every check green.
