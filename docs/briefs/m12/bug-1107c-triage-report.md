# M12 bug triage — 1107c: a joined phone stuck on the waiting card with no way out

Read-only triage; no fix, and no file changed but this report. Read: `ui/{waiting_card,joined_view,connect_panels,
connect_screen,controller_screen,controller_top_bar,controller_parts,bar_connection,bar_modes,host_chip}.dart`,
`host/host_screen.dart`, `main.dart`, `host_grace.dart`, `providers/{connection,view,game_feedback}.dart`,
`client_connection.dart`, `controller_client.dart`, `client_controls.dart`, `game_host.dart`, `game_session.dart`
(`drawn`), `network.dart` (`CloseCodes`), `packages/party_host/.../host_presence.dart`,
`docs/design/m12-joined-view.md` §0.3, `m12.md` §2.10, `m12-phone-layout.md` §0.7, `joined_view_test.dart`,
`host_mode_test.dart`, `test/support/{pump_app,fakes}.dart`, `device-1107-session.txt`, `coding-guidelines.md`.
No test or app run: the brief's only `check:` is this report, and every finding below is reachable by reading.

## Q 1 — why there is no way out

**Cause** the controller is the app's only screen (`main.dart:42`) and the only route out of a joined game is the
top bar's connection chip, which the bar stops drawing over a game: `showsGameProvider` (`game_feedback.dart:52`)
is true from a `ViewStarted` until a `ViewEnded` (`view.dart:30-46`), and a dropped link sends neither
(`controller_client.dart:330` → `client_controls.dart:98-101`: layout and status only), so `_GameTopBar` stays
(`controller_top_bar.dart:21-23`) with a badge and a bare dot on its left (`bar_connection.dart:70-84`, `:80`).
- **chip → Connect screen** (`bar_connection.dart:32-45`; `connect_screen.dart:247-249`): **hidden** — the compact
  bar draws the dot instead (`controller_top_bar.dart:47`), and the dot has no `onPressed`.
- **mode menu** (`controller_top_bar.dart:50`; `bar_modes.dart:43-80`): **visible, nothing to leave with** (the
  three modes and the mode's tune dialog).
- **Connect screen's Stop / Disconnect** (`connect_panels.dart:129`, `:158`): **covered** — the screen is
  unreachable — and useless if reached: `disconnect()` (`connection.dart:163-166`) leaves the wait and the view
  alone (`view.dart:103-112`), and while connected it *creates* the 30 s card (`:106`).
- **back**: the controller is the root route (`main.dart:42`); the only `PopScope` is the host route's
  (`host_screen.dart:58-61`); Android's back closes the app (reopening reconnects), iOS has none.
- **card** (`waiting_card.dart:47-67`): two `Text`s, no button; **Settings/Diagnostics**: no connection control.
**TV host** not stuck: no view, so no compact bar and no wait (`view.dart:106`), and Connect → Stop works; the dev TV's `SHARE_VIEW` traps a phone the same way. **Confidence** sure; the owner's words are the card's own (`waiting_card.dart:55`, `:59`), which only this state shows.

## Q 2 — how long the card stays

**Cause** `hostWaitProvider` (`view.dart:63-113`) is `_away ?? _dropped` (`:112`) and only four things move them:
`HostBack` (`:87`), `ViewStarted` (`:89-92`), `ViewEnded` (`:93-96`), a connected snapshot (`:104-105`, the drop
only) or a new client (`:73-80`). Nothing ends the wait by time: there is no timer in the notifier, the card's 1 s
`Timer` (`waiting_card.dart:32`) only repaints, and at 0 the card keeps its words (`:59`). A `host_away` with no
`host_back` therefore lasts until the next `view_start`/`view_end` — a resumed round that keeps the same view sends
neither, so it is cleared only if the phone rejoins and gets a `view_start` (`view.dart:89-92`). The drop wait is
worse: after reconnecting the link clears it (`:104-105`), but the *game* stays on screen for ever, because
`ViewEnded` never comes.
**Reconnect** never gives up: `_scheduleRetry` takes `retryDelays.last` = 3 s for ever (`controller_client.dart:
32-38`, `:61`, `:293-304`), `_onConnectFailed` keeps rescheduling while `everPaired` (`client_connection.dart:
150-165`), and `_giveUp` runs only for close codes 4000/4002/4003/4005 (`:173-196`). The owner's attempts 2–9 every
3 s are that rule; the attempt counter and Diagnostics' "Reconnect attempt N" grow without a bound.
**Confidence** sure. Proves it: the card the owner saw at 18:10 is the 17:48:18 drop's, `left` = 30 − 269 ≈ negative,
and no state change after 17:52:47 could retire it.

## Q 3 — the timeline

**Answer** 17:48:16 `[discovery] Restarting discovery` with no client line is the **app coming back to the
foreground** (`controller_screen.dart:80-89`): discovery restarts (`:83`), then `client.resume()` (`:87`), whose
only logs are "Back after X s…" (`client_connection.dart:143`) and "App resumed…" (`controller_client.dart:251`),
so silence means `connected` and heard from less than `heartbeatTimeout / 2` = 2 s ago (`:140-146`): a live socket.
The **code 1002** at 17:48:18 is no app code (`CloseCodes`, `network.dart:22-43`: 1000/1001/4000-4005), so it is
what the iPhone's socket reported when iOS took the link down; sure the app was **suspended, not killed** (the same
process answered as attempts 2–9), **unsure** why (lock, another app, or the network).
**Why not until 17:52:47**: the 1 s heartbeat `Timer` (`controller_client.dart:30`) doesn't run while iOS suspends
the app, but `nowMs` is a `Stopwatch` (`:74`) that kept counting, so the first beat after the wake
(`client_connection.dart:199-213`) saw 270.5 s — last heard 17:48:16.5, 1.5 s before the 1002 — and the 4 s timeout
never ran. The `-65569` then is mDNSResponder's socket reset (bug 1107b Q3).
**4107 ms `received_to_drawn`** is the **host's** number, not the phone's: `GameSession.drawn()`
(`game_session.dart:197-206`) reports `host.nowMs − inputArrivedAtMs` when the host's own screen paints the frame
(ticks over `stallS` 100 ms are skipped, `:47`, `:199`), so the host's drawing stopped ~4.1 s; the phone's own
numbers are small (jitter max 31, touch p95 51). **Unsure** it is the same moment: it fits the host's phone going
away inside the 40 s session, but no `host_away` line dates it.

## Q 4 — the fix

**Fix** (the owner's design, to this code).
- **Leave game on the card** (`waiting_card.dart:47-67`, `Key('leaveGame')`, `TextButton` then `FilledButton`): a new
  `ConnectionActions.leaveGame()` (`providers/connection.dart:157-166`) runs `_client.disconnect()` **without** `_store.lastHost = null`
  (tokens survive either way; `lastHost` is "remember the TV", `storage.dart:88-102`), then `openConnect(context)` (`connect_screen.dart:247`).
- **Leaving ends the view and the wait**: an `idle` client sets `ViewActiveNotifier` false (`view.dart:27-46`) and clears `_away`, `_dropped`, `_hasView`
  (`:103-110`); `idle` comes only from `disconnect()` (`controller_client.dart:263`) and the constructor (`:84`): it means "the player left", and it fixes Stop too.
- **Two states** (`waiting_card.dart:42-69`): `left = secondsLeft − elapsedS` from `wait.sinceMs` (`:44-46`); at `left <= 0` — or, with no number,
  `elapsedS >= hostGraceS` (`host_grace.dart:6`) — the title is **The host has left**, the line "You can keep waiting, or leave.", and
  Leave game is the `FilledButton` (a null `secondsLeft` does not happen today, `view.dart:86`, `:107`).
- **The way out over a game, while the card is up** (`controller_top_bar.dart:47`, `bar_connection.dart:70-84`): **it should show** — while
  `hostWaitProvider` is non-null, draw the `ActionChip` of `bar_connection.dart:32-45` (tooltip, `openConnect`) in the dot's place: one branch in `_GameTopBar`.
**Conflicts** `m12-joined-view.md` §0.3 rule 3, "At 0 it keeps the text without a number", and its test (`joined_view_test.dart:345-352`);
§0.3 gains "a disconnected client ends the wait and the view".
**Tests first** (`joined_view_test.dart`, "waiting for the host"; `joined()` leaves `nowMs` 1000): 1. tap `leaveGame` → `calls` has `'disconnect'`,
`ConnectScreen` shows; `idle` → no card, no `arena`, chip back, `lastHost` saved. 2. a drop at 1000, `nowMs = 31000`, `pump(1 s)` → `elapsedS` 30,
`left` 0 → **The host has left** and the line, `FilledButton` 'Leave game' (today "The host may have left", `:59`). 3. `connected` still clears
a card that said it left (`:354-367`). 4. `idle` on `joined()` → no card, no `arena`, full bar (three failures today).
**Risk** `idle` also ends a shown game for "Try without a TV"; `FakeClient` emits no idle snapshot (`fakes.dart:63`), so existing tests keep
their meaning; the compact-bar tests `:200-235`, `:287-310` change if the dot becomes a chip.

## Files changed

- `docs/briefs/m12/bug-1107c-triage-report.md` — new: this triage.

## Checks

- None run but reading: the brief's only `check:` is this report. No `flutter test`, no app, no git command.

## Questions

1. Leave game "as the Connect screen's Stop does today (the saved pairing stays)": today's Stop also forgets
   `lastHost` (`connection.dart:164`). Keep the pairing in the card's leave only, or make both keep it?
2. `host_away(120)`: should "The host has left" wait for that countdown's 0, or also appear after 30 s without a
   `host_back`? Today `HostPresence` sends `graceS` = 30, so the two coincide.
3. For Q 4's fourth bullet: the chip in the compact bar only while a wait is up, or in every over-a-game state (a
   live game with no way out but Stop)?
4. Was the host's phone screen off in the second or two before 17:48:18? The 4107 ms needs its drawing stopped for
   ~4.1 s, and the log has no `host_away` to date it.

## Suggestions (not acted on)

- Log the wait's start and end on the phone (`'Waiting: host away 30 s'` / `'Waiting: link dropped'` and the clear),
  so the next report says which of §0.3's two paths was in play; today's log has neither.
- `_followTheTv` restarts discovery every 4th attempt (`controller_screen.dart:103-107`), i.e. every ~12 s at 3 s
  delays; each restart drops the mDNS socket and could be the source of the 17:52:47 `-65569` rather than the wake.
  Worth a look as its own bug if the error repeats (unsure).
- `HostWait.secondsLeft`'s null branch (`view.dart:51`, `waiting_card.dart:56`) is unreachable today: either give it
  a caller or drop it when the card is touched.

## Commit message

```
docs(m12): triage the joined phone's no-way-out waiting card

A dropped host leaves viewActiveProvider true, so the compact top bar
draws a dot with no button instead of the connection chip; the Connect
screen's Stop is unreachable and, if reached, leaves the card and the
view up (hostWait is only cleared by host_back, view_start, view_end or
a reconnected link). Reconnects never give up and the card never ends.
Fix: Leave game on the card (keeps the pairing), an idle client ends the
view and the wait, "The host has left" at 0, and the chip back over a
game while the card is up. Open: whether Stop keeps the pairing.
```

## Status row

| Bug triage 1107c | G0 survey done ([bug-1107c-triage-report.md](bug-1107c-triage-report.md)): a dropped host leaves `viewActiveProvider` true (`view.dart:30-46`; `client_controls.dart:98-101` emits no `ViewEnded`), so the compact bar (`controller_top_bar.dart:21,47`) draws a dot with no `onPressed` (`bar_connection.dart:80`) where the connection chip should be; the Connect screen is unreachable and its Stop (`connect_panels.dart:129`) clears neither the wait (`view.dart:103-112`) nor the view; the card never ends by time and the reconnect retries 3 s for ever. Only a phone that shows a game is trapped (a TV sends no view). Fix proposed: Leave game on the card (keeps the pairing), an idle client ends view and wait, "The host has left" at 0/after the 30 s grace, the chip back over a game while the card is up. Open: whether Stop keeps the pairing, the long-countdown rule, and the chip's scope |

## Delete

- none
