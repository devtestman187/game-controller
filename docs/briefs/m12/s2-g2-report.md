# M12 step 2 — G2 report: transport types and their contract tests

Job: [s2-g2.md](s2-g2.md). Contract: [../design/m12-transport.md](../design/m12-transport.md) §1–§3,
decisions from [s2-g1-plan.md](s2-g1-plan.md) §5 (Q1–Q6).

## What changed, file by file

New, all in `packages/connection/lib/src/transport/`:

| File | Lines | What it holds |
| --- | --- | --- |
| `message_channel.dart` | 30 | `MessageChannel`, the contract's doc comments as written |
| `channel_listener.dart` | 30 | `ChannelListener` and `ListenFailed` (`toString() => message`, Q3) |
| `connector.dart` | 29 | `Connector` and `ConnectFailed` (`detail`, `osErrorCode`, `toString`, Q3) |
| `connect_error.dart` | 13 | `describeError`, moved whole from `controller_client.dart` (Q6/plan §1d) |
| `web_socket_channel.dart` | 77 | `WebSocketChannelAdapter`: socket → `MessageChannel`; binary frame closes with `CloseCodes.protocolError`, "Expected text frames" (R5); `incoming` is a non-sync `StreamController` so a frame is never delivered inside `send`; `close` never throws and a second call returns the first future |
| `web_socket_listener.dart` | 86 | `WebSocketListener`: today's `_bind` (dual stack, preferred port then any) and `_onRequest` (upgrade on `webSocketPath`, the status page otherwise); `preferredPort = defaultPort` (Q4); bind failure becomes `ListenFailed` |
| `web_socket_connector.dart` | 68 | `WebSocketConnector`: today's loop (each of `target.ordered`, `connectTimeout`, the two log lines), rejects a local target, checks `isCancelled` before each address and once after a successful connect (closing what it opened); `defaultConnectTimeout = Duration(seconds: 4)` |
| `in_process_link.dart` | 87 | `InProcessLink`: two ends over two non-sync `StreamController`s, both `isLocal`, `remoteAddress` null, one shared close state so either end closes both with the same code and reason; no timer, no delay |
| `in_process_listener.dart` | 36 | `InProcessListener`: `port` null; `connect()` hands the host end to the server at once and returns the controller end, throws `ConnectFailed` before `start` and after `stop` |
| `in_process_connector.dart` | 24 | `InProcessConnector`: over one `InProcessListener`, local target only, throws `ConnectFailed` when cancelled first |

Changed:

- `packages/connection/lib/connection.dart`: exports the nine transport files that hold public types. `connect_error.dart` is **not** exported: `describeError` is used only inside the package (`grep` over `packages`, `controller_app`, `tv_test_app`: `controller_client.dart:542, 563, 571` before the move; no test or app uses it), per the brief's item 3.
- `packages/connection/lib/src/controller_client.dart`: the only edit the brief allows — added `import 'transport/connect_error.dart';` and removed the moved function (8 lines). Nothing else in the file is touched.
- `packages/connection/lib/src/host_address.dart`: `HostAddress.local({required String hostId, required String name})` (Q1), a private constructor both it and `copyWith` use (validation "not empty" still applies to network addresses only), `isLocal` field, `display` = the name for a local address, `label` unchanged (`name ?? display`, so also the name), `toJson` writes `isLocal` only when true, `fromJson` reads `isLocal == true` (absent = false, so old JSON decodes as a network address) and validates `hostId`/`name` for a local one, `==`/`hashCode`/`toString` include `isLocal`.
- `packages/connection/test/host_address_test.dart`: new group `HostAddress.local` with 5 cases (see the list below).
- `packages/connection/test/transport_test.dart`: new, 25 tests.

Not touched, as the brief says: `host_server.dart`, `helpers.dart`, the other six test files. No `enum TestTransport` (that is G3/G4 and would not compile against today's `startHost`).

## Tests and their expected values

`test/transport_test.dart`, group "a connected pair", run once per channel kind (`webSocket`: `WebSocketListener(preferredPort: 0, hostName: 'Test TV')` plus `WebSocketConnector`; `inProcess`: `InProcessListener` plus `InProcessConnector` with `HostAddress.local(hostId: 'host-1', name: 'Test TV')`) — 8 cases × 2 = 16:

| Case | Rule and values |
| --- | --- |
| keeps the order of frames, also those sent before the peer listens | send `one`, `two`, `three` first, then `take(3)` → exactly `['one', 'two', 'three']` (R1: the non-sync controller buffers before `listen`) |
| never delivers a frame inside send | after `send('hello')` the listener has not run (`first.isCompleted` false); it then receives `'hello'` |
| shows the close code and reason on both ends | both `closeCode`s null before; after `controller.close(CloseCodes.replaced, 'Replaced by a newer connection')` both ends report code 4002 and that reason |
| ends incoming once, when either side closes | one `onDone` event, then the stream is done (`doneEvents == 1`) |
| does nothing when send is called after close | close the host end (1001, "Bye"), then `host.send('too late')`; the peer's frames are empty |
| keeps the first code when close is called twice | `close(1001, 'Bye')` then `close(4003, 'Second')`: both futures complete, the peer still sees 1001 / "Bye" |
| says whether the peer is local, and its address | web socket: `isLocal` false and `remoteAddress` `'127.0.0.1'` on both ends; in-process: `isLocal` true and `remoteAddress` null |
| stays open when the listener stops | `listener.stop()`, then `send('still here')` arrives as `['still here']` |

Once each, outside the loop (9): binary frame → frames empty, `closeCode` `CloseCodes.protocolError` (4003), `closeReason` `'Expected text frames'`; plain GET `/` → status 200 and `'Test TV is running the controller host (protocol v1).\n'` (`protocolVersion == 1`); web socket connector rejects `HostAddress.local`; web socket connector with `isCancelled: () => true` → `ConnectFailed` and the listener received no channel; in-process connector rejects `HostAddress(addresses: ['127.0.0.1'], port: 45780)`; in-process connector cancelled first → `ConnectFailed`, no channel; `InProcessListener().connect` before `start` → `ConnectFailed`; after `stop` → `ConnectFailed`; `port` is null after `start`.

`host_address_test.dart` (18 → 23): local address shows `'Thumb Party TV'` for `display` and `label`, `addresses` empty, `port` 0, `isLocal` true; `toJson` is `{'addresses': [], 'port': 0, 'hostId': 'host-1', 'name': 'Thumb Party TV', 'isLocal': true}` and `fromJson` gives an equal address; a network address's JSON has no `isLocal` key, decodes with `isLocal` false, `display` `'10.0.0.2:45780'`, `ordered` `['10.0.0.2']`; a local address is not equal to a network address of the same `hostId`; `WebSocketConnector().open(local, …)` throws `ConnectFailed`.

No `Future.delayed` and no `Timer` anywhere in the new code or tests. One real-time trap was avoided in the binary-frame test: a raw `WebSocket` that is never listened does not answer the close handshake, so dart:io's 5 s close timeout made the test take 5 s; the test now does `socket.listen((_) {})`, which costs nothing and keeps it instant.

## Checks

`tools/check.sh format analyze connection`: **PASS format, PASS analyze, PASS connection (119 tests, 8 s)** — 89 before, plus 25 transport and 5 host-address cases.

`tools/review.sh`: 1 FAIL and 3 NOTE, none on a line this job added:

- FAIL size `controller_client.dart`: 830 lines, pre-existing (the file was 839; the split is G3 and outside this gate). My diff there is the import and the removed function.
- NOTE func `controller_client.dart:527` `_open` (42 lines) and `:587` `_onData` (60 lines): pre-existing.
- NOTE number `web_socket_connector.dart:14`: the `4` inside `const Duration defaultConnectTimeout = Duration(seconds: 4)` — a named, documented constant, not a bare literal.

## Questions and things I wasn't sure about

1. **`controller_client.dart`**: the brief's `stop:` line says don't touch it, and `do:` item 1 says the import and the removal of `describeError` are the one edit allowed there. I followed item 1, because otherwise the function exists twice (or an unused function is left behind). Confirm that this is what G2 means.
2. **`describeError` stops being public.** It was exported through `controller_client.dart`; `connect_error.dart` is not exported, per item 3 and the check that nothing outside the package uses it. Confirm it should stay internal at G4 too.
3. **`defaultConnectTimeout`**: the brief asks for constants "named with units". A `Duration` carries its unit in the type, and the repo's other durations (`heartbeatInterval`, `pairingTimeout`) have no suffix, so I did not add one. Say the word if you want `defaultConnectTimeoutS`.
4. **`WebSocketChannelAdapter` takes `remoteAddress`** as a required named parameter: `dart:io`'s `WebSocket` has no peer address. The listener passes today's `displayIp(request.connectionInfo?.remoteAddress.address ?? '?')` and the connector passes `displayIp(address)`. That keeps the `'?'` fallback the server's log line has today; the adapter never returns null for a web socket.
5. **`InProcessLink.close` completes at once**, without waiting for the peer to consume the done event: awaiting a single-subscription `StreamController`'s close future can wait forever for a listener that never comes. The close code and reason are set before both streams close, so both ends see them. If "completes when the close is done" is meant to include the peer's done event, that needs a rule in the contract.
6. **Cancel order in `InProcessConnector`**: `isCancelled` is checked before the local-target check, so a cancelled open reports "Connection cancelled" rather than "That address needs a network connection". Only the error type is tested, as the brief lists.
7. **`WebSocketConnector` cancelling after a successful connect** (contract §1: "closes anything it opened") is implemented but not tested: the flag would have to flip between the two checks, and the listener may already have been handed the channel, so a test could only assert the `ConnectFailed`. The tested cancellation is the deterministic one, `isCancelled` true before the first attempt.
8. **`ConnectFailed.osErrorCode`** is filled from a `SocketException`'s `osError.errorCode` (the same source as today's client check). No test: the code differs per platform, and the brief's cases don't ask for one. Happy to add one asserting only "not null" if you want it.
9. **`HostAddress.copyWith` now keeps `isLocal`** (through the private constructor), so copying a local address doesn't throw on its empty list. Nothing in the repo calls `copyWith` today.
10. `sameHostAs` still compares by `hostId` only, so a local target and a network target of the same host match each other. That looked right to me; flag it if the connect flow needs them apart.
11. The working tree already had `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and `generated_plugins.cmake` modified before this job started; I didn't touch them (they are generated).
