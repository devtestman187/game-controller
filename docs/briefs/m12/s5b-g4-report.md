# s5b G4 — host mode complete: the own player's pad, C34, Stop hosting, lifecycle, abandoned rounds

**Status: done, at G4. Step 5 ends here.** The own player's pad plays the game the phone hosts (Q-A), "Show on
this device" and "Stop hosting" work, the lifecycle pauses the round and abandons it after the grace, and a
round the host lost ends `abandoned` with its records. Everything the brief lists is in, in the order it
asked for, with all checks green after every slice.

## What landed

### 1 Q-A: one client provider, two clients

- `providers/connection.dart`: today's body is `tvClientProvider`; `ownClientProvider`
  (`Notifier<ControllerClient?>`, `set`/`clear`) is new; `clientProvider` is
  `ref.watch(ownClientProvider) ?? ref.watch(tvClientProvider)`, with no `onDispose` of its own (each owner
  disposes its client). 184 → 206 lines.
- `hosting.dart`: `start()` sets the own client before the route opens and stops the search; `stop()` clears
  it, clears `gameShownProvider`, disposes the host and restarts the search. 50 → 74.
- `host_screen.dart`: the nested `ProviderScope` is gone, and so is everything that existed only for it;
  the route now also stops the host on the system back (`PopScope`). 67 → 59.
- `host_chip.dart`: the badge is back on `clientStateProvider` (Q-C), and the menu has "Stop hosting".
  65 → 73.
- `connect_screen.dart`: its "connected, so pop" listener ignores a connect while this phone hosts — the
  own player's connect would otherwise pop the Connect screen under the host route, and the host route
  with it. 222 → 226.
- **Plan §9 steps 4–6**: `host_mode_test.dart`'s single G3 case (which stopped at step 3) became four
  cases: the pad's labels, A through the menus into a solo Shape Race with the own player on the left;
  "Show on this device"; Stop hosting and a second host; the system back press.

### 2 S2: C34 and leaving

- `HostChoice.onDevice` (`controls: false`): no pad, no mode buttons, no Settings, the game filling the
  body under the bar.
- "Stop hosting" in the chip's menu (`Key('stopHosting')`) and the system back both stop the host; the
  route pops itself off `host.disposed`, the own client goes back to the TV client, the search resumes, and
  a second "Host a game" works (a new host, new provider instances).

### 3 S3: lifecycle and switch-offs

- `PhoneHost`: `away` (the presence's `ValueListenable`) and a `nowMs` seam for the presence's clock.
- `host_overrides.dart`: `party.hostAwayProvider` is the running host's `away`, `NeverAway` before the
  first host.
- `controller_screen.dart`: `didChangeAppLifecycleState` decides "hosting" from `_hosting` **or**
  `hostingProvider`, because the controller screen *below* the host route hears the same lifecycle events;
  without it a hosting phone restarts discovery on every resume.
- `host_lifecycle_test.dart` (new): the resumed case (search, TV client untouched, own player still
  paired), hidden → shown (away true, then the host back with one more advertising start), and hidden 31 s
  (see 5).

### 4 S4: the host state and the entry

- `hosting_test.dart` (new, a plain `ProviderContainer` test, no widgets): the provider throws before the
  first host; `start()` gives a running host with its own player paired and one local controller; `stop()`
  leaves it dead, the client idle, the own client cleared and the search restarted; a second `stop()` is a
  no-op; a second `start()` gives a new host and a new `party.hostServiceProvider` instance.
- `connect_screen_test.dart`: "Host a game" with no TV and after a failure, the sheet with both choices and
  the phone one focused, and Cancel starting nothing. 99 → 143.

### 5 Abandoned rounds (contract §2)

- `game_kit`: `GameSession.abandon()` ends the view `abandoned` and disposes, so a later `dispose` does
  nothing. 277 → 287.
- `puzzle_game`: `PuzzleSession.abandon()` records one `round_end {reason: abandoned}` (no winner) unless
  the match already reported a result, hides the panels and ends the view; `PuzzlePlayView` takes an
  optional `abandon` listenable. `dispose` now shares `_hideStatuses`.
- `test_game`: `ArenaSession.abandon()` records `round_end {reason: abandoned}` for a running round, then
  its `frames` as `dispose` does; `ArenaView` takes an optional `abandon`.
- `party_host`: `AbandonSignal` + `hostAbandonProvider` (new file, exported); `PuzzleScreen` and
  `GameScreen` hand the signal to their views; `abandonRound` fires it before popping; `NeverAway` is now
  public so a shell can hand it out before it has a host.
- `PhoneHost.abandon()` already went back to the games navigator (G3); what it needed was the signal, which
  the round's view hears through the root container.

## Line counts (flag: > 300)

| File | Was → now |
| --- | --- |
| `controller_app/lib/src/host/host_overrides.dart` | 23 → 27 |
| `controller_app/lib/src/host/host_screen.dart` | 67 → 59 |
| `controller_app/lib/src/host/hosting.dart` | 50 → 74 |
| `controller_app/lib/src/host/phone_host.dart` | 112 → 129 |
| `controller_app/lib/src/providers/connection.dart` | 184 → 206 |
| `controller_app/lib/src/providers/game_feedback.dart` | 96 → 96 (doc only) |
| `controller_app/lib/src/ui/connect_screen.dart` | 222 → 226 |
| `controller_app/lib/src/ui/controller_screen.dart` | 182 → 185 |
| `controller_app/lib/src/ui/host_chip.dart` | 65 → 73 |
| `controller_app/lib/src/ui/connect_panels.dart` | 298 → 298 (untouched) |
| `controller_app/test/connect_screen_test.dart` | 99 → 143 |
| `controller_app/test/host_mode_test.dart` | 53 → 140 |
| `controller_app/test/host_lifecycle_test.dart` | 102 (new) |
| `controller_app/test/hosting_test.dart` | 100 (new) |
| `controller_app/test/support/fakes.dart` | 215 → 218 |
| `controller_app/test/support/host_app.dart` | 119 → 155 |
| `controller_app/test/support/pump_app.dart` | 145 → 147 |
| `packages/game_kit/lib/src/game_session.dart` | 277 → 287 |
| `packages/game_kit/test/session_test.dart` | 192 → 213 |
| `packages/party_host/lib/party_host.dart` | 35 → 36 |
| `packages/party_host/lib/src/abandon_signal.dart` | 17 (new) |
| `packages/party_host/lib/src/host_presence.dart` | 97 → 98 |
| `packages/party_host/lib/src/ui/game_screen.dart` | 267 → 274 |
| `packages/party_host/lib/src/ui/pause_menu.dart` | 198 → 202 |
| `packages/party_host/lib/src/ui/puzzle_screen.dart` | 185 → 187 |
| `packages/party_host/test/abandon_test.dart` | 31 (new) |
| `packages/puzzle_game/lib/src/play_view.dart` | 116 → 125 |
| `packages/puzzle_game/lib/src/puzzle_session.dart` | 161 → 176 |
| `packages/puzzle_game/test/puzzle_session_test.dart` | 173 → 210 |
| `packages/test_game/lib/src/arena_session.dart` | 115 → 132 |
| `packages/test_game/lib/src/arena_view.dart` | 74 → 82 |
| `packages/test_game/test/arena_session_test.dart` | 108 → 138 |

**Nothing is over 300** among the files this job touched (the largest new one is `host_mode_test.dart` at
140; `connect_panels.dart` stays at 298 and was not edited, so Q-B's condition did not trigger). No lib file
grew past 400, no test past 500, `packages/connection/lib/src/controller_client.dart` is untouched.

## Tests, before → after

| Check | Before | After |
| --- | --- | --- |
| format | pass | pass |
| analyze | no issues | no issues |
| protocol | 102 | 102 |
| connection | 232 | 232 |
| metrics | 45 | 45 |
| kit | 29 | **30** (+1: `abandon`) |
| arena | 39 | **40** (+1: abandoned round) |
| puzzle | 78 | **80** (+2: abandoned mid-match and after the result) |
| host | 54 | **55** (+1: `abandon_test.dart`) |
| phone | 276 | **286** (+10: see below) |
| tv | 27 | 27 |

"Before" is the tree as G3 left it for the packages this job changed, and today's count for the packages it
did not touch (protocol, connection, metrics and tv gained tests in other, uncommitted work; nothing in
them changed here). The phone's ten: `host_mode_test.dart`'s one G3 case became four (+3),
`host_lifecycle_test.dart` 3 (two in S3, one in S5), `hosting_test.dart` 1, `connect_screen_test.dart` 3.

**No expected value changed in an existing test.** The only removal is the G3 case that stopped at step 3;
its assertions (the picker behind the controls, one local controller, P1, the chip's code) are all in
`host_mode_test.dart`'s first case, unchanged.

Computed values the new tests assert:

- **Steps 4–6** (`host_mode_test.dart`): the picker's rect equals the `ControlsLayer` rect; one controller,
  `isLocal`; `gameHost.players.single.number == 1`; `faceLabels` contains `'A OK'` and `'B Back'`; A →
  `ShapeRaceScreen` with `random-easy` focused; A → `JoinScreen`; A, A → `PuzzleScreen` with
  `teams.keys == [host.client.identity.controllerId]` and `[PuzzleSide.left]` (i.e. `'left'`), its rect
  still the `ControlsLayer`'s; the pad's labels become `'A Pick up'`.
- **C34**: `GameScreen`'s rect is `Rect.fromLTWH(0, 52, 852, 341)` at 852×393 — the 52 is the bar (4 padding
  + a 48-high row) and 341 the body; no `ControlsLayer`, no `faceButtons`, no `dpad`, no `BarModes`, no
  Settings tooltip; the chip and Diagnostics stay.
- **Stop hosting**: the chip's menu → `host.live == false`, `ConnectScreen` back, the own client
  `ClientStatus.idle`, `FakeDiscovery.restarts` + 1; the second host is a different object whose player is
  P1 again; the back press (`handlePopRoute`) does the same.
- **Lifecycle**: on `resumed` while hosting, `restarts`, `stops` and `FakeClient.calls` are unchanged (the
  TV client is never built or touched); after `hidden` → `inactive` → `resumed`, `away` goes true then
  false and `FakeAdvertiser.starts` grows by exactly one (the fake's status stays `starting`, so
  `LiveHostService.resume` takes its `_startAdvertising` branch).
- **Host state**: `discovery.stops == 1` after `start`; `host.service.state.host.running` true;
  `state.players.length == 1`; `discovery.restarts == 1` after `stop`, still 1 after a second `stop`.
- **Abandoned rounds**: game_kit — one `view_end` (reason `abandoned`), no step and no frame after it; puzzle
  — one `round_end` whose `data` is exactly `{reason: 'abandoned'}`, no `frames`, panels hidden; after a
  result, the record list is unchanged; arena — `round_end` with `playerId == null` and
  `data == {reason: 'abandoned'}`, then `frames` with `drawn == session.frameCount`; party_host — the signal
  fired exactly once, `view_end` abandoned, `GamesScreen` back; phone — 31 s hidden (over the 30 s grace),
  the signal fired exactly once, `PuzzleScreen` gone and `GamesScreen` shown, the host still live.

## Deviations

1. **`PhoneHost.live(..., {int Function()? nowMs})`** is the 31 s test's seam: it moves the presence's
   clock, not the widget's. The app passes nothing and gets the real, monotonic clock.
2. **`PhoneHost.away`** and the `hostAwayProvider` override in `phoneHostOverrides`: without it nothing
   pauses the game while the phone is hidden (the TV's default never goes away).
3. **The lifecycle guard covers both screens** (`_hosting || hostingProvider.live`), one line, one comment:
   plan §6's table places it on the controller screen below the route, which is a *different* widget.
4. **`ConnectScreen` ignores connects while hosting.** The own player's welcome arrives after the sheet, so
   the listener would pop the Connect screen under the host route.
5. **`gameShownProvider` moved from the host route to `HostingNotifier.start`/`stop`.** Riverpod 3 throws
   "Tried to modify a provider while the widget tree was building" from `dispose`; the notifier is the
   right owner (start before the route opens, stop before it pops).
6. **`FakeDiscovery.stops`** (plan §10 asks for it) and an `advertiser:` parameter on `pumpHostApp`, so a
   test can read what advertising did.
7. **`hosting_test.dart`'s throwing read** is asserted by message, not type: Riverpod 3.4.3 wraps a
   provider's build error in a `ProviderException` that `flutter_riverpod` does not export; the message
   still contains `'No host is running in this app'`.
8. **The join flow needs a bigger window in tests.** At 852×393 the host's screens get a 341-high body and
   `join_screen_widgets.dart`'s `_SidePanel` overflows by 59 px (two bars: the app's 52 and the party app
   bar's 56), so the two tests that press A through the join screen run at 1024×720 with a comment. This is
   a widget-test overflow on a landscape phone, not a layout the app can't draw — but it is the plan's Q6
   (two bars) showing up as a number.
9. **`abandonRound` is also what the pause menu's Quit calls** (`leaveForGamePicker` delegates to it), so
   Quit now fires the signal as well and its round ends `round_end {reason: abandoned}` / view `abandoned`
   rather than `quit`. No existing test asserted Quit's records (the `quit` view end is asserted through a
   direct `dispose()`), so nothing changed value; see Q1.
10. **`abandon_signal.dart` had been written in an earlier slice**; it is now exported from
    `party_host.dart` and covered by `abandon_test.dart`.
11. **`git status` lists `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
    `generated_plugins.cmake` as modified, with an empty `git diff`** — line endings only (LF/CRLF), from a
    `flutter pub get`/build outside this job's edits. No content changed, and I changed no file outside the
    allow list.

## Questions for Claude

1. **Quit and abandoned.** `leaveForGamePicker` (Quit in the pause menu) now fires the abandon signal, so a
   quit records `round_end {reason: abandoned}` (no winner) and ends the view `abandoned`. Is quitting the
   same thing as the host losing the round, or should Quit keep its own `quit` end and only the presence's
   abandon fire the signal? (Nothing asserted the old records, so this is a semantics question, not a
   broken test.)
2. **The join screen on a landscape phone.** Two bars cost 108 px, and `_SidePanel` does not fit the rest.
   Should the host route hide the app's bar while a game's screen is up (the TV has no second bar), or
   should the join screen scroll/shrink? The tests work around it with 1024×720.
3. **`resume()` and advertising.** The S3 test sees `FakeAdvertiser.starts` grow because the fake's status
   stays `starting`. On a device whose advertiser still reports `advertising`, `shown()` will not restart
   it. Is that the intent (only restart what the system stopped), and should the fake emit
   `advertising` in a later test to pin the other branch?

## Commit message

Phone hosts a game: the own player's pad, C34, Stop hosting, lifecycle, abandoned rounds

Q-A: clientProvider watches the host's own client first, set by HostingNotifier.start
and cleared by stop; the host route's nested scope is dropped, and the chip's badge
goes back to clientStateProvider. The Connect screen ignores a connect while hosting.
"Show on this device" (C34) shows the game alone; Stop hosting (chip, system back)
disposes the host and resumes the search, and a second Host a game works.
The lifecycle pauses the round while hidden (hostAwayProvider from the phone) and
shows/re-advertises the host on resume, without restarting the search.
GameSession.abandon ends a view abandoned; PuzzleSession and ArenaSession record it
(round_end without a winner, the arena's frames too); the views take an abandon
listenable, the screens hand them hostAbandonProvider, and abandonRound fires it.
Tests: host_mode (steps 4-6, C34, stop, back), host_lifecycle, hosting (container),
connect cases, abandon in game_kit/puzzle/arena/party_host, and the 31 s hidden case.

## Status row

s5b G4: host mode complete (own player's pad, C34, Stop hosting, lifecycle, abandoned rounds), all checks green; step 5 ends here. OPEN: none — Q1 (Quit as abandoned) and Q2 (join screen vs two bars) are for Claude to rule on.

## Delete

- none

## Claude's review

- Q1: Quit is not abandoned. `leaveForGamePicker` pops without the signal again; only `abandonRound` (the host lost the round) fires it. Test added (`abandon_test.dart`: Quit ends the view `quit` and records no `round_end`).
- Q2: the join screen's sides scroll (`SingleChildScrollView` in `_SidePanel`), so a landscape phone's 341-high body fits; on a TV nothing changes. The two host tests run at the phone's 852×393 again. Step 7 decides the phone's bars.
- Q3: yes, `resume()` restarts only what the system stopped; no extra test.
