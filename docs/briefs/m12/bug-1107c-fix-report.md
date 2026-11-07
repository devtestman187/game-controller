# M12 bug 1107c fix — G4 report: a joined phone can always leave a game, and its waiting card tells the truth

Done at G4, the gate the brief names. No file outside `allow:` was edited (see "Not sure" 7 for three
`tv_test_app/windows` generated files that the Flutter tool's pub get touched while the checks ran).

The brief's six do-items, in order: (1) an `idle` client ends the view and the wait; (2) Leave game on the card;
(3) the card's two kinds; (4) a finished round can't stay on screen after a reconnect; (5) the compact bar's dot is a
button to the Connect screen; (6) `m12-joined-view.md` §0.3. All six are in, with the tests the brief lists.

## Files changed

- `controller_app/lib/src/providers/view.dart` (190 lines) — items 1 and the view half of 4.
  `typedef HostWait` is now `({HostWaitKind kind, int? secondsLeft, int sinceMs})`, with
  `enum HostWaitKind { hostAway, dropped }`. `ViewActiveNotifier` adds
  `ref.listen(clientStateProvider, (_, next) { if (!next.isConnected) state = false; })`: any not-connected client
  (`reconnecting`, `failed`, `idle`) ends the view. `HostWaitNotifier._onClientState` clears `_away`, `_dropped` and
  `_hasView` on an `idle` client, records a wait on the first not-connected snapshot after a view
  (`kind: dropped, secondsLeft: null, sinceMs: client.nowMs`) and clears `_dropped` when the link is back; `_publish`
  and the unit-typed `_away`/`_dropped` fields are unchanged otherwise. Doc comments cite §0.3 and 1107d Q3.
- `controller_app/lib/src/ui/waiting_card.dart` (98 lines) — items 2 and 3. `build` derives
  `hostLeft = secondsLeft == null ? elapsedS >= hostGraceS : left <= 0`, then the title (`The host has left`, or by
  kind `Waiting for the host to come back` / `Reconnecting to the game…`) and one line (`You can keep waiting, or
  leave.` / `The game goes on if they're back in N s` / none for a drop); the button is `FilledButton` when
  `hostLeft` and `TextButton` otherwise, both `Key('leaveGame')`, labelled "Leave game". `_leave()` calls
  `connectionActionsProvider.disconnect()` and `openConnect(context)`.
- `controller_app/lib/src/ui/joined_view.dart` (91 lines) — the card left this file (item 2's placement, below) and
  `Visibility` is now `visible: viewActive || hostWait != null`, so the last frame stays drawn under the card
  (item 4). Size 89 → 91 lines.
- `controller_app/lib/src/ui/controller_parts.dart` (136 lines) — new private `_WaitingOverlay`
  (`ConsumerWidget`: `WaitingCard(wait)` or `SizedBox.shrink()`), documented as drawn over the pad so Leave game can
  be tapped.
- `controller_app/lib/src/ui/controller_screen.dart` (203 lines) — imports `waiting_card.dart` and adds
  `const Positioned.fill(child: _WaitingOverlay())` as the last child of the controls stack, above
  `AbandonedNotice`.
- `controller_app/lib/src/ui/bar_connection.dart` (135 lines) — item 5. `CompactConnection` draws
  `IconButton(key: Key('connectionButton'), tooltip: 'Connection', icon: ConnectionDot(key: Key('connectionDot')),
  onPressed: () => openConnect(context))`: same look, a 48 dp target from the Material defaults, and the dot keeps its
  key, so the existing opacity tests still find it. `controller_top_bar.dart` needed no change: it only wraps
  `CompactConnection` in `Opacity`, no pointer blocker, and the tap test passes through it.
- `controller_app/lib/src/providers/game_feedback.dart` (105 lines) — `showsGameProvider` is now
  `gameShown || viewActive || hostWaitProvider != null`, so the compact bar, the controls' opacity and the hidden
  status panel stay as they were while the card is up (the view has just ended by item 4, and Q3 wants the bar
  compact over a game at all times). Doc updated.
- `controller_app/test/support/joined.dart` — new (50 lines): `arena`, `arenaStart()`, `arenaFrame()`,
  `layerOpacity()` and `joined()` moved unchanged out of `joined_view_test.dart`, since a second test file needs
  them. `joined()` leaves `client.nowMs` at 1000.
- `controller_app/test/waiting_card_test.dart` — new (175 lines, 10 tests): the waiting-card group.
- `controller_app/test/joined_view_test.dart` (313 lines, 15 tests, 408 lines before) — the moved fixtures and the
  waiting group left; one test added (the dot), and no expectation in the tests it kept changed.
- `controller_app/test/controller_screen_test.dart` (97 lines, 5 tests) — one test added (1107d Q 4 (a)).
- `docs/design/m12-joined-view.md` — item 6: §0.3 rule 3's phone bullet replaced ("keeps the text without a
  number" is gone; the two kinds, "The host has left", the Leave game button and its two states, the idle rule, the
  dot button), plus the §5 `JoinedView` bullet (last frame under the card; the card is drawn by `ControllerScreen`).
- `docs/briefs/m12/bug-1107c-fix-report.md` — this report.

No change in `packages/` was needed. No lib file is over 400 lines (largest touched: `controller_screen.dart` 203).

## What the phone does now

- **Host away** (`host_away`): card over the game, "Waiting for the host to come back" + "The game goes on if they're
  back in N s", counting from the message's arrival on the phone's clock, Leave game a `TextButton`. At 0 (any `s`,
  Q2): "The host has left" + "You can keep waiting, or leave.", `FilledButton`.
- **Link dropped over a game**: "Reconnecting to the game…" with no number and no countdown, over the last frame
  drawn; after `hostGraceS` (30) of the phone's clock: "The host has left" as above. It never says "Waiting for the
  host" for its own sleep any more.
- **Link back**: the card goes. The view is off the screen (it ended at the drop), so a round that ended meanwhile
  stays off; a round that still runs comes back on the host's re-sent `view_start` (+ its latest frame).
- **Leave game** (any time the card is up): `disconnect()`, `lastHost` forgotten, pairing tokens kept (Q1), then the
  Connect screen opens. It works while the countdown runs and after the host has left.
- **Stop** (Connect screen) over a game, or a client that goes `idle` for any other reason: the view and the wait end,
  the full bar and the fully opaque controls are back. `failed` ends the view too and leaves the card up to its grace.
- **Over a game at any other time**: the compact bar's dot is a 48 dp button (tooltip "Connection") to the Connect
  screen.

## The mechanism picked for item 4, and the order found

Picked: **end the view on any not-connected client**, keep the last frame on screen while a wait is up, and let the
host's re-sent `view_start` bring a running round back. It is the smallest change with no edge cases: there is no
"view that is not running but must remember it might come back", and the re-show needs no timer, because the phone
already waits for `view_start` when it starts a view. I chose "any not-connected" rather than "only `reconnecting`"
so a client that gives up (`failed`) can't leave a stale round on screen either.

The order (read from the code, then pinned by a test): on a reconnect the host sends the **pair result first** and the
view start **second**.

1. `HostConnection._accept` (`packages/connection/lib/src/host_connection.dart:347-369`) sends
   `PairResultMessage.accepted` (364) and `PlayerMessage` (365), then `_host.emit()` (368).
2. The phone sets `ClientStatus.connected` when it handles the pair result (`client_messages.dart:145-153`).
3. `_host.emit()` → the server's `changes` listener (`packages/connection/lib/src/server_game_host.dart:17`) →
   `_checkPlayers` (285) → the new player has had no layout, status or view → `_sendView(id)` (294), which sends the
   kept `ViewStartMessage` and its latest frame (302-307).

So the connected snapshot is always handled before any re-sent `view_start`, on the same socket in that order, and
ending the view at the connected snapshot is safe: the start that follows turns it back on. A round that ended sends
no start, so the view stays off. The test `a link that comes back with a view_start keeps the round on screen` enacts
exactly that order (`connected` first, then `viewStart`, then a frame); `a link that comes back without a view_start
leaves the finished round off the screen` enacts the other outcome.

## Computed test values

`hostGraceS` is 30 (`controller_app/lib/src/host_grace.dart`). `joined()` sets `client.nowMs = 1000` and draws the
first frame, so a wait that starts at `joined()` has `sinceMs` 1000; `elapsedS = (nowMs - sinceMs) ~/ 1000`.

| Test | Clock / messages | What is computed | Expected |
| --- | --- | --- | --- |
| an away host counts its round down | `hostAway(30)` at 1000; `nowMs += 5000` → 6000 | `elapsedS` 5, `left` 30−5 = 25 | "30 s" then "25 s"; `TextButton` Leave game; `hostBack` hides the card |
| a countdown that runs out | `hostAway(2)` at 1000; `nowMs += 3000` → 4000 | `elapsedS` 3, `left` 2−3 = −1 ≤ 0 | "The host has left", "You can keep waiting, or leave.", `FilledButton` |
| a dropped link | drop seen at `nowMs` 1000; +5000 → 6000, +24000 → 30000, +1000 → 31000 | `elapsedS` 5, 29, 30 | "Reconnecting to the game…" at 5 and 29 s (no number), "The host has left" at 30 s (`30 >= hostGraceS`) |
| reconnect with no `view_start` | drop, then `connected` | `_hasView` false, no start | card gone, `arena` gone, `connectionChip` (full bar) back |
| reconnect with `view_start` | drop, `connected`, `viewStart`, frame | new start ⇒ `viewActive` true | `arena` drawn, compact bar (`connectionButton`, no `connectionChip`) |
| host back after the grace | drop, +30000 → "The host has left", then `connected` | `_dropped` cleared | card gone |
| idle client | `hostAway(30)`, then `idle` | `_away`/`_dropped`/`_hasView` cleared, view false | card and arena gone, full bar, `layerOpacity` = `ControlsSettings.maxOpacity` |
| Leave game | `hostAway(30)`, tap `leaveGame` | `disconnect()` | `client.calls` contains `'disconnect'`, `prefs['lastHost']` null, `ConnectScreen` |
| the dot over a game | `joined()` | `IconButton` defaults | `Size(48, 48)`, tooltip "Connection", tap → `ConnectScreen` and "Connect to a TV" |
| 1107d Q4 (a) | `inactive` then `resumed` | — | `client.calls` contains `'resume'` after one pump |

The device-sized default (`852×393`) is `pumpApp`'s and unchanged.

## Tests: counts and every changed old → new

Counts (phone, `flutter test` in `controller_app`): **331 before → 338 after, +7**: +1 in `joined_view_test.dart` (the
dot), +5 new in the waiting group (no-start, with-start, after the grace, idle, Leave game), +1 in
`controller_screen_test.dart` (resume). Per file: `joined_view_test` 19 → 15 (5 moved, 1 added), `waiting_card_test`
new 10, `controller_screen_test` 4 → 5.

Changed expectations, old → new (all in the waiting group; it moved from `joined_view_test.dart` to
`waiting_card_test.dart`):

1. `joined_view_test.dart:345-352`, title `'a countdown that ran out says the host may have left'` →
   `'a countdown that runs out says the host has left, with a filled Leave game'`.
   `find.text('The host may have left')` → `find.text('The host has left')`, plus
   `find.text('You can keep waiting, or leave.')` and `find.widgetWithText(FilledButton, 'Leave game')`. This is the
   only removed user-facing string (`review.sh --strings`: 'The host may have left' removed).
2. `'a link that drops over a game counts the grace, and reconnecting clears it'` →
   `'a dropped link says it is reconnecting over the last frame, then the host has left'`.
   `find.text('The game goes on if they\'re back in 30 s')` at the drop → `find.text('Reconnecting to the game…')`,
   plus `find.text('Waiting for the host to come back')` finds nothing and `find.byKey(Key('arena'))` finds one.
   After `nowMs += 5000` (5 s in): `…'back in 25 s'` → `'Reconnecting to the game…'` and
   `find.textContaining('The game goes on')` finds nothing. The old first half also went to 29 s and 30 s now, where
   it expects "Reconnecting…" and then "The host has left" + the leave line + the `FilledButton` (the "reconnecting
   clears it" half of this test is now the two reconnect tests below).
3. `'an away host counts its round down once a second, and coming back hides the card'`: same strings, one
   expectation added (`find.widgetWithText(TextButton, 'Leave game')`, "the countdown still runs").
4. Moved unchanged: `'a phone with no game shown says nothing when its link drops'` (its
   `find.text('Waiting for the host to come back')` still finds nothing) and `'a new view clears the wait'`.
5. New: `'a link that comes back without a view_start leaves the finished round off the screen'`,
   `'a link that comes back with a view_start keeps the round on screen'`,
   `'a host that comes back after the grace takes the card away'`,
   `'an idle client ends the view and the wait: Stop and Leave game both work over a game'`,
   `'Leave game disconnects, forgets the last host and opens the Connect screen'`.

No other test in the repo changed: a grep over `controller_app/test`, `tv_test_app/test` and `packages/*/test` for the
card's texts and the keys I touched finds only `host_mode_test.dart` (twice) and `connect_screen_test.dart`, which use
`connectionDot` and `connectionChip` — both keys are kept, and they pass.

## Checks

- `tools/check.sh format analyze phone` — PASS format (2 s), PASS analyze (6 s), PASS phone (338 tests, 19 s), all
  checks passed.
- `tools/review.sh` — **0 fail, 1 note**: `number controller_app/lib/src/ui/waiting_card.dart:87` (the bare `8` that
  spaces the button, in line with the `4` above it and the file's existing spacing; spacing scale is tech debt).
- `tools/review.sh --strings` — 1 removed ('The host may have left'), 9 added: 'Connection', 'connectionButton',
  'The host has left', 'Reconnecting to the game…', 'You can keep waiting, or leave.', 'Leave game' and 'leaveGame'
  (twice, the two buttons). Nothing personal.
- I also ran `dart analyze --fatal-infos` in `controller_app` while working (no issues) and `flutter test` (338 pass).

## Not sure

1. **The card moved out of `JoinedView` into `ControllerScreen`.** With the card inside the game, a tap on Leave game
   landed on the pad's Start button (it sits in the same place) and no disconnect happened; the test caught it. The
   card is now a `Positioned.fill` over the controls, above `AbandonedNotice`, and it only takes the touches on the
   card itself — the game behind it is the frozen last frame. If the card should stay inside `JoinedView`, the button
   needs a different place (e.g. the bar), which is a design change.
2. **`showsGameProvider` now includes the wait**, so the compact bar (and the dot button) stays up while the card is,
   and the controls keep the game opacity. The alternative — the full bar coming back once "The host has left" — is a
   one-clause change, but the last frame is still behind the card, so I kept it compact.
3. **Leave game reuses `ConnectionActions.disconnect()`** (Q1: "exactly what Stop does"); there is no `leaveGame()`.
   The tokens staying is a property of `disconnect()`, not something I added; no test pins the tokens (the
   `FakeClient`'s pairings are a fixed map), only `lastHost` and the call.
4. **"The host has left" after a drop is a phone-side decision**: the phone runs `hostGraceS` from the moment it
   noticed the link, which is after it wakes (a suspended app's timers don't fire), so a phone that slept 40 s gives
   the host a fresh 30 s rather than saying it has left at once. That is the old code's grace and what Q2 asks for
   ("with no number after `hostGraceS`"); say if the sleep time should count instead.
5. **A `failed` client keeps the card up to the grace**, then says "The host has left" with Leave game. A version
   mismatch might deserve the Connect screen (with its "problem" text) sooner; I didn't add that, it isn't in the
   brief.
6. **A re-shown view needs an extra frame in tests** (the ticker of the re-shown `FrameView` restarts): the with-start
   test does `viewStart` → settle → `viewFrame` → settle. Not a product bug, but a test-timing note for whoever
   touches that test.
7. **Three `tv_test_app/windows` generated files show as modified in `git status`** (`generated_plugin_registrant.cc`,
   `.h`, `generated_plugins.cmake`). `git diff` lists no content change (line endings only); the Flutter tool's pub get
   did it during the checks, not me. I couldn't clean them (git commands that change files are off-limits).
8. **The pad is still live around the card, not under it.** `_WaitingOverlay` is a `Positioned.fill` with a plain
   `Center`, so taps off the card reach the controls beside it (which §0.3 rule 5 wants: inputs reach a paused host
   and are ignored), and taps on the card stay with the card. If Claude wants the whole screen blocked while waiting,
   an `AbsorbPointer` is the change.
9. **Suggestion, not acted on:** the card has no test at a small screen (667×375) where its three lines plus the button
   may crowd; `pumpApp`'s default is used.

## Commit message

fix(m12): a joined phone can always leave the game

An idle client (Stop, and the new Leave game) ended neither the view nor
the wait, and a drop left the phone saying "Waiting for the host". The
card now says which wait it is — "Reconnecting to the game…" with no
countdown for a drop — then "The host has left" with "You can keep
waiting, or leave."; Leave game is a TextButton while it counts and a
FilledButton after. A link that goes down ends the view, so a finished
round can't stay on screen, and the host's re-sent view_start brings a
running one back. Over a game the compact bar's dot opens Connect.

## Status row

| Bug fix 1107c | G4 done ([bug-1107c-fix-report.md](bug-1107c-fix-report.md)): Leave game on the waiting card (`TextButton` counting, `FilledButton` after), the card's two kinds ("Reconnecting to the game…" for a drop, "The host has left" at 0 or after `hostGraceS`), an idle client ends the view and the wait, a link that goes down ends the view so a finished round can't stay on screen (a running one returns with the host's `view_start`; pair result before the start, pinned by a test), the compact bar's dot is a 48 dp button to the Connect screen, §0.3 updated. Tests 331→338 (phone), checks pass, review 0 fail. Open: the owner confirms on the next build; 1107d Q 3's reconnect and Q 4 (a) are covered here, Q 4 (b)–(d) are not |

## Delete

- none
