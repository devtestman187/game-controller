# m12 bug 1107d G1 — plan: a dropped player pauses the round for up to 30 s, and can leave

Read-only plan; this report is the only file changed. From [bug-1107d-triage-report.md](bug-1107d-triage-report.md) and the owner's
decision (Nov 7): pause up to 30 s, and let the player leave. 1107c is running in `waiting_card.dart`, `providers/view.dart`,
`joined_view.dart` and friends: jobs A2 and C wait for it, A1 and B do not touch those files.

## 1. The host side: the grace, the pause, and what reads `players`

**The grace lives in `ServerGameHost`** ([server_game_host.dart:135-150, 285-298](../../../packages/connection/lib/src/server_game_host.dart)), the one place that already sees every pairing come and go (`server.changes`, :17).

- **Slot.** A dropped player stays in `players` with a new `GamePlayer.away` ([game_types.dart:6-50](../../../packages/connection/lib/src/game_types.dart)); number, name, place and held piece stay (`PuzzleGame.update` drops only ids missing from its inputs, [game.dart:231-237](../../../packages/puzzle_game/lib/src/game.dart)); `gamepad` is already neutral (:156-160), `inputArrivedAtMs`/`inputSeq` null, `haptic`/`askRating` already false.
- **Clock.** One one-shot `Timer` per away player (cancelled on return, on `goOnWithout`, in `dispose`), the seconds shown from `server.nowMs`: not "a `Timer` in a game". The grace is a constructor `Duration` (`awayGrace`, default 30 s = `hostGraceS`), so a test can use 200 ms. Simulated players get no slot (the pause menu ignores them anyway, pause_menu.dart:93; "Stop sims" must not pause a round); the number is safe, `markSeen`/`pickPlayer` keep it a minute ([host_pairings.dart:162,180](../../../packages/connection/lib/src/host_pairings.dart)).
- **Pause.** The host lock's pause, not a second one: a source beside `hostAwayProvider`, **`playersAwayProvider`** (party_host `providers.dart`, from `gameHost.playersChanged`), and `Pausable` builds `paused = menu || hidden || away.isNotEmpty` (pause_menu.dart:133-139) → `GameSession.paused` ([game_session.dart:150-159,171-195](../../../packages/game_kit/lib/src/game_session.dart)): no steps, no clock, no frames, and `_last` keeps up so the resume doesn't catch up; `_tick` won't open the Start menu while away (:86-89). Not in `GameSession`: that would be a second owner of "paused" and would have the rules read the roster for a screen state. The lock ends the round `abandoned` after 30 s; an away player's round **goes on without them**, 30 s after the host noticed (at once on a socket close, up to 4 s of silence), the phones counting from the message's arrival.
- **Readers of `players`:**

| reader | change |
| --- | --- |
| pause menu (pause_menu.dart:77-103) | filter `!p.away` for presses and for who may resume |
| controller menus (controller_menus.dart:143-159) | filter `!p.away`: no menu layout stored for a phone that isn't there (it would be re-sent on rejoin, over the game's) |
| join screen (join_screen.dart:118-148) | filter `!p.away`: a dropped phone is not listed for 30 s and its team is not kept |
| results (puzzle_screen_widgets.dart:45,100-107) | keep: they show who played |
| report ([puzzle_report.dart:28](../../../packages/puzzle_game/lib/src/puzzle_report.dart)) | keep: a player away at the last step keeps its `player_result` (today the leaver's numbers are lost) |
| live stats (live_stats.dart:164-171) | unaffected: it reads the server's snapshot |
| TV debug/haptic screens (latency_screen.dart:22, haptic_panel_screen.dart:108, providers.dart:230) | filter `!p.away`; a haptic to an away phone already returns false |

## 2. The protocol: `player_away` / `player_back`, not the roster

**Pick: a new pair under `view`** — `player_away {player, n, s}` (id, number, whole seconds left) and `player_back {player}` (back, or the grace is over and the round went on without them), host → viewer, only while a view runs (as `hostAway` does, server_game_host.dart:238-244), re-sent with `view_start` to a viewer that pairs mid-away (`_sendView`, :302-307). `n` travels because no frames come while paused.

**Not a roster flag**: `_rosterField` throws unless an entry is exactly `[number, name]` (view.dart:218-237), and a phone that can't decode gives up with 4003 (client_messages.dart:103-107) — every 0.12.0 phone showing the game would be kicked out the moment a player dropped. **Not both**: frames stop while paused, exactly when the state is needed.

**Old phones don't break** (checked): an unknown `t` decodes to null (codec.dart:44-66) and the client drops it (client_messages.dart:34-36), so a 0.12.0 phone ignores both, and its roster entries stay two-element (the away player stays in `pl`, so the frozen dot draws). A 0.12.0 *host* sends neither: accepted. `docs/protocol.md`: §4's `view` row, §10a's table, a sentence under "Waiting for the host", §11, §12 ("A player away before the round goes on | 30 s").

## 3. The phone side: a third wait kind, on top of 1107c's card

`HostWaitNotifier` (providers/view.dart:65-113) keeps id → (number, secondsLeft, sinceMs) from `PlayerAway`/`PlayerBack`, cleared on `ViewStarted`/`ViewEnded`; the state is the host's wait (`host_away`) if there is one — the bigger stop — else the away players. The card: "Player 2 is away", "The game goes on if they're back in 24 s", at 0 "The game goes on without them…" until `player_back` or the next frame; **Leave game** as 1107c gives it; one line per away player, the countdown on the phone's clock from arrival.

**The dropped phone itself: no card** — its slot turns live with its new pairing and `_checkPlayers`/`_sendView` re-send `view_start`, the latest frame, its layout and its panel, so it just goes on (test: no player-away wait for its own id).

**Phones without a game view** (a TV host, `shareView` false) get nothing new: the panel is the game's and is rewritten every step (puzzle_session.dart:141-144), so it can't carry a wait; the TV's own screen says it (§4). A host note line could carry it later; not this job.

## 4. The host's own screen: a third card, not the pause card

Drawn by `Pausable` over the game, so both games (puzzle_screen.dart:170, game_screen.dart:117) and every host type get it — not a dialog: nobody pressed Start, and it would fight the Start pause. It claims the menu controls like the dialog (`ControlsClaim(Controls.menus(only: present))`), so the remote and the phones here work it. One line per away player ("P2 is away", "The game goes on if they're back in 24 s") with **Go on without them** (`Key('goOnWithout')` → `gameHost.goOnWithout`, once per away player) and **End round** (`Key('awayEndRound')`: the menu's Quit path, `leaveForGamePicker`, ends `quit`, not `abandonRound`). Only while `Pausable.enabled`, never over the menu. New `ui/away_card.dart` (~90 lines); `pause_menu.dart` 204 → ~225.

## 5. The jobs (smallest first; A2 and C wait for 1107c)

| job | files | tests first | could break |
| --- | --- | --- | --- |
| **A1** the slot (G4) | `game_types.dart` (`away`), `game_host.dart` (`goOnWithout`), `server_game_host.dart`, `memory_game_host.dart`, the `!p.away` filters of §1, new `connection/test/player_away_test.dart` | the slot is kept for the grace and gone after (200 ms grace: there at 100 ms, gone at 300); `goOnWithout` drops it at once; pad neutral; dispose cancels the timers; a sim leaves at once; `playersChanged` fires on the drop and on the expiry | every test that counts `players` after a drop (`view_test`, `m6_test`, party_host fakes); `GamePlayer` equality in `_samePlayers` and `gamePlayersProvider._same` |
| **B** the pause and the card (G4) | party_host: `providers.dart` (`playersAwayProvider`), `ui/pause_menu.dart`, new `ui/away_card.dart`, `testing/host_fakes.dart` (set a player away); tests in `pause_menu_test.dart`, `puzzle_screen_test.dart`, new `away_card_test.dart` | the round stops for both games while someone is away (the clock stays, as pause_menu_test.dart:36-41); the card's text and countdown; Go on without them resumes; End round goes to the picker; no menu opens while away; menus skip an away phone | the pause tests, `game_players_test`, controller-menu layout assertions |
| **A2** the wire (G4) | protocol: `view.dart`, `codec.dart`; connection: `client_controls.dart` (+ export), `client_messages.dart`, `host_server.dart` (`capabilityFor`), `bin/sim_view.dart`; game_kit: `frame_view.dart`; `controller_app/providers/view.dart` (switch arms only); `docs/protocol.md` | both need `view`; a drop and a return send the pair in order, with the seconds left; a viewer that pairs mid-away gets them after `view_start`; a phone without `view` gets none | the exhaustive `ViewEvent` switches (frame_view.dart:134, sim_view.dart:99, providers/view.dart:37,87,140) — 1107c's file |
| **C** the phone's card (G4) | controller_app: `providers/view.dart`, `ui/waiting_card.dart`; tests `joined_view_test.dart`, a card test | the third kind's title, line and countdown; Leave game; the returning phone has no card; the host's wait wins over a player's; two away players, two lines | 1107c's card tests (follow its new text and keys) |

A1 alone holds a dropped player 30 s with the round running (dot frozen, clock going); B completes the decision, so A1 and B ship in one build. A TV host needs no code of its own: the same server path and the same `Pausable`; only the messages are absent while it doesn't share its view.

## 6. Questions (my calls; Claude's to confirm or change)

1. `awayGrace` as a `ServerGameHost` constructor `Duration` (connection can't import game_kit's `HostingSettings`), documented as `hostGraceS`? **unsure**
2. `goOnWithout(String playerId)` as the `GameHost` verb, one call per away player from the card?
3. A rematch pressed within the grace starts with the away player and pauses again: accepted, or should the slot end with the view? **unsure**
4. `End round` = Quit (`quit`), not `abandonRound` (`abandoned`)? And one "Go on without them" for all away players?
5. `player_away`'s `n` (my pick) or the number looked up in the last frame's roster?

## Files changed

- `docs/briefs/m12/bug-1107d-g1-plan.md` — new: this plan.

## Checks

- None run: a plan changes no code, and the brief names no check. Paths and line numbers above were read from the worktree today.

## Commit message

```
docs(m12): plan the pause for a player who drops mid-round

A dropped player keeps its slot in ServerGameHost for 30 s (awayGrace,
one timer per player, the server clock), so the rules keep its dot and
held piece; playersAwayProvider adds a second source to Pausable, so
both games stop. A view-gated player_away/player_back pair (not a
roster flag: a 0.12.0 phone would give up with 4003) carries the
countdown; the host screen gets a third card with Go on without them
and End round. Four jobs: A1, B, then A2 and C after 1107c.
```

## Status row

| Bug 1107d G1 plan | Plan done ([bug-1107d-g1-plan.md](bug-1107d-g1-plan.md)): the away slot lives in `ServerGameHost` (30 s, one timer per player, `GamePlayer.away`, `goOnWithout`), the pause is `Pausable`'s with a new `playersAwayProvider`, the others learn of it through a `view`-gated `player_away {player, n, s}` / `player_back` pair (not a roster flag: a 0.12.0 phone would give up with 4003), the host screen gets a third card, and the work is four jobs (A1, B; A2 and C after 1107c). Open: Claude's answers to five questions, then A1 |

## Delete

- none
