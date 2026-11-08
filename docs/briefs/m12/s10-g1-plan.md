# m12 s10 G1 — plan: the host phone's pad shows only during a round

Read-only plan; this file is the only change, no code and no check run. The contract is [m12-host-touch.md](../../design/m12-host-touch.md) (owner, Nov 7): its rules 1–6 replace m12.md §2.6's "the host phone's owner can use either" for the host phone's own pad. Paths below are from the repo root.

## 1. How the host phone knows a round is running, and paused

| candidate | what it says | verdict |
| --- | --- | --- |
| the own player's view state (`viewActiveProvider`, [view.dart:25](../../../controller_app/lib/src/providers/view.dart)) | `view_start`/`view_end` | **no.** The own player pairs *without* `Capability.view` ([hosting.dart:71-76](../../../controller_app/lib/src/host/hosting.dart)), so it never gets a view at all. Even for a viewer a view spans the screen, not the round: it stays on at the results and sends nothing while paused |
| a route check on `HostGames`' navigator ([host_games.dart:14](../../../controller_app/lib/src/host/host_games.dart)) | which screen is on top | **no.** Silent about paused (menu, away card, host away), and the app would have to observe a navigator `party_host` raises |
| `Pausable` ([pause_menu.dart:36-141](../../../packages/party_host/lib/src/ui/pause_menu.dart)) | mounted only inside a round (both games: puzzle_screen.dart:170, game_screen.dart:117) and it already owns `paused` | **chosen**: the one place that is up exactly while a round is on and knows the menu, the host-away pause and, after 1107d B, the away players |

**The state.** New `packages/party_host/lib/src/ui/round_phase.dart` (~45 lines), exported: `enum RoundPhase { none, ready, playing }` (`none` = the picker, levels, join, results, and a stopped round: pause menu, away card, host away), `RoundPhaseSignal extends ValueNotifier<RoundPhase>`, and `roundPhaseProvider` (a `Provider`, disposed with the scope). `Pausable` writes it from one `_publish()` that reads a single `_stopped` getter (`!enabled || _pausedBy != null || away.value`), called from `initState`, `didUpdateWidget`, the away listener, the beat's timer, `_pause` and its dialog's pop, and `dispose` — a plain object, so s5b's "Riverpod refuses a provider change from a widget's `dispose`" ([hosting.dart:26-28](../../../controller_app/lib/src/host/hosting.dart)) does not apply. It is the `controlsClaimsProvider`/`hostAwayProvider` pattern, not a `NotifierProvider`, for that reason. A single `_stopped` getter is what makes 1107d B's `playersAwayProvider` hide the pad for the away card with one line.

## 2. The pad: not built; the neutral input; the bar

| phase | pad | top bar | the own player's client |
| --- | --- | --- | --- |
| `none` (picker, levels, join, results, pause menu, away card, host away) | not built | full | one neutral `input`, then silence |
| `ready` (the Get ready beat, §3) | up | compact | the pads' presses (a press lands at step 0) |
| `playing` | up | compact | the pads' presses |

- **Hidden by not building it.** `_Controls` ([controller_parts.dart:20-41](../../../controller_app/lib/src/ui/controller_parts.dart)) returns `SizedBox.shrink()` when this phone hosts (`widget.background != null`) and the phase is `none`; the `controls` flag (C34) and a joined phone (no background) keep today's pad, so rule 6 holds. A built-but-transparent pad would keep the held finger's pointer route: its release arrives after the round, and the button stays pressed in `PadTracker` meanwhile. Not building it removes the hit test; the app then calls `padProvider.releaseAll()` ([pad.dart:50-54](../../../controller_app/lib/src/providers/pad.dart)), which sends **one** neutral `input` (buttons empty, `dx/dy 0`) through `_send` ([pad.dart:136-144](../../../controller_app/lib/src/providers/pad.dart)) and nothing more. The host's `minPressMs` = 50 ms ([server_game_host.dart:34](../../../packages/connection/lib/src/server_game_host.dart)) can keep a held button up to 50 ms longer, as any release does.
- **Where the transition is handled.** `_ControllerScreenState` adds and removes a listener on `roundPhaseProvider` in `initState`/`dispose` (a plain object, so both are legal) and calls `releaseAll()` there — the same call the lifecycle makes ([controller_screen.dart:95](../../../controller_app/lib/src/ui/controller_screen.dart)). It also pauses gyro mode with the existing `gyroProvider.pause()/resume()` ([gyro.dart:259-274](../../../controller_app/lib/src/gyro.dart)), whose doc comment widens to "the pad is hidden"; gyro is the only source that sends by itself ([gyro.dart:308-323](../../../controller_app/lib/src/gyro.dart)). D-pad and sticks only send on touches, so they need nothing.
- **The bar.** `_TopBar` ([controller_top_bar.dart:21-23](../../../controller_app/lib/src/ui/controller_top_bar.dart)) picks compact vs full from the phase when it is on the host route, not from `showsGameProvider` (which is true for the whole host life, [hosting.dart:28](../../../controller_app/lib/src/host/hosting.dart)): full over the picker, the levels, the join, the results, the pause menu and the away card (rule 1), compact over the round (rule 2, unchanged over a round). The status panel keeps keying off `showsGameProvider` ([bar_connection.dart:24](../../../controller_app/lib/src/ui/bar_connection.dart)); that is not this job. Both widgets read the phase with `ValueListenableBuilder`, as `Pausable` reads `away`. "Show on this device" (C34) has no pad but follows the same bar rule, so its picker goes full (today compact); see question 2.

## 3. "Get ready" (rule 3)

**Today there is no countdown.** `GameSession.advance` steps on its first frame ([game_session.dart:171-195](../../../packages/game_kit/lib/src/game_session.dart)) and `Pausable.startGrace` = 500 ms only ignores Start ([pause_menu.dart:46](../../../packages/party_host/lib/src/ui/pause_menu.dart)).

**Pick (A).** `Pausable` holds the round `paused` for `readyCountdown` — a `Provider<Duration>` in party_host, default `Duration.zero`; the phone app overrides it with `RoundStart.readyS` = 3 s in [host_overrides.dart](../../../controller_app/lib/src/host/host_overrides.dart) (3 s is my guess; the owner named no length, unsure). While it runs, the builder gets `paused: true`, so **no steps run** (3 s = 1800 ms = **180 steps of 1/60 s** not run; the puzzle's `timeLeftMs` is unchanged) and the phase is `ready`, so the pad is up. New `ui/ready_card.dart` (~60 lines, `Key('getReady')`) draws over the game: "Get ready · 3", "· 2", "· 1", a 1 s `Timer` it cancels in `dispose`. Both games get it because both build `Pausable`; the TV's default is zero, so the TV and its phones are unchanged (rule 6). Start during the beat opens the pause menu as today (question 3).

| where | who sees it | cost |
| --- | --- | --- |
| **A. `Pausable`, the session paused (pick)** | the host phone | `view_start` has gone out, so the joined phones draw nothing for 3 s ([frame_view.dart:26-29](../../../packages/game_kit/lib/src/frame_view.dart) waits for the first frame): 180 frames at 60 Hz |
| **B/C, not chosen**: build the game after the beat, or a start delay in `GameSession` | B: the host phone only, joined phones keep their last screen; C: everyone | B restructures both screens and splits the phase's writer; C is a protocol/game_kit change (a frame or setup field) that reaches the TV unless the setting is 0 there (rule 6) |

## 4. Rule 5: the own player joins by itself

- **Today.** The own player pairs when the host starts ([phone_host.dart:96-105](../../../controller_app/lib/src/host/phone_host.dart)) but is not on a side: it must press **A** on the pad ([join_screen.dart:176-186](../../../packages/party_host/lib/src/ui/join_screen.dart)) and push **left/right** (:187-192). `host_mode_test.dart:78-86` does exactly that. Start is a touch `HostButton` (:110) but `_start` needs a non-empty `_teams` (:223).
- **Change.** In `_tick`, beside `_simulatedJoin` (:149), the own player (`ownPlayerIdProvider`, [providers.dart:83-87](../../../packages/party_host/lib/src/providers.dart), which the phone app overrides) goes to `sideForNewPlayer(_teams)` (:37-44) whenever it is connected and has no side — so a reconnect, or a return from away, re-joins too. Each `_SidePanel` ([join_screen_widgets.dart:4-51](../../../packages/party_host/lib/src/ui/join_screen_widgets.dart)) becomes tappable and moves the own player there when that side has room (`maxPerSide` = 2, join_screen.dart:33), marked as the own player's. The hint (:272-278) gains "Tap a side to play; press A on a phone to join".
- **Must not change.** The **TV**: `ownPlayerIdProvider` is null there, so no auto-join, and the keyboard player still joins with Space. The **joined phones**: A, left/right, Start and B and their layouts are untouched; A after joining still starts the match (:176-186). A rematch ("Change teams") carries the sides ([puzzle_screen.dart:140](../../../packages/party_host/lib/src/ui/puzzle_screen.dart)), and the auto-join only fills a missing side, so it never overrides a choice.

## 5. Touch everywhere the pad used to drive

| screen (rule) | pad/remote-only today | touch equivalent |
| --- | --- | --- |
| game picker, level list ([games_screen.dart:28,37,45,57,163-175](../../../packages/party_host/lib/src/ui/games_screen.dart)) | none: cards and `HostButton`s are touch | — |
| join screen (rule 1, 5) | A joins (:176-186), ←/→ pick a side (:187-192), B leaves/back (:193-200), Start only once joined (:201-206) | s10b: auto-join on entry + tap a side; Start/Back already touch (:110, :118) |
| results, puzzle settings, app settings ([puzzle_screen_widgets.dart:149,157,159](../../../packages/party_host/lib/src/ui/puzzle_screen_widgets.dart), [puzzle_settings_screen.dart:53,67,76,147](../../../packages/party_host/lib/src/ui/puzzle_settings_screen.dart), opened by [controller_top_bar.dart:94](../../../controller_app/lib/src/ui/controller_top_bar.dart)) | none: `HostButton`s, a switch, sliders | — |
| pause menu (rule 4) | opening it: Start on the pad ([pause_menu.dart:98-110](../../../packages/party_host/lib/src/ui/pause_menu.dart)) | Start is a touch target on the pad; Resume/Quit touch (:188, :194) |
| Arena ([game_screen.dart:81-84,108](../../../packages/party_host/lib/src/ui/game_screen.dart)) | "Back: leave" is the remote's Back | tap Start on the pad, then Quit ([pause_menu.dart:188-193](../../../packages/party_host/lib/src/ui/pause_menu.dart)), which leaves for the picker (:130, `leaveForGamePicker` :145-146) |
| away card (1107d B), host-away pause ([host_presence.dart](../../../packages/party_host/lib/src/host_presence.dart)) | none: the card's buttons are `HostButton`s; the host-away pause has nothing to press | — |

Not in this job: the debug overlay's OK/D ([game_screen.dart:74-88](../../../packages/party_host/lib/src/ui/game_screen.dart)) is a dev tool, and the joined phones keep `ControllerMenus` (rule 6).

## 6. The jobs (gated, smallest first)

**1107d B comes first for s10a and s10c**: both rewrite `Pausable` in `pause_menu.dart`, the file B is changing (`playersAwayProvider`), and the away card's pause must reach the phase. s10b touches `join_screen*.dart` only, which B does not change, but it shares `host_mode_test.dart` with s10a, so the order is B → s10a → s10b → s10c.

| job | gate | files | tests first | risks |
| --- | --- | --- | --- | --- |
| **s10a** the phase, the hidden pad, the bar | G3 | party_host: new `ui/round_phase.dart`, `ui/pause_menu.dart`, `party_host.dart`; app: `ui/controller_parts.dart`, `ui/controller_top_bar.dart`, `ui/controller_screen.dart`; tests: party_host `pause_menu_test.dart`, app `host_mode_test.dart`, `host_lifecycle_test.dart` | phase `none` on the picker, join, results and pause menu, `playing` in a round and after Resume; no pad widget outside a round and the pad back in it; one neutral input on hide and no button left held (a fake client counts `sendInput`); full bar over the picker, compact over the round | `host_mode_test`'s solo Shape Race works the picker and the join with `pressA` — those steps become taps; the compact-bar expectations flip (host_mode_test:50-54, 128-149; host_lifecycle_test:63-65); the app's tests without a host are untouched because the gate needs a background |
| **s10b** the join screen | G4 | `ui/join_screen.dart`, `ui/join_screen_widgets.dart`; tests `join_screen_test.dart`, app `host_mode_test.dart` | the own player is on the left on entry; tapping the right moves it and the format text follows; a full side refuses it; `ownPlayerIdProvider` null (a TV) changes nothing; a player back from away re-joins | the harness needs the override; `join_screen.dart` 305 → ~340 lines (limit 400); "Nobody has joined yet" becomes unreachable on the phone |
| **s10c** the Get ready beat | G3 | new `ui/ready_card.dart`, `ui/pause_menu.dart`, `ui/round_phase.dart`; app `host/host_overrides.dart` | 3 s of card (3, 2, 1) and no step run (the puzzle's clock unchanged over 180 frames); the phase is `ready` then `playing`; zero → no card and the first frame steps at once (the TV) | the joined phones' 3 blank seconds; the length is a guess |

## 7. Questions, and what I did not do

1. Is 3 s the beat (rule 3)? I picked it with no owner's number. **unsure**
2. Does rule 1's full bar apply in "Show on this device" too (its picker goes full, its round compact)? I read "Play on this phone" literally and applied it to both host routes.
3. Start during the beat: today it opens the pause menu 500 ms in. Leave it, or ignore Start until the beat ends?
4. Tapping a side moves only the host's own player, never another phone's. Confirm.
5. Suggestion, not acted on: m12.md §2.6 (:86) still says the host's owner "can use either"; a later docs job should point it at m12-host-touch.md, and rule 1's "settings" should name the screens (the app's and "Puzzle settings").

## Files changed and checks

- `docs/briefs/m12/s10-g1-plan.md` — new: this plan. No check was run: a plan changes no code and the brief names none. Line numbers and keys were read from the worktree today.

## Commit message

```
docs(m12): plan the host phone's pad only during a round

The round's phase comes from Pausable (up exactly while a round is on,
and it owns paused), as a ValueNotifier in a Provider so dispose can
clear it; the pad is not built outside a round, the app releases it and
pauses gyro so the own player sends one neutral input, and the top bar
goes full. A 3 s Get ready beat holds the session paused; the own
player joins by itself and a tap picks its side. Jobs after 1107d B:
s10a, s10b, s10c.
```

## Status row

| Step 10 host touch G1 plan | Plan done ([s10-g1-plan.md](s10-g1-plan.md)): the round's phase is `RoundPhase {none, ready, playing}` from `Pausable`, the pad is not built outside a round (one neutral input, gyro paused) and the bar goes full, a 3 s Get ready beat holds the session paused, and the own player joins by itself with a tap picking its side; three jobs, s10a/s10c after 1107d B. Open: Claude's answers to four questions |

## Delete

- none

## Claude's answers (Nov 7)

1. 3 s, yes. But the joined phones must not go blank: s10c publishes the round's first frame (step 0, nothing stepped) before the beat holds the session, so every phone sees the board during "Get ready".
2. Yes: the full bar over the menus on both host routes, the compact one over a round.
3. Start is ignored during the beat.
4. Confirmed: a tap moves only the host's own player.
5. Yes, after s10c: m12.md §2.6 points at m12-host-touch.md and rule 1 names the screens.

Order: 1107d B → s10a → s10b → s10c.
