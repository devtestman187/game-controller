# m12 cleanup c1 G4 — split `game_host.dart`, real waits out of the connection tests

Gate: G4, this cleanup only. No behaviour, message or public API change; nothing for step 3.

## 1. The split (a pure move)

`packages/connection/lib/src/game_host.dart` was 538 lines. It is now five files, along the map the brief gives:

| File | Lines | What it holds |
| --- | --- | --- |
| `game_host.dart` | 79 | `GameHost`, `PlayerLatency` |
| `game_types.dart` | 85 | `GamePlayer`, `LatencyStage`, `StageSample`, `GameRecord` |
| `local_player.dart` | 28 | `LocalPlayer` |
| `server_game_host.dart` | 240 | `ServerGameHost` (and its private `_samePlayers`) |
| `memory_game_host.dart` | 128 | `MemoryGameHost` |

- Only imports changed inside the moved code. No member, doc comment, constant or body is different: I copied each block verbatim and gave it the imports it needs.
- One thing moved that the map doesn't name: the private `_samePlayers(List<GamePlayer>, List<GamePlayer>)` helper. It compares player lists and only `ServerGameHost._checkPlayers` calls it, so it went to `server_game_host.dart` and stays private there. No type moved out of `game_types.dart`: all four are used by both hosts and/or the interface.
- `connection.dart` exports exactly today's names, this time with `show` lists so each file's public surface is visible:

```dart
export 'src/game_host.dart' show GameHost, PlayerLatency;
export 'src/game_types.dart' show GamePlayer, GameRecord, LatencyStage, StageSample;
export 'src/local_player.dart' show LocalPlayer;
export 'src/memory_game_host.dart' show MemoryGameHost;
export 'src/server_game_host.dart' show ServerGameHost;
```

  That is the same nine public names `export 'src/game_host.dart'` gave before; the export list is now alphabetical by path as it was. Nothing else in `lib/` or `bin/` imported `game_host.dart` directly, so no other file changed.

## 2. Waits in the connection tests

`settle()` (150 ms) is gone from `m9_test.dart` and `m10_test.dart`. Every wait below is now the event the test is about; line numbers on the left are the old file's, on the right the new one's. No test was added, removed, renamed, merged or weakened: the suite is 176 tests before and after.

| file:line (before) | old wait | now |
| --- | --- | --- |
| `m9_test.dart:22` | `Future<void> settle()` helper | deleted; the helper had no other caller |
| `m9_test.dart:59` (a phone does not send metrics) | `await settle()` then "no `MetricsMessage`" | waits for the phone's own later input, `host.messages.firstWhere(seq > pairedSeq)` (line 65): one frame arrives after the other, so the batch never left |
| `m9_test.dart:78` (batches reach, get acknowledged) | `await settle()` | `Completer` when both batches are on `host.messages` (79/91), then `hapticRoundTrip(host, client)` (94) to prove the phone took both acks before `metricsWaiting` is read |
| `m9_test.dart:93` (batches while the Wi-Fi is off) | `await settle()` | `host.messages.firstWhere(s1, index 0)` (112) |
| `m9_test.dart:103` (same test, after reconnect) | `await settle()` | `Completer` when s1/1 and s2/0 arrive (102/125), then `hapticRoundTrip` (130) for the acks |
| `m9_test.dart:125` (the host asks, the phone answers) | `await settle()` | `Completer` on the `RatingMessage` reply (140/153) — the round trip is the answer itself |
| `m9_test.dart:171` (reports stages) | `Future.delayed(Duration.zero)` | `host.stages.firstWhere(receivedToDrawn)` (187/200) |
| `m10_test.dart:16` | `settle()` helper | deleted; no other caller |
| `m10_test.dart:32` (layout and status) | `await settle()` | `client.layouts/statuses.firstWhere(not standard / not hidden)` (28/29) |
| `m10_test.dart:43` (same test, after reconnect) | `await settle()` | the same two `firstWhere`s, subscribed before the drop (38/39) so the reset-to-standard events can't race them |
| `m10_test.dart:50` (game ends) | `await settle()` | `firstWhere(isStandard)` / `firstWhere(isHidden)` (52/53) |
| `m10_test.dart:65` (an older phone gets neither) | `await settle()` | `hapticRoundTrip(server, client)` (73): a message sent after the layout/status would have gone out, before which nothing of the sort arrived |
| `m10_test.dart:89` (status at most 10 a second) | `Future.delayed(300 ms)` after the loop | `Completer` on the newest status `n29` (85/104) — the test now ends on "the newest always gets there" |
| `m10_test.dart:129` (a quick tap) | `Future.delayed(Duration.zero)` | deleted: `HostConnection._onInput` applies the input before it forwards the message, so the awaited release message already proves the snapshot |
| `m10_test.dart:134` (the tap clears) | `Future.delayed(minPressMs + 20)` | wait for two more heartbeat samples of the phone, `hostUntil(rttStats.samples >= samples + 2)` (149/150) |
| `m10_test.dart:150` (sounds by name) | `await settle()` | `await host.sounds.first` (163/167) |
| `input_test.dart:27` (input reaches the message stream) | `Future.delayed(20 ms)` | `host.messages.firstWhere(the same press)` (23/31) |
| `input_test.dart:92` (a dropped controller releases everything) | `Future.delayed(50 ms)` | `host.messages.firstWhere(neutral with seq > pressedSeq)` (94/102) — the released state `HostConnection._ended` makes up |
| `m6_test.dart:139` (input latency is logged) | `Future.delayed(700 ms)` | `Completer` on the host's `Latency Phone phone-1: ping …` log line (115/149); the `Session of Phone phone-1 ended` line is now waited for the same way (116/154) instead of being read after the snapshot change |
| `reconnect_test.dart:139` (disconnect stops retrying) | `Future.delayed(300 ms)` | a second phone pairs and gives three heartbeat samples (see below) |
| `haptic_test.dart:51` (sendToAll skips unpaired) | `Future.delayed(100 ms)` | the unpaired phone now pairs, and the test waits for it (53/54): a host-to-phone message sent after `sendToAll`, which a stray haptic would have come before |

New shared helper in `test/helpers.dart` (`hapticRoundTrip`, line 144): the host sends one haptic event and the test waits until the phone has it. Frames keep their order, so everything the host sent before it has been handled — the round trip the brief asks for, in the one direction where a test has no other reply to wait for.

### Values the new waits rest on

- `ServerGameHost.minPressMs` = 50 ms; the host pings every `hb` = 100 ms (helpers), so two samples of the phone are ≥ 100 ms apart, which is longer than the press must be held. Measured: the tap check is false after 2 samples, every run.
- A phone's `retryDelays` in tests are 50 ms then 100 ms (the last repeats), so a phone still retrying after `disconnect()` would reconnect within 100 ms; three heartbeat samples at 100 ms take ≥ 200 ms after the second phone pairs.
- `latencyLogInterval` is 300 ms and `HostConnection.latencyLine` writes `Latency $who: ping …, input delay ~ avg …` with `who` = `Phone phone-1`, so one line satisfies both existing expectations.
- The rate test's bound is unchanged: `received.length <= elapsed ~/ 100 + 2`, with `elapsed` now stopping when `n29` arrives instead of after a fixed extra 300 ms. Measured sends per run: 6 to 7 within 0.6 to 0.8 s.

## 3. Real time left in the connection tests

Two `Future.delayed` calls remain, both the *input* of their test rather than a wait for something to happen. I left them because neither can be a wait or fake time:

- `m10_test.dart:101` — `for (var i = 0; i < 30; i++) { setStatus(...); await Future.delayed(16 ms); }`. The rule under test is "at most 10 a second", so 30 statuses at ~60 a second *are* the stimulus. Fake time can't replace it: the limiter's timers run on the host while real sockets carry each status (guidelines §9 allows real sockets here, fake time only where no socket is involved). The allowed count is worked out from the loop's real time, as before.
- `m6_test.dart:130` — five `sendInput` calls 20 ms apart, so each state is its own latency sample; the following wait for `inputLatency.samples >= 5` is event-based. Sending them back to back would make five states arrive in one burst, which is a different measurement.

Claude decides whether these two stay.

## 4. Checks

- `tools/check.sh format analyze connection host phone tv` — all PASS: format (2 s), analyze (7 s), connection 176 tests (13 s), host 44 tests (66 s), phone 262 tests (22 s), tv 22 tests (17 s).
- Connection tests before this job: **176 tests, 26 s** (`tools/check.sh connection` at the start). After: **176 tests, 13 s**. A plain `dart test` in the package takes 9 s now; it also took 9 s over four repeated runs, all green, so the new waits are stable here.
- `tools/review.sh` on the diff: `review: 0 fail, 0 note`.
- `tools/review.sh --strings`: `strings: 0 removed, 0 added, 7 unchanged or moved` — a pure move, as expected. (The 7 are the literals that travelled with the code: the player label interpolations, the `local-` ID prefix, `sim`.)
- `dart format --output=none --set-exit-if-changed packages/connection`: 0 changed.

## 5. Files changed

| File | Change |
| --- | --- |
| `packages/connection/lib/src/game_host.dart` | kept `GameHost` and `PlayerLatency`; imports the new files (538 → 79 lines) |
| `packages/connection/lib/src/game_types.dart` | new: `GamePlayer`, `LatencyStage`, `StageSample`, `GameRecord` |
| `packages/connection/lib/src/local_player.dart` | new: `LocalPlayer` |
| `packages/connection/lib/src/server_game_host.dart` | new: `ServerGameHost`, `_samePlayers` |
| `packages/connection/lib/src/memory_game_host.dart` | new: `MemoryGameHost` |
| `packages/connection/lib/connection.dart` | five exports with `show` lists instead of one |
| `packages/connection/test/helpers.dart` | new `hapticRoundTrip` helper |
| `packages/connection/test/m9_test.dart` | `settle()` removed; six waits replaced |
| `packages/connection/test/m10_test.dart` | `settle()` removed; seven waits replaced, the zero-length one dropped |
| `packages/connection/test/input_test.dart` | two `Future.delayed` replaced |
| `packages/connection/test/m6_test.dart` | 700 ms wait replaced; the session-ended log is waited for |
| `packages/connection/test/reconnect_test.dart` | 300 ms wait replaced; `dart:async` import dropped (now unused) |
| `packages/connection/test/haptic_test.dart` | 100 ms wait replaced |
| `packages/connection/lib/src/game_host.tmp` | leftover of the split: the 79 kept lines copied with `head` before overwriting `game_host.dart`. `rm` is refused in this sandbox, so it is in the Delete list below. No code imports it and no check reads it, but it must not be committed. |

## 6. Things I changed beyond a like-for-like swap (please check)

1. `reconnect_test.dart`, "disconnect stops retrying": the last expectation was `expect(host.snapshot.connected, isEmpty)`. The test now pairs a second phone (`other`) to have a clock it can wait on, so it reads `expect(host.snapshot.connected.map((c) => c.controllerId), ['other'])` — the same fact (the first phone did not come back), made exact.
2. `haptic_test.dart`, "sendToAll reaches every paired phone and skips unpaired ones": the unpaired phone pairs at the end of the test so there is a host-to-phone message to wait on. `unpairedGot` is still 0 with no time passing by itself.
3. `m10_test.dart`, the sounds test: `await host.sounds.first` before `expect(sounds, ['snap'])`; no expectation added or changed.
4. `m6_test.dart`: the log sink is a small `onLog` function that completes two completers instead of `log.add`.

## 7. Questions and suggestions

1. The two `Future.delayed` stimulus loops (§3): keep them as they are, or should the rate test move to a host with a fake clock?
2. The `game_host.tmp` leftover: the Delete list has it; is an untracked file in `lib/src` acceptable in the meantime, or should a later job forbid `cp`/`head` shortcuts in the brief?
3. `game_types.dart` holds four public types, against guidelines §3's "one public type per file, unless the small related ones only make sense together". This is the brief's map, so I followed it; if Claude wants a file per type (five more files under `lib/src`), that's a different map.
4. Suggestion for a later job: `MemoryGameHost` and `ServerGameHost` still share nothing but the interface, so `game_host.dart` could import neither of them — it doesn't; only `connection.dart` needs the two. Worth an `export` comment? Not done: no change wanted here.

## Commit message

```
Split connection's game_host.dart and drop real waits from its tests

The 538-line game_host.dart is now five files along the given map: the
GameHost interface and PlayerLatency stay in game_host.dart, the shared
types move to game_types.dart, and LocalPlayer, ServerGameHost (with the
private _samePlayers) and MemoryGameHost get a file each. Pure move:
imports only, and connection.dart exports the same nine names, now with
show lists.

The connection tests no longer sleep: settle() is gone and every wait is
the stream event, completer or round trip the test is about. Two
Future.delayed loops remain, as the input of two tests rather than waits.
```

## Status row

| Cleanup c1 | **Done**: `game_host.dart` split into five files (79/85/28/128/240 lines), `connection.dart` exports the same nine names, and the connection tests wait on events instead of time — 176 tests still pass, 26 s → 13 s. Open: c2 and c3 (the phone app's `providers.dart`/`widget_test.dart`, and the long members, `puzzle` `Random`, leftovers), plus Claude's call on the two `Future.delayed` stimulus loops left in `m10_test.dart` and `m6_test.dart`. |

## Delete

- packages/connection/lib/src/game_host.tmp
