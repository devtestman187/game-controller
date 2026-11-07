# m12 cleanup c1b G4 — the connection tests' "nothing was sent" checks look at the wire

Gate: G4, these test fixes only. No change in `packages/connection/lib`.

## 1. What was wrong

Both checks were made on a real `ControllerClient`, and the client drops what it can't use, so the check passed whether or not the host sent anything:

- `haptic_test.dart:55` — a haptic to a phone that isn't paired is dropped by the client (`client_messages.dart:49`), so `unpairedGot` was 0 even if a haptic had been sent. Only the `sendToAll(...) == 2` count was real.
- `m10_test.dart:73` — a client without the layout/status capabilities ignores both (`client_messages.dart:62,65`), so `client.layout.isStandard` held even if the host had sent a layout; the haptic round trip there proved only that the channel was alive.

The rule in both tests is the host's ("don't send X to a phone that can't use it"). Both now watch the host's own frames.

## 2. The changes, by item

New test helper `test/wire_phone.dart` (77 lines, one type, the same shape as `test/fake_host.dart`): a phone the test speaks for itself over `rawPeer`. It says hello (with the capabilities the test gives), waits for the host's welcome, optionally pairs with the code and waits for the accepted `PairResultMessage`, keeps every message the host sent it in `fromHost`, and `drain()` sends a ping and waits for the host's pong. Frames keep their order on both transports (TCP and the in-process link's per-direction `StreamController`s), so after a reply everything the host sent before it is in `fromHost`, and what it never sent will not come.

1. **`haptic_test.dart`, "sendToAll reaches every paired phone and skips unpaired ones"** (line 33): the unpaired `ControllerClient` is now `WirePhone.open(host, t, controllerId: 'c')`, a peer that says hello and never pairs, so the host has its session (the welcome proves it). `expect(host.sendToAll(...), 2)` stays. After the two paired phones got their haptic, `await unpaired.drain()` and `expect(unpaired.fromHost.whereType<HapticEventMessage>(), isEmpty)`.

2. **`m10_test.dart`, "an older phone gets neither"** (line 63): the metrics-only `ControllerClient` is now `WirePhone.open(... capabilities: const [Capability.metrics], code: server.pairingCode)`, so it is *paired* — the only thing that can stop a layout or status is the host's capability check, which is the rule under test. `host.setLayout` / `host.setStatus`, then `await older.drain()`, then no `GameLayoutMessage` and no `StatusMessage` in `fromHost`. `expect(server.snapshot.connected, hasLength(1), reason: 'still connected')` stays. The `hostUntil(server, (h) => h.connected.isNotEmpty)` line is gone: the accepted pair result is the same fact, learnt earlier and from the host itself. The old client-side `client.layout.isStandard` / `client.status.isHidden` checks are gone with the client; the client's own reset-on-drop behaviour is what the first m10 test covers (`m10_test.dart:20`).

3. **Timeouts** on the c1 waits that had none, all `.timeout(const Duration(seconds: 5))` like the others: `m9_test.dart:65`, `m9_test.dart:114`; `m10_test.dart:29`, `:30`, `:39`, `:40`, `:53`, `:54`, `:177`. I also gave the quick-tap `firstWhere` (`m10_test.dart:142`, awaited at `m10_test.dart:156`) the same timeout: it is the one other c1 wait without one, and item 3 names the rule ("every new firstWhere/first wait from c1 without a timeout"), with the parenthetical list as the pointer to them.

4. **`m10_test.dart:150`, "two samples"**: the wait is now the host's own measure of the 50 ms window, not two heartbeats. The test keeps the press's arrival time as the host recorded it — the `receivedAtMs` of the `ControllerMessage` that carries the press, the same value `ServerGameHost._notePresses` files the press under — and then waits for

   ```dart
   await hostUntil(server, (_) => server.nowMs - pressMs >= ServerGameHost.minPressMs);
   ```

   `ServerGameHost.gamepad` clears a press with exactly `now - at >= minPressMs` (`server_game_host.dart:145`), so the expectation is exact, not a margin. The heartbeat only wakes the wait (a snapshot comes with every pong, ~100 ms); it is no longer the measure. Two pongs arriving together can't let the check run early, and a slower heartbeat couldn't hold the press longer than the rule says.

5. **How each fixed test fails if the rule breaks** (worked out, not tried — no `lib/` change):

   - Haptic: with `sendToAll`'s `s.paired` filter gone (`host_server.dart:197`), it counts the raw peer too, so `expect(host.sendToAll(...), 2)` fails first with 3; and the `HapticEventMessage` frame reaches the peer before the pong, so the `isEmpty` expectation fails too. Note the test now passes for a defensible reason if only the *client's* drop rule (`client_messages.dart:49`) were removed — that is not this test's rule.
   - m10 "an older phone gets neither": with the capability check gone (`host_server.dart:224` `_accepts`, or `capabilityFor` returning null for layout/status), `ServerGameHost.setLayout`/`setStatus` (`server_game_host.dart:81,95`) write both frames to the paired peer before the ping goes out, so the two `fromHost.whereType<...>(), isEmpty` expectations fail. A refused pairing fails earlier, loudly: `WirePhone.open` throws `StateError('phone-1 was not paired: …')`.
   - Quick tap: if `minPressMs` were ignored (`gamepad` never clearing the press), the last `pressed(GamepadButton.a), isFalse` fails once the host clock has passed 50 ms; if the press were held longer than 50 ms, the same expectation fails at the first instant the rule says it is released (the wait is now synchronous with the rule, so it can't run late either).
   - The m9 additions don't test a rule; they turn a 30 s test timeout into a 5 s one with a message.

## 3. Computed values the waits rest on

- `ServerGameHost.minPressMs` = 50 ms; `server.nowMs` is the `Stopwatch` the host was made with, and `ControllerMessage.receivedAtMs` is that clock at `_onInput` — so `pressMs + 50` is the first millisecond the press may be gone.
- `hb` = 100 ms in `helpers.dart`, so a snapshot (pong) arrives about every 100 ms; the quick-tap wait therefore returns 0–100 ms after the window closes and the test grows by at most ~0.1 s.
- The raw peers don't answer the host's pings, so the host drops them after `heartbeatTimeout` = 1500 ms. Both round trips happen within a few ms of pairing, and a peer dropped early makes `drain()` time out (5 s, clear failure) rather than let a check pass on a closed channel — the round trip is also a liveness check.
- Test counts per changed file, unchanged: haptic 4, m10 6, m9 14 declarations; whole package 176 tests before and after.

## 4. Checks

- `tools/check.sh format analyze connection` → PASS format (2 s), PASS analyze (6–9 s, whole workspace), PASS connection (176 tests, 12 s), twice. All checks passed.
- `dart analyze` in `packages/connection` → "No issues found!".
- `dart format --output=none --set-exit-if-changed packages/connection/test` → 12 files, 0 changed.
- `dart test` in `packages/connection` → 176 tests, all pass, 7–9 s.
- `dart test test/haptic_test.dart test/m10_test.dart` four times → 19 tests, all pass each time (the two rewritten tests are stable here).
- `tools/review.sh` (the uncommitted tree) → `review: 0 fail, 2 note`; both NOTES are elsewhere (`controller_app/lib/src/providers/device.dart:24`, `metrics.dart:32`), none on these lines.
- No `Future.delayed` added; no test added, removed, renamed or merged.

## 5. Files changed

| File | Change |
| --- | --- |
| `packages/connection/test/wire_phone.dart` | new: `WirePhone`, a phone the test drives on a raw channel (hello, optional pairing, `fromHost`, `drain()`) |
| `packages/connection/test/haptic_test.dart` | the unpaired phone is a `WirePhone`; the check reads the host's frames after a ping/pong round trip; imports it |
| `packages/connection/test/m10_test.dart` | "an older phone" is a paired `WirePhone` with metrics only; layout/status checked on the wire; quick-tap wait tied to the host's `minPressMs` clock; seven 5 s timeouts |
| `packages/connection/test/m9_test.dart` | two 5 s timeouts on the c1 `firstWhere` waits |

## 6. Questions and suggestions

1. Item 3's parenthetical list didn't include the quick-tap `firstWhere` (`m10_test.dart:142`); I treated it as part of "every new firstWhere/first wait from c1 without a timeout" and gave it the same 5 s. Say if that one should stay as it was.
2. `WirePhone` is a new file, not an addition to `helpers.dart`, following `fake_host.dart` (one test type per file). Moving it into `helpers.dart` is easy if you'd rather have no new file.
3. In "an older phone gets neither" I dropped the `hostUntil(server, (h) => h.connected.isNotEmpty)` line: `WirePhone.open` waits for the accepted pair result, which the host sends after marking the phone paired, so the wait is already stronger. Same for `clientStatus(client, ClientStatus.connected)`, which the pair result replaces.
4. Not done, for a later job: the same wire check would fit "a host never sends a message the controller did not list" (`m9_test.dart:37`), which still checks `host.send(...)` return values only.

## Commit message

```
Make the "nothing was sent" connection checks read the wire

haptic_test's unpaired phone and m10_test's phone without the layout and
status capabilities were real clients, and a client drops what it can't
use, so both checks passed whether or not the host sent anything. Both
place a WirePhone (a raw peer that says hello, pairs when asked and keeps
every frame the host sends it) in that phone's place, then drain the
channel with a ping and its pong: a haptic, layout or status frame would
be in the list by then.

The c1 waits without a timeout get the usual 5 s, and the quick tap's
wait now follows the host's own 50 ms minPressMs clock instead of two
100 ms heartbeats. No test added, removed or renamed; 176 still pass.
```

## Status row

| Cleanup c1b | **Done**: the connection tests' two "nothing was sent" checks now read the host's frames through a raw peer (`test/wire_phone.dart`) followed by a ping/pong round trip, the quick-tap wait uses the host's `minPressMs` clock, and every c1 wait has a 5 s timeout — 176 connection tests still pass. Open: c2 and c3 (the phone app's `providers.dart`/`widget_test.dart`, and the long members, `puzzle` `Random`, leftovers), plus Claude's call on the two `Future.delayed` stimulus loops left in `m10_test.dart` and `m6_test.dart`. |

## Delete

- none
