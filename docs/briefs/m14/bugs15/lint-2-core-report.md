# M14 bugs15 lint-2-core — strict lint clean for connection, protocol and game_kit

## Summary

`dart analyze packages/connection packages/protocol packages/game_kit` prints **"No issues found"** with the
strict settings on: 27 issues fixed, no `// ignore`, no behaviour, text or public-API change.

| Kind | Count | Where |
| --- | --- | --- |
| `argument_type_not_assignable` (error) | 8 | the `dynamic` `i` of three `Iterable.generate` calls; `winners`/`standings` in `view_result.dart` |
| `inference_failure_on_instance_creation` | 3 | the same three `Iterable.generate` calls |
| `strict_raw_type` | 1 | `_optionalInt(Map json, …)` in `view_result.dart` |
| `inference_failure_on_collection_literal` | 2 | `'data': {}` and `[]` in `protocol/test/m9_test.dart` |
| `discarded_futures` | 7 | `client_connection`, `controller_client`, `host_connection`, `host_server`, `sim_controller`, `frame_view` ×2 |
| `unawaited_futures` | 2 | `sim_controller.dart:188`, `connection/test/client_view_test.dart:115` |
| `close_sinks` | 3 | the in-process link's two controllers and the WebSocket connector's socket |
| `cancel_subscriptions` | 1 | `client_view_test.dart`'s `_Batches` subscription (a `late final` field) |
| **Total** | **27** | |

**Possible real bugs:** none new, and no ordering is at risk (every close and send enqueues before its future
is dropped); the two swallowed close errors, `host_server`'s unhandled close and `frame_view`'s cancels are
listed below.

**Decisions:** `Iterable<int>.generate` in the three list helpers; `view_result`'s private readers take
`Object?` / `Map<Object?, Object?>`, with the same `FormatException`; the in-process controllers close through
a `closePipes` callback the factory builds (invisible to the lint; two non-sync closes, order not
observable); the WebSocket connector drops its `opened` copy; `_Batches`' subscription is a local cancelled in
`addTearDown`; `client_view_test` awaits the close. No `docs/code-health.md` entry needed.

**Test counts** (`tools/check.sh format analyze protocol connection kit`, run once): protocol **118**,
connection **295**, kit **74** passed, **format PASS**; **analyze FAIL** on the 80 issues outside this job
(controller_app 18, metrics 36, party_host 18, puzzle_game 5, test_game 1, toy_look 1, test/support 1 — the
lint-3 and lint-4 jobs). None in these three packages.

## Possible real bugs

The discarded futures whose failure would be lost or whose order matters; behaviour was not changed beyond
`unawaited`/`await`. `unawaited` only marks a future used, so its error still reaches the zone: nothing that
used to surface is silent now.

1. `connection/lib/src/host_connection.dart:118` — the host's own close is not awaited and its error is
   swallowed by an existing `.then((_) {}, onError: (_) {})`. If the socket close fails, the host keeps the
   channel's resources until the peer's timeout and nothing is logged. Intentional (the comment says a close
   on a dead network can wait a long time), unchanged.
2. `connection/lib/src/client_connection.dart:139` — the phone's `dropChannel` close, same shape: failure
   lost, no log. Intentional (same comment), unchanged.
3. `connection/lib/src/host_server.dart:285` — a channel that arrives while the server is stopping is closed
   without waiting. If that close throws, the error is unhandled (nothing catches it) and the server is
   already stopping, so the only risk is a stray socket until the OS drops it. Low.
4. `game_kit/lib/src/frame_view.dart:140,147` — `StreamSubscription.cancel()` in `didUpdateWidget` and
   `dispose` is not awaited (dispose can't wait). A cancel that fails is lost; a cancel rarely fails. Low.
5. `connection/bin/sim_controller.dart:136,188` — a dev tool (stdin pairing code, Ctrl-C); a lost error there
   only affects the tool's exit. None in `lib/`.
6. `connection/lib/src/controller_client.dart:278` — `_open` starts `ClientConnection.open` in the
   background; that method catches `ConnectFailed` itself and reports it through `_onConnectFailed`.

## Fix notes

- `Iterable.generate(n).every((i) => a[i] == b[i])` → `Iterable<int>.generate(n)…` (`client_types.dart`,
  `host_address.dart`, `server_game_host.dart`). Same runtime behaviour, one type argument.
- `ViewResult.fromJson`'s private helpers take `Object?` instead of `Object` and `Map<Object?, Object?>`
  instead of a raw `Map`: the values come from decoded JSON, so null is the only extra value they now
  accept. Each still throws the same `FormatException`, and no caller passes null (`winners`/`standings` are
  checked for null first), so no decode result changes.
- `m9_test.dart`'s empty `{}` / `[]` got explicit type arguments (`<String, Object?>`, `<Object?>`); the
  encoded frames are identical.
- `close_sinks` found no missed close, only closes the analyzer could not see across classes:
  - The in-process link's two controllers are closed by `_InProcessEnd.close`, which the lint cannot follow
    through the shared `_Closing`. `_Closing` now holds the close as a `closePipes` callback that the
    factory builds with the two controllers, so creation and closing are in one function. Both controllers
    are non-sync, so both closes are scheduled before any listener runs: which one is closed first is not
    observable, and the link's behaviour is unchanged.
  - `WebSocketConnector.open` closed `opened`, a copy of `socket`, so the lint saw the local as unclosed.
    The copy is gone and `socket` is null-checked, closed and returned directly — same behaviour.
- `cancel_subscriptions` on `client_view_test.dart`'s `_sub`: it was cancelled in `addTearDown`, but it was
  a `late final` field assigned in the constructor, which the lint cannot follow. It is only used there, so
  it is a local now, cancelled in the same `addTearDown`.
- `client_view_test.dart:115` closes a host channel before waiting for the client's resend; awaited now, so a
  failing close fails the test instead of racing it.
- No `docs/code-health.md` entry: every close and cancel is in the code; the two swallowed close errors
  above are old, deliberate and already commented, and are listed as suggestions below.

## Changes, file by file

- `packages/connection/lib/src/client_types.dart` — `Iterable<int>.generate` in `sameStrings`.
- `packages/connection/lib/src/host_address.dart` — same in `HostAddress.==`.
- `packages/connection/lib/src/server_game_host.dart` — same in `_samePlayers`.
- `packages/connection/lib/src/client_connection.dart` — `dropChannel`'s close is `unawaited(…)` (comment
  kept).
- `packages/connection/lib/src/host_connection.dart` — `close`'s close is `unawaited(…)`; `dart:async`
  imported for it (file 390 → 392 lines).
- `packages/connection/lib/src/host_server.dart` — closing a channel that arrives while stopping is
  `unawaited(…)` (file stays 399 lines).
- `packages/connection/lib/src/controller_client.dart` — `_open` builds the `ClientMessages` in a local and
  runs `open` unawaited (file 398 → 399 lines).
- `packages/connection/lib/src/transport/in_process_link.dart` — `_Closing` carries the `closePipes` callback
  the factory builds, and `_InProcessEnd.close` calls it (see decisions).
- `packages/connection/lib/src/transport/web_socket_connector.dart` — the `opened` copy is gone; `socket` is
  checked, closed and returned.
- `packages/connection/bin/sim_controller.dart` — the pairing-code read and the Ctrl-C handler are
  `unawaited(…)`.
- `packages/connection/test/client_view_test.dart` — the host close is awaited; `_Batches`' subscription is a
  local cancelled in `addTearDown`.
- `packages/protocol/lib/src/view_result.dart` — the three private readers take `Object?` /
  `Map<Object?, Object?>`.
- `packages/protocol/test/m9_test.dart` — explicit type arguments on the two empty literals.
- `packages/game_kit/lib/src/frame_view.dart` — both `cancel()` calls are `unawaited(…)`.

## Self-check (review-rules part A)

1. **Every host setup:** not affected — no message, frame, timing or state changed; the only runtime-visible
   edit is *which* in-process controller is closed first, and both closes land before any listener runs.
   Covered by protocol 118, connection 295 (including the in-process link tests), kit 74.
2. **When kept state starts and ends:** unchanged. The in-process link's close state, code and reason are set
   exactly as before, once, and closing either end still closes both; its tests pass.
3. **How a new state combines with the others:** not affected — no new state, no new pause/wait/flag.
4. **Stay in the job's folder:** every write is in `allow:` (the 14 files above), plus the report.
5. **Stop rather than overstep:** no file outside `allow:` was needed or touched; the brief's contract could
   be met as written.

## Questions and suggestions

1. The whole-workspace `analyze` check cannot pass until lint-3 (apps) and lint-4 (host) land; this job's
   `dart analyze packages/connection packages/protocol packages/game_kit` is clean.
2. Suggested code-health item (not added): `host_connection.close` and `client_connection.dropChannel` drop a
   close error with `.then((_) {}, onError: (_) {})` and no log line; one `LogSink` line would show a socket
   that refused to close.
3. `client_connection.dart:83` and `web_socket_connector.dart` still use `.ignore()` for a close nobody waits
   for; that is the same idea as `unawaited` and was left as it is to keep the diff to the lint's findings.

## Hand-over

The three packages are lint-clean under the strict settings; tests and format pass. The workspace `analyze`
check still fails on other packages (lint-3, lint-4), so the full `tools/check.sh` is red until those jobs
land. Nothing else is open in this job.

## Commit message

lint: clear the strict-lint issues in connection, protocol and game_kit

Type arguments on Iterable.generate and the JSON readers, and an
Object?/Map<Object?, Object?> pair of private helpers, so the strict
settings see the types the code already had. Fire-and-forget futures
are marked unawaited (or awaited in a test that needs the close), and
the in-process link and the WebSocket connector are shaped so the
analyzer can see their sinks closed. No behaviour or API change.

## Status row

- **lint-2-core done:** `dart analyze packages/connection packages/protocol packages/game_kit` is clean (27
  issues fixed, no ignores); protocol 118, connection 295, kit 74 pass. Open: the whole-workspace analyze
  still fails on the apps and host packages (lint-3, lint-4).

## Delete

- none
