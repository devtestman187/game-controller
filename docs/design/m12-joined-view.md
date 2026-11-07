# M12 step 6 contract: the joined view

Refines m12.md §2.3 (sounds), §2.4, §2.5 (local echo), §2.9 and §2.10 for step 6, and wins where they differ. From the G0 survey ([s6-g0-survey.md](../briefs/m12/s6-g0-survey.md)); Claude's answers to its questions are §0.

## 0. Decisions on the survey's questions (Nov 7, 2026)

1. **Who gets frames: the host decides.** Every phone lists `view` (it can show a game). The host sends views only when its screen isn't the one everyone watches: `ServerGameHost.shareView` (default true, so the connection tests keep their meaning); `HostService` takes `shareView` (default **false**: the TV app never sends frames) and the phone host sets it true for "Play on this phone" and false for "Show on this device". A change applies from the next `view_start`. The host phone's own player doesn't list `view` (the phone app takes it out of the identity it pairs with), so it never gets frames: the host phone draws the game itself. (s6a: a server rule on `isLocal` would also have caught the connection tests' in-process viewers, so the app decides instead.) The dev TV app turns it on with a debug-only define `SHARE_VIEW` (like `FRAME_RATE_HZ`), which `tools/tv-dev.sh start` always passes, so the smoke `frames` step and the PC measurement keep working.
   - Known gap, accepted: a TV app from build 1 (m12.1) sends frames to any phone that lists `view`, so a newer phone joined to that TV would show the game over its controls. Both apps update together from the next build.
2. **Sounds: `FrameView` reports them, the phone app plays them.** `FrameView` gains `onSounds(List<String> names)`. Each frame's sounds are reported once, when the render time first reaches its `at`. Frames passed over in one tick report theirs in step order. A frame whose `n` is at or below the last reported one doesn't report again. The count resets on `ViewStarted`; a rejoin may replay one frame's sounds, which is accepted. The phone plays them through `party.soundPlayerProvider`, and restarts that player when the app is shown again (as the host route does since s5c).
3. **Waiting for host: the host says so when it can, and the phone notices when it can't.**
   - Wire: `host_away` `{s}` (int, seconds left before the round ends) and `host_back` `{}`, host → viewer, behind `view`, sent only while a view is running and only to viewers that get views (rule 1). `GameHost.hostAway(int? secondsLeft)`: a number sends `host_away`, null sends `host_back`. `HostPresence.hidden()` calls it with `graceS`; `shown()` calls it with null after `resume()` when the round isn't abandoned (an abandoned round sends `view_end` `abandoned` as today).
   - Phone: "Waiting for the host" shows while (a) a `host_away` came and no `host_back`, `view_start` or `view_end` since, or (b) a view is running and the client isn't connected (an iOS host that's suspended can't send anything, and the heartbeat drops). Countdown: from `s` at arrival for (a); from `hostGraceS` (30) at the moment the link dropped for (b). At 0 it keeps the text without a number.
   - A pause menu stops frames but not the heartbeat, so it never shows the waiting card.
4. **`LocalEcho` stays a hook shape, not API.** Nothing is added to `GameModule` until the measurement asks for it (m12.md §2.5). `FrameView` keeps one private seam: the snapshot it draws goes through one method (`_toDraw(GameSnapshot lerped)`, returning it unchanged), where an echo would apply.
5. **While waiting, the joined phone's controls keep working** (inputs reach a paused host and are ignored, as on a TV). A view that ends `abandoned` shows "The host was away too long, so the round ended." for 4 s over the controls, then controller mode as today. Other reasons show nothing.
6. **Host list labels (C26).** `DiscoveredHost` gains `kind` (`HostKind?`, null for hosts without the TXT key). Icon per kind: `tv` → `Icons.tv`, `pc` → `Icons.computer`, `phone` → `Icons.smartphone`, `tablet` → `Icons.tablet`, none → `Icons.tv` (as today). The subtitle starts with the kind's word ("Phone", "Tablet", "TV", "PC"; nothing when null). The heading "TVs on this Wi-Fi" becomes "Games on this Wi-Fi".

## 1. Protocol (`packages/protocol`, `view.dart`)
`HostAwayMessage` (`host_away`, `s` int ≥ 0) and `HostBackMessage` (`host_back`), both mapped to `Capability.view`. Protocol version stays 1. `docs/protocol.md` gets both rows.

## 2. Connection
- `ViewEvent` gains `HostAway(int secondsLeft, int arrivedAtMs)` and `HostBack()`. Every exhaustive switch over `ViewEvent` handles them (`FrameView` ignores both; `sim_view` logs them).
- `GameHost.hostAway(int? secondsLeft)`; `ServerGameHost` sends to the viewers of rule 1, nothing when no view is running; `MemoryGameHost` records the calls (`hostAways`).
- `ServerGameHost.shareView` (get/set, default true). False: `hasViewers` is false, no `view_start`, frame, `view_end` or `host_away` goes out.
- `ViewerStats.summary`: a `ViewSummary` per frame rate since the stats were made (not reset by `reset`): `touch_to_frame` and `frame_jitter` median and p95 over the last 2000 samples each, and `frames`, `late`, `gaps` totals. `drain` (the metrics batches) is unchanged. `controller_client.dart` is at 398 of 400 lines: any line it needs means splitting it first.

## 3. game_kit
- `FrameView` gains `onSounds` (§0.2) and the `_toDraw` seam (§0.4). Nothing else in its behaviour changes; its 9 tests keep their expected values.

## 4. party_host
- `HostService`: `shareView` (constructor, default false; get/set) passed to its `ServerGameHost`; the game host reachable for `HostPresence`.
- `HostPresence`: `hidden()` → `hostAway(graceS)`; `shown()` → `hostAway(null)` after `resume()` unless abandoned.

## 5. The phone app (controller_app)
- `pubspec.yaml`: `game_kit`, `puzzle_game`, `test_game` (they come through `party_host` today but aren't direct).
- `storage.dart`: the identity lists `view`.
- `gameRegistryProvider`: `GameRegistry([shapeRaceModule, arenaModule])`.
- `viewActiveProvider`: true from a `ViewStarted` on `clientProvider`'s `view` stream until a `ViewEnded` or the client changes. `showsGameProvider` = `gameShownProvider` (the host route's) || `viewActiveProvider`. The opacity and the status panel read `showsGameProvider`.
- `JoinedView` (`ui/joined_view.dart`): `FrameView` with the client's `view`, `viewerStats`, `nowMs`, the identity's `controllerId` as `playerId`, the registry and `onSounds` → the sound player; the waiting card (§0.3) over it; the restart of the sound player on app show. `ControllerScreen` gets it as `background` whenever no other background is given (the joined phone's home); the host route keeps passing `HostGames`.
- A shown game (the joined view and the host route's `HostGames`) fills the whole safe area behind the top bar; the top bar draws over it with a transparent background while a game is shown ([m12-phone-layout.md](m12-phone-layout.md) §0.7). The controls and their touch metrics keep the body box below the bar.
- The abandoned notice (§0.5).
- Host list labels (§0.6): `discovery.dart` reads `kind`; `connect_screen.dart` shows icon, word and the new heading.
- The phone host sets `service.shareView` from the start sheet's choice (§0.1).
- Diagnostics: the report adds a "Game view" section from `viewerStats.summary`: one line per frame rate with touch-to-frame median/p95 (and the sample count), jitter median/p95, frames, late, gaps. Absent when nothing was viewed. (This is how the owner sends Claude the phone measurement.)
- Test support: `FakeClient` gains a `view` stream controller and a real `ViewerStats`.

## 6. Measurement (the exit check)
Two phones on one Wi-Fi: one hosts "Play on this phone" (Shape Race, then the Arena, 2 minutes each), the other joins and plays. The owner pastes the joined phone's Diagnostics. The touch-to-frame median should be under 50 ms; over it, Claude brings the numbers and a recommendation (frame rate, or local echo), and the owner decides. Before that, Claude runs the emulator check on this PC: the dev TV app hosts with `SHARE_VIEW`, the emulator's phone app joins and shows the game (screenshot).

## 7. Jobs and gates
| Job | What | Gates |
| --- | --- | --- |
| s6a | §1–§4 and the dev define (protocol, connection, game_kit, party_host, tv_test_app debug start, tv-dev.sh) | G4 (each part is small; the brief lists every test) |
| s6b | §5 | G3: the dependencies, `view`, the registry, `viewActiveProvider`, `JoinedView` with a fake client's events, `showsGameProvider` → G4: waiting card, abandoned notice, labels, shareView from the start sheet, diagnostics |
