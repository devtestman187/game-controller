# M12 bug 1107d B — G4 report: the round waits for a phone that dropped; the host's away card

Done at G4, the gate the brief names. The plan's job B: `playersAwayProvider` counts each away player's grace on
the host's clock, `Pausable` treats it as a third pause (no steps, no clock, no frames, no catch-up, as the host's
lock), and a new `ui/away_card.dart` stands over the game with a line per away player, Go on without them and End
round. No file outside `allow:` was edited; `packages/connection` and `controller_app` are untouched, and so are
`packages/game_kit` and `packages/puzzle_game`.

## Files changed

- `packages/party_host/lib/src/players_away.dart` — **new**, 97 lines: `AwayPlayer` (`player`, `secondsLeft`),
  `playersAwayProvider` and `PlayersAwayNotifier`. The notifier notes each player's first roster as away with
  `gameHost.nowMs`, forgets the ones that are back or gone, and ticks once a second (`tick`) only while someone is
  away, so the card's seconds move; `graceS` is `ServerGameHost.hostGraceS` (30) read from `connection`, so the
  countdown and the host's slot can't drift. The plan put this in `providers.dart`, which came to 411 lines with it
  (the limit is 400): it moved here and `party_host.dart` exports it, the same move A1 made for `away_slots.dart`.
  `providers.dart` itself is unchanged from HEAD (`dart:math` came and went with the block).
- `packages/party_host/lib/party_host.dart` — 39 → 40 lines: `export 'src/players_away.dart';`.
- `packages/party_host/lib/src/ui/away_card.dart` — **new**, 144 lines: `AwayCard(players, onEndRound)` over the
  game, one `_AwayLine` per away player (`PlayerBadge` + "P2 is away" + the countdown), **Go on without them**
  (calls `gameHost.goOnWithout` once per away player) and **End round** (`onEndRound`, the menu's Quit). It claims
  the menu controls for the phones that are here and puts the focus on Go on without them, so the remote's OK and a
  phone's A press it.
- `packages/party_host/lib/src/ui/pause_menu.dart` — 241 → 262 lines: `Pausable` watches `playersAwayProvider`,
  `paused = menu || hidden || waiting`, and shows `AwayCard` over the game while `waiting` (only with `enabled`, so
  never on the results), not over the pause menu and not while the host app is hidden (the host's own pause wins);
  `_tick` opens no Start menu while someone is away, so the card is the screen's only menu; the class doc says so.
- `packages/party_host/lib/src/testing/host_fakes.dart` — 340 → 382 lines: `FakeHostService.removeController(id)`
  (the state without that phone, emitted), `FakeGameHost.setAway(id, isAway)` (emits the players), `clockMs` (a
  settable clock, so a countdown test moves time instead of waiting) and a `goOnWithout` that now takes the phone
  off the roster as the real host does (before, it only cleared `away`, which made the player live again).
- `packages/party_host/test/support/host_harness.dart` — 205 → 239 lines: `startRace`, `openRace` (home → Play →
  Shape Race with P1 left and P2 right), `timeLeftMs` (the round's clock from the play view's snapshot) and
  `holdSlot` (a phone away at the host clock's zero, plus the pumps that let the screens hear it).
- `packages/party_host/test/away_card_test.dart` — **new**, 95 lines, 5 tests (below).
- `packages/party_host/test/pause_menu_test.dart` — 102 → 230 lines, 6 tests (below).
- `docs/briefs/m12/bug-1107d-b-report.md` — this report.

## The card, exactly

Keys: `awayCard`, `awayLine-N`, `awayCountdown-N`, `goOnWithout`, `awayEndRound`. The texts, one line per away
player `N`:

```
P2 is away
The game goes on if they're back in 30 s          ← while the slot's grace has seconds left
The game goes on without them…                   ← at 0 s, until the host ends the slot
Go on without them                               ← focused as the card appears
End round
```

The seconds are whole and rounded up (`graceS * 1000 - elapsed` / 1000, ceil, at least 0), so 30 until the first
second has passed and 0 when the host's slot is due to end. An empty set of lines is impossible (the card only
shows while someone is away).

## The rules, and the values they were checked with

`pause_menu_test.dart` (`openRace`: a Shape Race from the house puzzle; the fake's clock):

1. **the round waits while a phone is away, and goes on from where it stopped** — `holdSlot(p2)`: the card shows,
   and the clock's `timeLeftMs` is the same after 63 frames of 16 ms (1008 ms); `setAway(p2, isAway: false)` and
   100 ms of frames later it has gone down by more than 0 and less than 200 ms (it goes on, it doesn't catch the
   pause up), and the card is gone.
2. **the round goes on at once when the away phone's grace runs out** — 10 frames frozen, then the phone leaves the
   roster (`removeController`, what the host's timer does); the card is gone and the clock has gone down after
   100 ms, with no press.
3. **the Arena waits for an away phone too** — with `hasViewers = true`, after 10 frames the fake has frames; over
   63 frames of `setAway(p1, true)` it has exactly the same number (nothing steps, no frame is sent); back, and
   32 ms later it has more.
4. **Start opens no menu while the round waits for an away phone** — P1's Start leaves no `pauseMenu`, the card
   still shows.
5. **an away phone gets no menu and cannot work one** — on the game picker, `setAway(p1)` and P1's A starts no game
   (A1's `!p.away` filters; this is the plan's "menus skip an away phone").
6. **the host going away and a phone away pause the round once** — with the host lock on, the card is hidden, the
   clock is still frozen over 30 frames; with the lock off the card is back (a phone is still away) and the clock
   is still frozen over 30 more; the log has exactly one `Round paused: the host went away` and one
   `P2 away: the round waits for them` (1107e's lines): one pause, counted once.

`away_card_test.dart`:

7. **the card names each away player and counts their grace down** — clock 0: "P2 is away" and "… back in 30 s";
   clock 6000 (+ a second's pump): 30 − 6 = **24 s**; clock 30000: "The game goes on without them…".
8. **two away players get a line each** — P2 and P3, two "back in 30 s" lines.
9. **Go on without them ends every away slot and the round goes on** — the focus is on `goOnWithout`; the away
   phone's A does nothing (`goOnWithouts` empty); a phone that is here presses it (`goOnWithouts == ['p2']`), the
   card goes and the clock goes on.
10. **End round is the menu Quit: the game picker, the round quit** — tap `awayEndRound`: `GamesScreen`, no
    `PuzzleScreen`, `viewEnds.last.reason == ViewEndReason.quit` (1107e's rule; not `abandoned`).
11. **the results show no card: no round runs to wait for one** — "Left wins!", a phone set away, no card (`enabled`
    is false there).

## Failed first

With `Pausable`'s away pause, the `_tick` gate and the card reverted (tests unchanged), 9 of the 11 tests failed for
the bug's reason (no pause, no card, no gate). The two that passed on the old code are "the results show no card"
(there was no card at all) and "an away phone gets no menu and cannot work one" (A1's `!p.away` filters already
landed). The code was restored, and the tests were run again after the `players_away.dart` move, all 103 pass.

## Checks

- `tools/check.sh format analyze host puzzle tv` — all PASS: format (1 s), analyze (6 s), puzzle (106 tests), host
  (**103** tests, 13 s), tv (9 s).
- Test counts before → after: host **92 → 103** (+11: 5 in the new `away_card_test.dart`, 6 in
  `pause_menu_test.dart`); puzzle 106 → 106; tv unchanged; kit 34 and phone 339 unchanged (`tools/check.sh analyze
  phone kit` also PASS, as `controller_app` host mode mounts `Pausable`).
- `tools/review.sh` — 0 fail, 9 notes: `host_fakes.dart` 382 lines (limit 400, aim 300) and eight
  `numeric literal` notes in `away_card.dart` (the card's styling; see "Not sure" 8).

## Not sure

1. **`providers.dart` has no diff.** The plan names it for `playersAwayProvider`; with the block inside it the file
   was 411 lines (limit 400), so it lives in `src/players_away.dart`, exported from `party_host.dart`, as A1 did
   with `away_slots.dart`. Say if it should stay in `providers.dart` and something else should move instead.
2. **The card's claim is `Controls.menus(only: here)`**, the plan's `only: present`, with here = the non-away,
   non-simulated, non-local ids. With every player away the set is empty and no phone works the card (the host's
   touch and the remote still do); I didn't copy the pause menu's `null` "Anyone can resume" fallback.
3. **B ("Back") on a phone while the card shows pops the game screen**: the play view is disposed, the view ends
   `quit` and the picker shows — the same landing as End round, without asking. The card doesn't say so. The pause
   dialog has no such hole (its layout makes B Resume, and B pops the dialog). If it should be blocked, a
   `PopScope(canPop: false)` in the card is the place (1107e put one on the results).
4. **The countdown starts when the host's roster first reports the player away**, on `gameHost.nowMs`, not at the
   socket close: the host holds the slot from its own check (up to 4 s of silence), so the card can say 30 while the
   host's timer has a little less left. At 0 the line says "without them…" until the host ends the slot (within a
   second on the real host), and the round is still paused until then.
5. **The fake's `goOnWithout` changed meaning**: it now removes the phone (`removeController`), because clearing
   only `away` made the player live again — a *return*, not "the round goes on without them". The grace test uses
   the same removal, since that is what the host's timer does.
6. **`host_fakes.dart` at 382 lines** (review note, aim 300): this job's 42 lines are `removeController`, `setAway`,
   `clockMs` and the new `goOnWithout`. Splitting the fake is a job of its own; say if it should be B's.
7. **`Pausable.build` always wraps the game in a `Stack(fit: StackFit.expand)`** now, card or no card, so the play
   view and its session are not rebuilt when the card appears; with nothing away it is one transparent layer.
8. **The card's styling numbers** (0.88 alpha, 20 radius, 32/24 padding, 20/12/6 gaps, 30 badge) are the review's
   `number` notes. They copy `game_screen.dart`'s and the pause dialog's own literals (0.7/0.75, 20/12, badge 30),
   which the review notes the same way; party_host has no style-constants file. Say if the card should make its own
   named constants.
9. **1107e's `_noteAway` log (not my lines)** keeps a number after a player leaves the roster while away, so a
   later phone with that number doesn't log "away" again. Left as it was; one line in `pause_menu.dart` if Claude
   wants it.
10. **Suggest, not acted on:** `AwayPlayer` is now part of `party_host.dart`'s surface, so A2/C can reuse it for the
    phone's card instead of a second record.
11. **Three `tv_test_app/windows` generated files show as modified** (`generated_plugin_registrant.cc/.h`,
    `generated_plugins.cmake`) after the tv check ran the Flutter tool. I didn't edit them and `git diff` lists no
    content for them (line endings only), as `bug-1107b-fix-report.md` and the A1 report noted.

## Commit message

feat(m12): the round waits for a phone that dropped

`playersAwayProvider` counts each away player's grace on the host clock
(ServerGameHost.hostGraceS) and Pausable treats it as a third pause, so
the puzzle and the Arena send no steps, no clock and no frames while the
round waits and go on where they stopped. The host's screen shows the
away card over the game: a line per away player ("P2 is away", the
seconds left), Go on without them (gameHost.goOnWithout for each) and
End round (the menu's Quit). The card claims the menu controls for the
phones that are here, Start opens no menu while it shows, and a slot
that ends by itself resumes the round. The away code lives in a new
players_away.dart, as providers.dart would have passed 400 lines.

## Status row

| Bug 1107d B | G4 done ([bug-1107d-b-report.md](bug-1107d-b-report.md)): `playersAwayProvider` (new `players_away.dart`, exported from `party_host.dart`) counts each away player's grace from the host clock (`hostGraceS` 30 s); `Pausable` pauses like the host lock (no steps, clock or frames, no catch-up), Start opens no menu, and the new `ui/away_card.dart` shows a line per away player with the countdown, Go on without them (`goOnWithout` each) and End round (Quit, `quit`); the phones that are here work it. Tests host 92→103; checks pass, review 0 fail. Open: A2 (the wire) and C (the phone's card) |

## Delete

- none
