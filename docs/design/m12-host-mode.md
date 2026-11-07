# M12 step 5 contract: host mode on the phone

Nov 7, 2026. Refines [m12.md](m12.md) §2.1, §2.2, §2.6, §2.9 and §2.10 for step 5, and wins where they differ. Facts: [s5-g0-survey.md](../briefs/m12/s5-g0-survey.md). Rules: [coding-guidelines.md](../coding-guidelines.md).

**Goal:** on a phone or tablet, "Host a game" runs the whole host (server, advertising, game host, stats, sound, the `party_host` screens) inside the phone app. The phone's own player is an ordinary controller over an in-process link, and its controls are drawn over the host's screens. A solo puzzle works with Wi-Fi off. Locking the phone pauses the game; unlocking within 30 s resumes it.

## 0. Decisions on the survey's questions and conflicts

- **The own player stays a normal player** (survey Q2, conflict 1), not `GamePlayer.local`: it keeps the controller menus, and `ControllerInfo.isLocal` already says its channel is in-process. Step 8 reads `isLocal` for "watched on the host phone". (Changes m12.md §2.1's last line.)
- **Directories** (Q1): sessions under the app support folder (`sessions`, `sessions-debug` in debug builds, as the TV); exports in the app documents folder. `PhoneHostDirectories` in the phone app.
- **The advertised name** (Q3, conflict 4) comes from `HostIdentity`: the TV keeps "Thumb Party TV (…)"; a phone host uses "Thumb Party on <its controller name>" (`iPhone 3F2A`, from `storage.dart` `ControllerIdentity.name`). The log and stats strings that say "TV" take the identity's display name where they name the host; screen text that says "TV" stays for step 9's wording pass.
- **Best times** (Q4) stay in memory per match, as on the TV. Nothing to store.
- **`HostType.tablet`** (Q5, conflict 5) is added to the metrics `HostType` (additive). The phone host sets `phone` or `tablet` from its `DeviceInfo.kind`.
- **Restarting after a background** (Q6, conflict 3): `HostService` gains `Future<void> resume()`, which restarts the server on the same port if it stopped listening and restarts advertising. `HostPresence` calls it.
- **Sound** (conflict 2) stays in providers; the phone's host scope overrides nothing for sound (the `SoLoud` player is cross-platform). The device check proves it.
- **Background time** (conflict 8): none is asked for. The game pauses when the app is hidden; within the grace period the app comes back and `resume()` restores what the OS closed.
- **bonsoir advertising on phones** (Q7) is unproven: build 1's device checks include "the iPad sees the iPhone's game in its host list". The step 5 exit (solo, Wi-Fi off) doesn't need it.
- **"Show on this device" (C34)** is a choice on the host start: with it, the phone has no own player and no controls on top; the screens fill it, and everyone joins from their phones.

## 1. connection

- `LiveHostService` takes an optional `InProcessListener` and adds it to the `HostServer`'s listeners; the phone app passes one, the TV doesn't. Nothing else changes in pairing, tokens or heartbeats.
- `ControllerClient` over `InProcessConnector` (exists, step 2) for the own player.

## 2. party_host

```dart
abstract class HostService {
  // ...as today, plus:
  /// After the app was in the background: restarts the server on its port if
  /// it stopped listening, and the advertising. Does nothing when both run.
  Future<void> resume();
}

/// Pauses the game while the host app is hidden, and ends the round when it
/// stays hidden longer than [graceS] (m12 §2.10).
class HostPresence {
  HostPresence({required HostService host, required void Function() onAbandon, int Function()? nowMs, this.graceS = 30});
  final int graceS;
  /// True from the moment the app is hidden until it's shown again.
  ValueListenable<bool> get away;
  void hidden();   // the app went to the background or the screen locked
  Future<void> shown(); // calls host.resume(); away within graceS → unpause; longer → onAbandon()
  void dispose();
}
```
- `hostAwayProvider` (party_host) exposes `away`; `Pausable` treats `away` like an open pause menu (no step, no clock), without showing the menu. A round ended by `onAbandon` records `round_end` with `reason: abandoned` and returns to the games screen (`gamesRouteName`); its view ends `abandoned`.
- The TXT record gains `kind` (`tv`, `pc`, `phone`, `tablet`) from `HostIdentity.kind` (new field; the TV sets `tv` on Android TV, `pc` on Windows).
- `HostType.tablet` in `packages/metrics`.

## 3. The phone app

- **Entry:** `ConnectScreen` gets "Host a game" beside "Try without a TV" (C25). It opens a host start sheet: "Play on this phone" (default) or "Show on this device" (C34), then the host.
- **`PhoneHost`** (`lib/src/host/`): builds the `LiveHostService` with the phone's identity, `PhoneHostDirectories`, an `InProcessListener`, the prefs and log, and starts it. It owns `HostPresence` (driven by an `AppLifecycleListener`: `onHide` → `hidden`, `onShow` → `shown`).
- **The host screen:** a nested `ProviderScope` with `party_host`'s overrides (its `prefsProvider`, `logProvider`, `hostServiceProvider`; import `party_host` with a prefix where names clash). It shows the `party_host` games screen as the body behind the controls: `ControllerScreen` gains an optional `background` widget (the `ControlsLayer` child) and, in host mode, `clientProvider` is overridden with the in-process client and the screen doesn't reconnect or open `ConnectScreen`. `gameShownProvider` is true in host mode. With "Show on this device" the games screen fills the phone alone.
- **Own player:** a `ControllerClient` with the phone's own `ControllerIdentity` over `InProcessConnector`, pairing with the host's current code, as the TV's simulated controllers do.
- **Leaving host mode:** a "Stop hosting" item in the host screen's menu (and on the pause menu's Quit from the games screen, unchanged); it disposes the host and returns to `ConnectScreen`.
- `controller_app` depends on `party_host`, `game_kit`, `puzzle_game`, `test_game`, `game_assets`. The iOS deployment target and Android minSdk already cover `flutter_soloud` and `bonsoir`.

## 4. Tests (the job briefs carry the cases)

- connection: a client over `InProcessConnector` pairs with a `HostServer` that also has a WebSocket listener, and both kinds of client are players.
- party_host: `HostPresence` with a fake clock: hidden 10 s → shown → unpaused, `resume` called once; hidden 31 s → `onAbandon` once; `away` true while hidden. `resume()` restarts a stopped server on the same port (a fake listener). The TXT has `kind`.
- controller_app: "Host a game" → the games screen behind the controls with the own player paired (a fake `HostService` or a real one on the in-process link only); "Show on this device" → no controls; "Stop hosting" disposes the host.

## 5. Exit check

All checks pass; on this PC the TV app is unchanged (smoke). On the iPhone (build 1): host a solo Shape Race with Wi-Fi off and finish it; lock and unlock within 30 s and the round resumes; lock for over 30 s and it ends as abandoned. On the iPad: the iPhone's game appears in its host list (advertising).

## 6. Jobs and gates

| Job | What | Gates |
| --- | --- | --- |
| s5a | §1, §2: `resume`, `HostPresence`, `hostAwayProvider`, `kind`, `HostIdentity.kind`, `HostType.tablet`, the in-process listener in `LiveHostService` | G2 → G4 |
| s5b | §3: the phone host, the entry, the host screen, C34 | G1 plan → G3 (solo Shape Race on the host screen, in a widget test) → G4 |
