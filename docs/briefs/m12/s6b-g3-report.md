# M12 step 6b — G3 report: the joined view on the phone, first slice

Job: [s6b-g3.md](s6b-g3.md). Contract: [../../design/m12-joined-view.md](../../design/m12-joined-view.md) §0, §5;
[../m12-phone-layout.md](../m12-phone-layout.md) §0.7.

**Done at G3**: every phone lists `view` and the host's own player doesn't; a phone a host shows a game draws it
behind its own controls, and the game fills the safe area behind the bar. `tools/check.sh format analyze phone` PASS
(phone 291 → 297 tests), `tools/review.sh` 0 fail (1 note). Nothing from the G4 list is in.

## Files changed, with line counts

| File | Lines | What changed |
| --- | --- | --- |
| `controller_app/pubspec.yaml` | 38 → 44 | `game_kit`, `puzzle_game`, `test_game` as direct path dependencies (1) |
| `controller_app/lib/src/storage.dart` | 107 → 109 | `loadIdentity` lists `Capability.view`, with the note that `host/hosting.dart` takes it back out (2) |
| `controller_app/lib/src/host/hosting.dart` | 74 → 88 | `_inputs` pairs the own player with `ownPlayerIdentity(ref.read(identityProvider))`, and `ownPlayerIdentity` itself (the identity minus `view`) (2) |
| `controller_app/lib/src/providers/view.dart` | new, 42 | `gameRegistryProvider` (`shapeRaceModule`, `arenaModule`) and `viewActiveProvider` (3, 4) |
| `controller_app/lib/src/providers.dart` | 40 → 41 | exports `providers/view.dart` |
| `controller_app/lib/src/providers/game_feedback.dart` | 96 → 102 | `showsGameProvider`; `gameShownProvider` now documents itself as the host route's half (4) |
| `controller_app/lib/src/ui/joined_view.dart` | new, 48 | `JoinedView`: the client's frames in a `FrameView`, sounds through the party sound player (5) |
| `controller_app/lib/src/ui/controller_screen.dart` | 188 → 195 | the body is a `Stack`: the background (given, else `JoinedView`) fills the safe area, the bar and controls sit over it (5, 6) |
| `controller_app/lib/src/ui/controller_parts.dart` | 125 → 119 | `_Controls` loses `background` and watches `showsGameProvider` for the opacity and the demo readout (4, 6) |
| `controller_app/lib/src/ui/bar_connection.dart` | 93 → 93 | the status panel watches `showsGameProvider` (4) |
| `controller_app/test/support/fakes.dart` | 218 → 248 | `FakeClient`: `view` stream, real `ViewerStats`, `nowMs`, `viewStart`/`viewFrame`/`viewEnd` (7) |
| `controller_app/test/support/pump_app.dart` | 147 → 150 | `pumpApp` takes the safe area (`padding`) for the test's view |
| `controller_app/test/joined_view_test.dart` | new, 173 | the 6 tests below |
| `controller_app/test/host_mode_test.dart` | 162 → 164 | 3 rects follow item 6 (old → new below) |
| `controller_app/test/phone_metrics_test.dart` | 309 → 315 ⚑ | the hello's capability list (old → new below) |

⚑ over 300, under the 500 test limit. No `lib` file is near 400 (`controller_screen.dart` 195 is the longest touched).
`controller_client.dart` and `diagnostics_screen.dart` are untouched; every party_host import is `as party` (the new
`joined_view.dart`, `hosting.dart` already was). `pubspec.lock` did not change: the three packages were already in the
workspace lock, and `flutter pub get` in the root rewrote nothing.

## What each piece does

- **Identity** (2). `loadIdentity` lists `view` for every phone; `ownPlayerIdentity` returns the same identity with
  that capability filtered out, and `_inputs` uses it for the controller the server pairs this phone's own player as,
  so the server has no `isLocal` rule to guess with (s6a answer).
- **`viewActiveProvider`** (4). A `Notifier<bool>` over `clientProvider`'s `view` stream: `ViewStarted` → true,
  `ViewEnded` → false, frames and the away messages change nothing. `showsGameProvider` is
  `gameShownProvider || viewActiveProvider`, and the controls' opacity, the status panel and the demo readout read it.
- **`JoinedView`** (5). `FrameView(views: client.view, registry, stats: client.viewerStats!, nowMs: () =>
  client.nowMs, playerId: identity.controllerId, onSounds: every name → party.soundPlayerProvider.play)`. A client
  without the capability has a null `viewerStats`, so there is nothing to draw or measure and it builds nothing.
  `ControllerScreen` uses it as the background when none is given; the host route still passes `HostGames`.
- **Layout** (6). The background is `Positioned.fill` inside the `SafeArea`, and the bar-plus-controls column is over
  it, so the game takes the whole safe area (under the bar) while `_Controls.body` — the touch metrics' and layouts'
  box — stays the rectangle below the bar. The top bar paints no background of its own (bare `Padding` + `Row`), so
  there was nothing to make transparent; over a game the game simply shows through it. `HostGames` gets the bigger box
  the same way.

## How `viewActiveProvider` follows a client change

The notifier starts by watching `clientProvider` (which is `ownClientProvider ?? tvClientProvider`). When the client
changes — this phone starts hosting and `ownClientProvider` gets a client of its own (m12 §3) — Riverpod rebuilds the
notifier: the old subscription is cancelled through `ref.onDispose`, a fresh one listens to the new client's `view`
stream, and `build` returns false. So a new client always starts with no view, whatever the old one was showing, and
nothing that arrives from the old client can leave a game on a phone that now hosts. Test: "a new client starts with
no view, as when this phone starts hosting" (`ownClientProvider.notifier.set(FakeClient())` → the Arena goes, the
controls go back to full opacity).

## Test values

- Safe area at 852 × 393 with a notch (`FakeViewPadding(left: 48, top: 24, right: 48)`): the game's box is
  `Rect.fromLTWH(48, 24, 756, 369)`; the bar's 4 + 48 puts the controls at `Rect.fromLTWH(48, 76, 756, 317)`; the
  touch map is `756 / (160 / 25.4) = 120.015 mm` wide and `317 / (160 / 25.4) = 50.32375 mm` high (asserted with
  `closeTo(…, 1e-9)`). Without insets the same numbers are 393 → 62.39 mm and 341 → 54.146 mm.
- The opacity test saves `controlsOpacity: 0.6`: the layer's `Opacity` is 1.0 (`ControlsSettings.maxOpacity`) before
  the view, 0.6 over it, 1.0 again after the `ViewEnded`.
- The sounds test: three Arena steps at `atMs` 1000, 1016, 1032, each arriving on the phone's clock at that same ms
  (skew 0 for all three, so base 0 and playout delay 0), the third at `nowMs` 1032. The tick after the third draws
  render time 1032, which has passed all three: `['hit', 'snap']`, and no more on later ticks.
- The Arena test frames: `ArenaSnapshot(round: 1, roundTimeS: 30, phase: playing, walls: [], goal:
  (0.9, 0.4)–(1, 0.6), hazards: [], players: [ArenaPlayerView(id: 'phone-1', x: 0.5, y: 0.5)])`, 60 Hz, with
  `arenaSetup`, drawn once the first frame arrives.
- Unknown module: `ViewStartMessage(game: 'mystery', snapshotVersion: 1, setup: {}, hz: 60)` → `updateAppText`, and no
  Arena.

## Tests

| Check | Before | After |
| --- | --- | --- |
| format | PASS | PASS |
| analyze | PASS | PASS |
| phone | 291 | **297** |

`tools/review.sh`: 0 fail, 1 note — `controller_parts.dart:37` `top: 4`, a literal that was there before and moved
with the line I edited.

New tests (6, `controller_app/test/joined_view_test.dart`): identity lists `view` / the host's own player's doesn't;
a `ViewStarted` + a frame → the Arena behind the controls, opacity 0.6, panel hidden, then `ViewEnded` → Arena gone,
opacity 1.0, panel back; an unknown module → `updateAppText`; three frames' sounds play each once in step order
through `party_test.FakeSoundPlayer`; the game fills the safe area while the controls and the touch map keep the body
below the bar; a new client → no view.

**Existing expected values that changed** (item 6 and item 2 make them unavoidable; the brief says "list any old →
new"):

| Test | Old | New |
| --- | --- | --- |
| `host_mode_test` "the picker…" | `getRect(GamesScreen) == getRect(ControlsLayer)` | `GamesScreen == Rect.fromLTWH(0, 0, 852, 393)` and a new `ControlsLayer == Rect.fromLTWH(0, 52, 852, 341)` |
| `host_mode_test` "a puzzle…" | `getRect(PuzzleScreen) == getRect(ControlsLayer)` | `Rect.fromLTWH(0, 0, 852, 393)` |
| `host_mode_test` "Show on this device…" | `getRect(GamesScreen) == Rect.fromLTWH(0, 52, 852, 341)` | `Rect.fromLTWH(0, 0, 852, 393)` |
| `phone_metrics_test` "the hello lists…" | `[metrics, rating, layout, status]` | `[metrics, rating, layout, status, view]` |

The host route still draws `HostGames` behind the controls: the picker test finds `party.GamesScreen` with the
controls over it, and the "Show on this device" test still finds no `BarModes` or Settings.

## G4 plan (not in this job)

1. **Waiting card and countdown** (§0.3): a `WaitingCard` over the joined view, driven by a new
   `hostAwayProvider` in `providers/view.dart` (the `HostAway`/`HostBack` events `JoinedView`'s `FrameView` already
   sees, listened to on `client.view`), the countdown ticking on `client.nowMs`. Files: `providers/view.dart`,
   `ui/joined_view.dart` or a new `ui/waiting_card.dart`. Risk: two listeners on one broadcast stream is fine, but
   the card must also survive a reconnect (the server re-sends the start, not the away).
2. **Abandoned notice** (§0.5): the `ViewEnded` reason's abandoned case — a card that says the round is over, in
   `view.dart` (a second provider or a field on the notifier). Risk: check which `ViewEndReason` the host sends.
3. **Host list labels** (§0.6): `host/host_games.dart` (and whatever builds the list in `party_host` if the labels
   come from the module), text only — the smallest of the six.
4. **`service.shareView` from the start sheet** (§0.1): `host/host_games.dart`'s start sheet and
   `party_host`'s `HostService.shareView` (built in s6a). Risk: the sheet is in `party_host`, so a change there is a
   `packages/` change, not just the app.
5. **Sound player restart on app show**: a lifecycle observer (`AppLifecycleState.resumed`) next to the sound player
   provider; risk: nothing here is testable on the phone without faking the lifecycle, so a unit test on the
   observer's own method.
6. **Diagnostics "Game view"** (§5): `ui/diagnostics_screen.dart` (untouched in G3 on purpose) + `viewerStats.summary`
   from s6a. Last, because it reads what 1 and 2 add.

## Notes and questions

1. **The view stays mounted while no view is on.** A broadcast stream drops events with no listener, and
   `viewActiveProvider` only turns true *when* the `ViewStarted` arrives — so building the `FrameView` only then
   loses the very start that mounts it (the first draft did, and the tests caught it). `JoinedView` therefore always
   builds the `FrameView` and wraps it in `Visibility(visible: viewActiveProvider, maintainState: true)`: the user
   sees nothing while no view is on (`FrameView` draws nothing before a start), and the start is heard. Reading item 5's
   "else nothing" as what is on screen.
2. **The bar's background** (item 6) needed no line: `_TopBar` is a bare `Padding` over a `Row`, with no
   `Material`/`ColoredBox`, so a game behind it shows through in every state. If you wanted a background *except*
   while a game shows, there is none to hide.
3. **The two `host_mode_test` rect changes and the hello list** are the "old → new" above. The brief's "no expected
   value changes" and its item 6 can't both hold; I follow the contract (phone layout §0.7) and list them.
4. `FakeClient.viewFrame` takes its arrival from the test's `nowMs`, so a test that wants a late frame sets `nowMs`
   itself; that is also how the sounds test gets zero skew.
5. `ControlsLayer.child` (the game) is now never passed by the app — the game sits behind the whole screen — but the
   parameter and its test ("a touch outside the controls reaches the game") stay; it's how that layer says what
   "behind" means, and a future game-inside-the-body layout would want it.

## Commit message

m12 s6b G3: the joined view on the phone, first slice

- controller_app: `loadIdentity` lists `Capability.view`; the host's own player pairs with the same identity minus
  it (`ownPlayerIdentity` in host/hosting.dart), since the server has no isLocal rule.
- controller_app: `gameRegistryProvider` (shape race, arena); `viewActiveProvider` follows `clientProvider`'s view
  stream (ViewStarted → ViewEnded, and false for a new client); `showsGameProvider` = host route or joined view,
  read by the controls' opacity and the status panel.
- controller_app: `ui/joined_view.dart` draws the host's frames in a FrameView behind the controls, with the party
  sound player for each frame's sounds; ControllerScreen uses it when it is given no background.
- controller_app: the game fills the safe area behind the top bar for both the joined view and the host route; the
  controls and their touch map keep the body box below the bar.
- 6 new tests (291 → 297); 4 existing expected values follow the new layout and the new capability, listed in the
  report.

## Status row

| 6 Joined view | **s6b G3 done**: the phone lists `view` and the host's own player doesn't, the joined view draws a host's game behind the phone's controls (registry, `viewActiveProvider`, `showsGameProvider`, sounds through the party player), and the game fills the safe area behind the bar for the joined view and the host route alike — phone 291 → 297 tests, format/analyze PASS, review 0 fail. Not in (G4): waiting card and countdown §0.3, abandoned notice §0.5, host list labels §0.6, `shareView` from the start sheet §0.1, the sound player restart on app show, Diagnostics "Game view" |

## Delete

- none
