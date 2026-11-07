# s5b G3 — host mode in the phone app, S0 and S1

**Status: stopped at G3, with S0 and S1's code in and the workspace green.** S0 (the moves) is done and
proven. S1 (the host, the entry, the route, the harness) compiles, passes `dart analyze` and the whole
`tools/check.sh`, and the G3 path works up to and including the host route with its own player paired —
but **the own player's pad does not reach the host**, and that is a design decision, not a slice: the
host route's `ProviderScope` (Q1: "only overrides `clientProvider`") does not reach any provider the app's
home `ControllerScreen` has already built. Evidence, consequences and options are in "The scope does not
reach the pad" below. The new test therefore stops after plan §9 step 3.

## What landed

**S0, the moves (files 1–6 of plan §11), strings unchanged:**

- `connect_panels.dart` (new) holds `ConnectionPanel` and one widget per connection status
  (`_NotConnected`, `_Waiting`, `_Connected`, `_Failed`, `_CodeEntry`) plus `_NoTvActions`
  ("Try without a TV" and "Host a game"), moved out of `connect_screen.dart`. `ConnectionPanel.build` is a
  `switch` over the status, so no list of statements has to grow.
- `bar_connection.dart` (new) holds `BarConnection`, `PlayerBadge` and `_statusColor`.
- `bar_modes.dart` (new) holds `BarModes` and the `_ModePicker` (`SegmentedButton`), so each `build` is
  short.
- `controller_top_bar.dart` is now `_TopBar` picking `hosting ? const HostChip() : const BarConnection()`,
  then `if (controls) const BarModes()`, then Settings and Diagnostics.
- `controller_parts.dart`: `_Controls` takes `background` (the game behind) and `controls` (false for C34,
  returning the game alone).

**S1, the host (files 7–20):**

- `pubspec.yaml`: `party_host` (path) and `path_provider: ^2.1.6`. `flutter pub get` at the root: "Got
  dependencies", `pubspec.lock` unchanged (0 diff).
- `phone_host.dart`: `PhoneHost.live`, the `InProcessListener`, the own `ControllerClient`, `start()`
  (service first, then the own player on the link with the pairing code), the `HostPresence` + lifecycle
  listener, `abandon()` (games navigator → `gamesRouteName`) and an idempotent `dispose()`.
- `hosting.dart`: `hostingProvider` (`NotifierProvider<HostingNotifier, PhoneHost?>`), the
  `phoneHostBuilderProvider` seam, `phoneServiceProvider` (throws before the first host) and the discovery
  stop.
- `host_overrides.dart`: the four `party_host` overrides, supplied by `main()` and by the tests.
- `host_screen.dart`, `host_games.dart`, `host_start_sheet.dart`, `host_chip.dart`: the route with the
  nested scope, the games navigator, the sheet with both choices, and the bar's host chip (code, first
  address, "New code"; "Stop hosting" is G4).
- `controller_screen.dart`: `background`/`controls`, `_hosting`, the guards of plan §6 (no reconnect, no
  discovery, no session monitor, no rating prompt while hosting) and `_followTheTv` extracted so `build`
  stays under 60 lines.
- Tests: `pump_app.dart` gains `extra:` on `pumpApp`/`pumpFaked`; `host_app.dart` is the harness (temp
  folders, fakes for advertiser/sound/screen, the puzzle library loaded in the real clock, `hostOf`,
  `hostReady`, `enterHostMode`, `tapFace`, `pressFace`, `faceLabels`); `host_mode_test.dart` is the G3
  path's first case, up to step 3.

## Line counts (flag: > 300)

| File | Lines |
| --- | --- |
| `controller_app/lib/main.dart` | 45 (was 33) |
| `controller_app/lib/src/host/host_games.dart` | 22 (new) |
| `controller_app/lib/src/host/host_overrides.dart` | 23 (new) |
| `controller_app/lib/src/host/host_screen.dart` | 67 (new) |
| `controller_app/lib/src/host/host_start_sheet.dart` | 93 (new) |
| `controller_app/lib/src/host/hosting.dart` | 50 (new) |
| `controller_app/lib/src/host/phone_host.dart` | 112 (new) |
| `controller_app/lib/src/host/phone_host_setup.dart` | 42 (new) |
| `controller_app/lib/src/ui/bar_connection.dart` | 93 (new) |
| `controller_app/lib/src/ui/bar_modes.dart` | 88 (new) |
| `controller_app/lib/src/ui/connect_panels.dart` | 298 (new; see below) |
| `controller_app/lib/src/ui/connect_screen.dart` | 222 (was 412) |
| `controller_app/lib/src/ui/controller_parts.dart` | 125 (was 117) |
| `controller_app/lib/src/ui/controller_screen.dart` | 182 (was 150) |
| `controller_app/lib/src/ui/controller_top_bar.dart` | 40 (was 164) |
| `controller_app/lib/src/ui/host_chip.dart` | 65 (new) |
| `controller_app/test/host_mode_test.dart` | 53 (new) |
| `controller_app/test/support/host_app.dart` | 119 (new) |
| `controller_app/test/support/pump_app.dart` | 145 (was 140) |
| `controller_app/pubspec.yaml` | 38 (was 35) |

**Nothing is over 300**, but `connect_panels.dart` is at 298 and only fits because `_Connecting` and
`_Reconnecting` were merged into one `_Waiting` (same strings, one widget, `reconnecting:` flag). Its first
version was 309: the per-status widgets the review's 60-line limit forced out of `ConnectionPanel` cost
more than the plan's ~215 estimate. If it has to grow again, `_CodeEntry` (93) is the natural next file.
No lib file grew past 400 and no test past 500.

## The scope does not reach the pad (why this stopped)

**What the plan assumes** (§1, §6): the host route's `ProviderScope` overrides `clientProvider`, and
"`gameLayoutProvider`, `gameStatusProvider`, `tvHapticsProvider`, `ratingPromptProvider`,
`phoneMetricsProvider` … all live inside the host route's scope", so the own player replaces the TV client
below the route. The brief's Q1 keeps that as decided.

**What Riverpod 3.4.3 does:** a provider is created in the first container that reads it, and a child
container **reuses that element** whatever the child overrides. Minimal repro (run as a throwaway test,
both with `ProviderContainer(parent:)` and with a nested `ProviderScope`):

```dart
final base = Provider<int>((ref) => 1);
final derived = Provider<int>((ref) => ref.watch(base) * 10);
final root = ProviderContainer();
root.read(derived);                                     // 10
final child = ProviderContainer(parent: root, overrides: [base.overrideWithValue(2)]);
child.read(base);                                       // 2
child.read(derived);                                    // 10, not 20
```

**In this app** the root container builds those providers first: `main.dart`'s `home` is
`const ControllerScreen()` (`main.dart:42`) and `ConnectScreen` is pushed over it, so the app's own pad,
`clientStateProvider`, `gameLayoutProvider`, `padProvider` … all exist in the root container before a host
starts. In the G3 test (all measured, then the probes removed):

- `ProviderScope.containerOf(ControlsLayer)` is **not** the container of `MaterialApp` (two containers, and
  the override is applied: `container.read(clientProvider)` is `host.client`).
- `identical(hostContainer.read(gameLayoutProvider.notifier), rootContainer.read(gameLayoutProvider.notifier))`
  is **true** — and the same for `padProvider` and `clientStateProvider`. The host scope shares the root's
  elements.
- Therefore the host's pad is labelled `'A, B, X, Y'` while the own player's client holds
  `{a: OK, b: Back}`, and `pressFace(a)` never opens Shape Race: `PadNotifier` sends through
  `ref.read(clientProvider)` **of its own container**, which is the root's, i.e. the app's TV client.
- The chip's own player number had the same cause (`clientStateProvider` in the host scope is the root's,
  player `null`); it now reads `party.hostStateProvider`'s own (local) controller, which is the authority
  anyway.

So host mode is wired end to end except that the own player's pad does not play it, which is exactly what
plan §9 step 4 (labels) and steps 5–6 (A through the menus) assert. **This is Q1's decision to revisit, not
something to guess at**, so the test stops at step 3 and the pad's half of the case is left out.

**Options** (not acted on):

1. **Make `clientProvider` host-aware** — `ref.watch(hostingProvider)?.client ?? <the app's client>` in the
   one root container, and drop the nested scope. Every client-derived provider then rebuilds with the own
   player, `main.dart` needs nothing, and the chip's badge can go back to `clientStateProvider`. Costs:
   `providers/connection.dart` imports `host/hosting.dart` (which imports `../providers.dart` — a library
   cycle, or `hostingProvider`'s inputs move to break it).
2. **Override every client-derived provider in the host scope** — correct but a list that must track every
   new client-derived provider; the failure mode (a silently shared provider) is what bit here.
3. **Do not keep a `ControllerScreen` under the Connect route** (home becomes `ConnectScreen`, the
   controller is pushed when a TV answers) — then the root never builds them first. Biggest change, and it
   touches the "switch TV mid-game" path.

Recommendation: 1. It is the only one where the host and the controller cannot disagree by construction,
which is what §1's "one container" argument was after.

## The S0 strings proof

Measured **right after S0, before S1 touched anything**:
`tools/review.sh --strings` → `strings: 0 removed, 0 added, 69 unchanged or moved`. So the moves changed no
user-visible string.

Measured now (S1 included): `strings: 2 removed, 22 added, 68 unchanged or moved`.

- the 2 removed are `'tryWithoutTv'` and `'Try without a TV'` from `connect_screen.dart`, which S1 moved to
  `connect_panels.dart:72/74` (`_NoTvActions`, the tool lists removals per file);
- the 22 added are S1's own: the sheet's keys and labels, the chip's, `'Host a game'`, `'No host is running
  in this app'`, the host's `'own'` log sink, the identity's `'Thumb Party on …'` and the sessions path.

## Tests, before → after

| Check | Before | After |
| --- | --- | --- |
| format | pass | pass |
| analyze | no issues | no issues |
| protocol | 102 | 102 |
| connection | 223 | 223 |
| metrics | 39 | 39 |
| kit | 25 | 25 |
| arena | 39 | 39 |
| puzzle | 78 | 78 |
| host | 54 | 54 |
| phone | 275 | **276** (the new entry case) |
| tv | 23 | 23 |

`tools/check.sh format analyze protocol connection metrics kit arena puzzle host phone tv` → all PASS (89 s).
`tools/review.sh` → `0 fail, 47 note` (the 11 extra notes are numeric literals in the new files; no FAIL).
No expected value changed in an existing test.

Computed values the case asserts: the picker's rect equals the `ControlsLayer` rect (852×341 body under the
bar); one controller in `state.host.controllers` with `isLocal` true; `gameHost.players.single.number == 1`;
`Key('hostChip')` shows the live pairing code; `Key('playerBadge')` shows `P1`.

## Plan §8: what is sure, and what I found out

**Verified in the tree** (the plan said so; it holds):

- `android/app/src/main/AndroidManifest.xml` declares exactly `INTERNET`, `ACCESS_NETWORK_STATE`,
  `CHANGE_WIFI_MULTICAST_STATE` and `VIBRATE` — no new permission for advertising, no `NEARBY_WIFI_DEVICES`.
- `minSdk = 31` (`android/app/build.gradle.kts:35`), far above `path_provider`'s minimum.
- iOS `Info.plist` already has `NSLocalNetworkUsageDescription` (`:29`) and `NSBonjourServices` with
  `_gamectl._tcp` (`:31-33`), which advertising reuses; no `UIBackgroundModes`.

**Found out while building it:**

- **The host's timers outlive a widget test.** The service refreshes addresses every 10 s and the link
  heartbeats; if a test ends with the host running, the binding fails with "A Timer is still pending even
  after the widget tree was disposed". `await tester.runAsync(host.dispose)` at the end of the case fixes
  it (in the test). G4's "Stop hosting" test will dispose the host through the UI instead.
- **A real `LiveHostService` does run inside `flutter test`.** `hostReady` (200 × 5 ms of real time under
  `tester.runAsync`, each followed by a 16 ms pump) is enough for the stats file, the socket bind, the
  in-process pairing and the welcome. No fake `HostService` is needed for G3.
- **The port is not null.** `LiveHostService` always adds the LAN listener, so the host binds 45780 even
  though the own player only uses the in-process one; "port is null when every listener is port-less" is
  about `HostServer`'s listener set, not about this service.
- **`Override` is exported by `package:flutter_riverpod/misc.dart`** in Riverpod 3.4.3, not by
  `flutter_riverpod.dart` (`List<Override>` does not compile from the latter). `host_overrides.dart` and
  `pump_app.dart` import `misc.dart` for it.
- **The puzzle library loads from the bundle inside `tester.runAsync`** (a bare `ProviderContainer`, its
  future awaited there), so `host_app.dart` overrides `party.puzzleLibraryProvider` with it and no test
  needs `build/unit_test_assets` gymnastics.

Still unproven and only a device check (as §8 says): whether a phone may advertise with NSD reliably while
the app is in front, whether `flutter_soloud` initialises on the same phone that draws the game, and whether
the sound and the phone's haptics fight.

## Deviations and smaller questions

1. **`PhoneHost.service` is `party.LiveHostService`, not `party.HostService`.** `HostService` has no
   `start()` (only the live class does, `host_service.dart:200`), and the TV app holds the live class too.
   `phoneServiceProvider` still hands out a `HostService`.
2. **`PhoneHost` owns `gamesKey`.** `abandon()` uses `gamesKey.currentState?.overlay?.context` rather than
   `Navigator.of(gamesKey.currentContext)`: the latter starts looking from the element's *parent*, so it
   would find the app's navigator above the games one.
3. **`hostingProvider.start()` takes no `HostChoice`.** The choice is the route's `controls` flag, so the
   notifier stays about the host, not about the screen.
4. **`phoneHostOverrides` takes only `directories`.** `prefs`, the identity, the log and the advertiser are
   read through `party.*` providers at build time, so `main()` and the tests cannot pass a stale instance;
   the tests get a temp folder through `directories`.
5. **`pumpApp` gained `extra:` too**, not only `pumpFaked`, because the host app is pumped through it.
6. **The host chip shows `PlayerBadge`** (plan §9 step 4 asks for it in the bar) but reads the number from
   `party.hostStateProvider`'s local controller — see the scope section. With option 1 above it can go back
   to `clientStateProvider`.
7. **"Show on this device" is offered and works in S1** (`controls: false`); G4 adds its test and "Stop
   hosting".
8. **`_NoTvActions` is private to `connect_panels.dart`** while `connect_screen.dart` uses
   `ConnectionPanel`: the two buttons are only ever built by the panel.

Open questions for Claude:

- **Q-A: which option above, for the scope?** Nothing in G4 works until the own player's pad does.
- **Q-B: `connect_panels.dart` at 298** — the plan estimated ~215. Should the per-status widgets move to a
  file of their own in G4 (with the C34 work), rather than trimming again?
- **Q-C: the chip's badge** — keep it on the host's snapshot, or put it back on `clientStateProvider` once
  the scope question is answered? (The host is the authority either way; the two can only differ while the
  own link is reconnecting.)

## Commit message

Phone app hosts a game: entry, host route, own player

S0 splits connect_screen and the top bar into connect_panels, bar_connection,
bar_modes and a short _TopBar, and _Controls learns background/controls.
S1 adds the host itself (phone_host, hosting, the party_host overrides), the
sheet with both ways to host, the host route with its games navigator, the
bar's host chip (code, address, New code) and the switch-offs of plan §6.
New test harness: pumpApp/pumpFaked take extra overrides, host_app runs a real
LiveHostService in a temp folder with faked advertiser, sound and screen.
The G3 path stops at step 3: the host route's scope does not reach the pad
(built in the root container first), which needs Q1 revisited — see the report.

## Status row

s5b G3: S0 done, S1's code in and green (entry, host route, own player paired, chip, harness); OPEN: the own player's pad still uses the root container's providers, so plan §9 steps 4–6 and everything after wait on the Q1 scope decision (report "The scope does not reach the pad").

## Delete

- none
