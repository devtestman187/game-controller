# M12 step 6a — G4 report: `host_away`/`host_back`, `shareView`, sounds out of `FrameView`, the viewer summary, the dev `SHARE_VIEW` define

Job: [s6a.md](s6a.md). Contract: [../../design/m12-joined-view.md](../../design/m12-joined-view.md) §0.1–§0.4, §1–§4.

**Stopped** at one sentence of item 2 (below). Everything else in the brief is in and every check is green: 929
tests, `dart format` clean, `dart analyze` no issues, `tools/review.sh` 0 fail. Please read the first section first:
the one rule I left out is a conflict inside the brief, not something I ran out of time for.

## Why I stopped: the local-channel rule contradicts `view_test.dart` and the brief's own test list

The brief says (item 2, last sentence): *"Channels with `isLocal` never count as viewers and never get a view
message, whatever `shareView` is."* And (tests): *"a local (in-process) viewer gets no view_start, frame or
host_away while a WebSocket viewer does"*.

What `isLocal` is in the code:

- `ControllerInfo.isLocal` is set from the connection: `host_connection.dart:182` `isLocal: _channel.isLocal` →
  `host_pairings.dart:38` `isLocal: remoteAddress == null`.
- `_InProcessEnd.isLocal => true` (`transport/in_process_link.dart:56`), and an in-process channel has no remote
  address: every in-process channel is local, by definition and as [transport.md](../m12-transport.md) and
  [architecture.md](../../architecture.md) say. There is no second notion of "local" to use instead.

The connection tests' `inProcess` transport *is* that channel (`test/helpers.dart` `startHost`/`newClient`, and
`WirePhone` over `InProcessListener`). So the rule as written changes eight existing tests in
`packages/connection/test/view_test.dart`, all of them in the `inProcess` group:

| `view_test.dart` test | expected today | with the rule |
| --- | --- | --- |
| a controller that did not list view gets none of the view messages | `hasLength(3)` for the viewer | 0 — the `reason: 'the view was really on'` fails first |
| a controller that listed view gets the start, the frames and the end | `['view_start','frame','frame','view_end']` | `[]` |
| hasViewers counts only a paired controller that listed view | `isTrue` | `isFalse` |
| a viewer that pairs mid-view gets the start and the latest frame | 2 messages | 0 |
| a viewer that pairs after the view ended gets nothing | 3 for the early viewer | 0 |
| publishFrame sends nothing before the view starts or after it ended | `[1]` | `[]` |
| a viewer that drops and reconnects mid-view gets the start and the latest frame again | 2 | 0 |
| the client emits the start, the frames with their arrival time, and the end | 2 `ViewFrame`s | 0 |

and the brief also asks for "any existing test whose expected value changed (old → new; there should be none)".

The brief's test list contradicts itself on the same point: *"connection (both transports, like view_test): during a
view, `hostAway(30)` reaches a viewer …"* runs over `inProcess` too, where that viewer is local and would get
nothing. The design's §0.1 means the host phone's own player (the only in-process controller in the apps), but
`ServerGameHost` cannot tell that player from a test's in-process phone.

Per the coding guidelines ("if a rule contradicts the code, stop and report it"), I implemented `shareView` and left
the local rule out. The two ways forward are in Questions 1 and 2; neither is something I should pick alone. I also
took back out the plumbing it would have needed (`HostConnection.isLocal`, `HostServer.sendToAll(toLocal:)`), so
nothing dead is left behind.

## Files changed, with line counts

| File | Lines | What changed |
| --- | --- | --- |
| `packages/protocol/lib/src/view.dart` | 193 → 237 | `HostAwayMessage` (`host_away`, `s` int, `FormatException` for a missing, negative or non-int `s`) and `HostBackMessage` (`host_back`, no fields) |
| `packages/protocol/lib/src/codec.dart` | 72 → 74 | the two decoders |
| `packages/protocol/test/view_test.dart` | 335 → 364 | 2 tests: round trip and wire `s`; `s` missing/negative/string throws, `s: 0` and `s: 30` pass |
| `docs/protocol.md` | 273 → 275 | `host_away` and `host_back` rows in the view table; "the three messages below" → "the messages below" (the table now has five) |
| `packages/connection/lib/src/host_server.dart` | 379 → 383 ⚑ | `capabilityFor`: both messages → `Capability.view` |
| `packages/connection/lib/src/host_connection.dart` | 394 → 396 ⚑ | both messages added to the "Unexpected from a phone" close case (a non-exhaustive switch otherwise) |
| `packages/connection/lib/src/game_host.dart` | 100 → 107 | `void hostAway(int? secondsLeft)`, with the contract's doc |
| `packages/connection/lib/src/server_game_host.dart` | 297 → 317 ⚑ | `shareView` (default true) gating `hasViewers`, `startView`, `publishFrame`, `endView`; `hostAway` |
| `packages/connection/lib/src/memory_game_host.dart` | 152 → 158 | `hostAways` (`List<int?>`) |
| `packages/connection/lib/src/client_controls.dart` | 131 → 161 | `HostAway(secondsLeft, arrivedAtMs)`, `HostBack()`, `addHostAway`/`addHostBack` |
| `packages/connection/lib/src/client_messages.dart` | 182 → 188 | both messages → the `view` stream, dropped without `view` like the others |
| `packages/connection/lib/src/viewer_timing.dart` | 154 → 158 | `PlayoutBuffer.frames` (the frames it holds, oldest first) so sounds can be read before `pick` drops them |
| `packages/connection/lib/src/viewer_stats.dart` | 149 → 260 | `ViewSummary` + `SampleSummary`, `summary`, the per-hz `_Totals`, one `_quantile` shared by both summaries |
| `packages/connection/lib/connection.dart` | 36 → 36 | exports `HostAway`, `HostBack` |
| `packages/connection/bin/sim_view.dart` | 141 → 145 | `host_away s=<n>` / `host_back` lines |
| `packages/connection/test/host_away_test.dart` | new, 162 | 10 tests (below) |
| `packages/connection/test/viewer_stats_test.dart` | 137 → 230 | 6 tests on `summary` |
| `packages/game_kit/lib/src/frame_view.dart` | 218 → 268 | `onSounds`, `_soundsReportedN`, `_reportSounds`, `_toDraw` |
| `packages/game_kit/test/frame_view_test.dart` | 264 → 324 | 1 test for the sounds; the 9 existing ones keep their values |
| `packages/party_host/lib/src/host_service.dart` | 329 → 345 | `HostService.shareView` get/set; `LiveHostService(shareView: false)` → its `ServerGameHost` |
| `packages/party_host/lib/src/host_presence.dart` | 98 → 108 | `hidden()` → `hostAway(graceS)`; `shown()` → `hostAway(null)` after `resume()`, else `onAbandon()` |
| `packages/party_host/lib/src/providers.dart` | 280 → 287 | `shareViewProvider` (false) → `LiveHostService` |
| `packages/party_host/lib/src/testing/host_fakes.dart` | 318 → 328 ⚑ | `FakeHostService.shareView`, `FakeGameHost.hostAways` |
| `packages/party_host/test/host_presence_test.dart` | 110 → 135 | 2 tests (away/back, abandon) |
| `packages/party_host/test/live_host_service_test.dart` | 139 → 153 | 1 test: `shareView` off by default, what the service sets reaches its game host |
| `tv_test_app/lib/src/debug_start.dart` | 60 → 71 | `shareViewDefine` (`bool.fromEnvironment('SHARE_VIEW')`) and `shareViewEnabled({debug, defined})` |
| `tv_test_app/lib/main.dart` | 55 → 59 | `shareViewProvider.overrideWithValue(shareViewEnabled())` |
| `tv_test_app/test/debug_start_test.dart` | 56 → 64 | 1 test: true / false / absent / release, next to the other defines |
| `tools/tv-dev.sh` | 134 → 137 | `start` always passes `--dart-define=SHARE_VIEW=true`; the help says so |

⚑ over 300, all under the 400 limit. `host_service.dart` is 345, under the brief's 360. No `pubspec.yaml` changed,
so no `flutter pub get` was needed and `pubspec.lock` is untouched; `controller_client.dart` needed no line and is
untouched at 398.

## What each piece does

- **`shareView`** (item 2). A false setting keeps no `view_start`, so no frame, no end and no away message can follow
  it and a viewer that pairs later gets nothing; `hasViewers` is false. A change takes effect at the next
  `startView`, and a view already running finishes as it began. `endView` sends a `view_end` only if a view was
  running, so a not-shared view sends no end either.
- **`hostAway`** (item 2). Sends only while a kept `view_start` exists; the number goes out as `host_away` and null
  as `host_back`. Only paired controllers that listed `view` can take them, because `capabilityFor` maps both to
  `Capability.view`.
- **`ViewerStats.summary`** (item 3). One entry per `hz` the stats have measured under, kept since construction:
  `frameArrived`/`frameDrawn` add to the per-hz totals as well as to the batch counters, and `reset`/`drain` leave
  the totals alone. Each stage keeps its last 2000 samples (a `ListQueue` that drops the oldest); `touchToFrame` and
  `jitter` report `(count, medianMs, p95Ms)` through the same nearest-rank rule as the metrics report's
  `DelayStats.quantile`, index `(q × (n − 1)).round()`, now one private `_quantile` in this file. `frames`, `late`,
  `gaps` are totals over the whole life of the stats. `drain` is untouched.
- **`FrameView.onSounds`** (item 5). Each tick, before `pick` drops the frames the render time has passed,
  `_reportSounds` walks `PlayoutBuffer.frames` in order and reports every frame with `n` above `_soundsReportedN`
  and `at` at or below the render time, with its non-empty `sounds`; `_soundsReportedN` moves up to that frame's `n`
  even when it has no sounds, so a frame is reported once. `_start` sets it back to null when the start is one this
  app can show. A frame that arrives late, below the last reported step, is not reported again.
- **`_toDraw`** (item 5). The lerped snapshot goes through `GameSnapshot _toDraw(GameSnapshot s) => s` before
  `viewer.build`; its doc says a `LocalEcho` would apply there (m12 §2.5) and that it isn't built.
- **party_host** (item 6). `HostPresence.hidden()` tells the game host `hostAway(graceS)` before anything else, so
  the phones can say "waiting for the host"; `shown()` calls `hostAway(null)` after `await host.resume()`, only when
  the round isn't abandoned — an abandoned round sends nothing back.
- **tv_test_app** (item 7). `shareViewDefine` reads `SHARE_VIEW` the way `FRAME_RATE_HZ` reads its define in
  `hosting_settings.dart`; `shareViewEnabled()` is `debug && defined`, so a release build ignores it. `main.dart`
  overrides `shareViewProvider` with it. With the define absent nothing shares, but no app lists `Capability.view`
  yet, so the TV's behaviour is unchanged either way.

**How `HostPresence` reaches the game host:** it already held the `HostService` (for `resume()`), and
`HostService.gameHost` is the public getter it already had, typed `GameHost`. `hostAway` is now a member of that
interface, so `host.gameHost.hostAway(...)` needed nothing new: no cast, no new parameter, no wider type. The
narrowest handle that already existed was enough, so I exposed nothing.

## Tests

Per check, before → after (same commands as `tools/check.sh`):

| Check | Before | After |
| --- | --- | --- |
| protocol | 102 | **104** |
| connection | 234 | **250** |
| metrics | 45 | 45 |
| kit | 30 | **31** |
| arena | 40 | 40 |
| puzzle | 80 | 80 |
| host | 57 | **60** |
| phone | 291 | 291 |
| tv | 27 | **28** |
| total | 906 | **929** |

New tests: protocol 2; `host_away_test.dart` 10 (capability, then per transport: `HostAway(30)`/`HostBack` on the
client's stream, nothing before a start, a non-viewer gets nothing while a viewer gets the whole view with the away
messages, `shareView` false then true from the next start; plus the memory host); `viewer_stats_test.dart` 6 (60/30
Hz apart, reset and drain keep it, median/p95 on `[10,20,30,40,100]` → 30 and 100, median 300/p95 400, only the last
2000 of 2001, late/gaps totals); `frame_view_test` 1; `host_presence_test` 2; `live_host_service_test` 1;
`debug_start_test` 1.

**Existing test whose expected value changed: none.** Every new test lives in a new group or a new file; the 9
existing `FrameView` tests, `view_test.dart` (417 lines, untouched) and the other suites pass as they were.

Checks run: `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets` (0 changed),
`dart analyze` (no issues), `dart test` in `packages/protocol` and `packages/metrics`, `flutter test` in
`game_kit`, `test_game`, `puzzle_game`, `party_host`, `controller_app`, `tv_test_app`; `tools/review.sh`
(0 fail, 7 notes: the 5 size notes over 300 plus the pre-existing `onData` and `logProvider`). I could not run
`tools/check.sh`/`tools/review.sh` through the sandbox's approval gate in one go, so I ran the same commands one by
one; `tools/review.sh` ran with the override.

## Notes

1. **The `FrameView` test sends a `view_end` before the second `view_start`.** `_start` calls `_ticker.start()` on a
   ticker that is still running when a second start arrives without an end, which asserts ("a ticker was started
   twice"). No existing test does that and no app sends one, so I left `_start` alone and the test ends the view
   first; a one-line `if (!_ticker.isActive)` would make it tolerant if you want that.
2. **`docs/briefs/m12/STATUS.md` is modified in the worktree and isn't mine** (it says "G0 survey running"); I didn't
   touch it.
3. `protocol.md`'s sentence "The three messages below need the capability" had to become "the messages below" —
   otherwise it contradicts the table, which now has five rows.
4. `sim_view` prints the away lines after `view_end` handling; nothing else in it changed.

## Questions

1. **The local-channel rule (the stop).** Which do you want: (a) keep the rule and change the eight `inProcess`
   expectations in `view_test.dart` (old → new in the table above), or (b) keep the rule but not for in-process
   *test* peers — e.g. `ServerGameHost` learns the host's own player id and skips only that controller, with
   `LiveHostService` passing it? (b) leaves `view_test.dart` as it is and still keeps the host phone's own player
   quiet, but it is new API the brief doesn't name.
2. **`shareView` and the dev TV.** With the define absent the dev TV shares nothing, so the `frames` step of the
   smoke check and a PC measurement would see no frames unless it is started through `tools/tv-dev.sh`. That matches
   the brief (the script always passes it), just flagging it.

## Commit message

m12 s6a G4: host_away/host_back, shareView, sounds out of FrameView, the viewer summary

- protocol: HostAwayMessage (`host_away`, `s` >= 0) and HostBackMessage, both under Capability.view; protocol.md
  documents both in the view table.
- connection: ViewEvent gains HostAway(secondsLeft, arrivedAtMs) and HostBack; GameHost.hostAway sends both only
  while a view runs; ServerGameHost.shareView (default true) gates hasViewers and every view message, from the next
  startView; MemoryGameHost records the calls.
- connection: ViewerStats.summary by hz since construction (2000-sample median/p95 per stage, frames/late/gaps
  totals), not cleared by reset or drain; PlayoutBuffer exposes the frames it holds.
- game_kit: FrameView reports each frame's sounds once, in step order, before the frames are dropped, and resets on
  a start it can show; the lerped snapshot goes through a `_toDraw` seam for a future LocalEcho.
- party_host: HostService.shareView; HostPresence tells the game host hostAway(graceS) when hidden and
  hostAway(null) after resume when the round is not abandoned.
- tv_test_app: the debug SHARE_VIEW define sets shareView; tools/tv-dev.sh start always passes it.
- 23 new tests (906 -> 929); no existing expected value changed.

## Status row

| 6 Joined view | **s6a stopped at one rule** (G4): `host_away`/`host_back` in protocol and the client, `GameHost.hostAway`, `ServerGameHost.shareView`, `ViewerStats.summary`, `FrameView.onSounds` + the `_toDraw` seam, `HostService.shareView` and `HostPresence`'s away calls, the debug `SHARE_VIEW` define and `tv-dev.sh` — 906 → 929 tests, nothing existing changed. Not in: the local-channel rule ("channels with `isLocal` never get a view message, whatever `shareView` is"), because it flips eight existing `view_test.dart` in-process expectations and the brief also says no existing expectation may change; Claude's answer needed (s6a-report.md, Questions 1–2) |

## Delete

- none
