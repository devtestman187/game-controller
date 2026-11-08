# M12 build 4 review R2 — the host's screens: party_host and tv_test_app

Read-only. `git diff 526a6fc HEAD -- packages/party_host tv_test_app` (build 4's code ends at `9df6884`); only
this report was written.

## Part A — the jobs of this area: is their self-check true?

No report has an A1–A3 section (the rule came after them; s10a–c answered through their test tables), so these
answers are mine.

- **1107b** (addresses, the log line): true. `network_addresses_test` (5) holds each platform's list, `en0` before
  another interface, the OS order inside a rank; the `Addresses:` prefix stays (`host_service.dart:357`). A1: every
  host kind runs `LiveHostService`; nothing tests the `dropped` half of `_addressesLine`.
- **1107d A1** (a dropped phone's slot): true. `player_away_test` and the `away_slots` tests; `!p.local`/
  `!p.simulated` keep a host player and the test tool out, so A1 holds on the TV and both phones; an older phone's
  codec ignores `player_away`.
- **1107d B** (the wait, the away card): true for what it claims; the hole B named in "Not sure 3" is finding 1.
  Values: `graceS` 30 → the card shows 30 / 24 / 1 / 0 s at 0 / 6000 / 29999 / 30000 ms.
- **1107d A2 + C** and **s11** (the mirror): r1's and r3's areas; the host side A2/C rests on (`AwaySlots.endAll`
  from `endView`, `sendTo`) is covered by the connection tests.
- **1107e** (back on the results, the log lines): true. `puzzle_results_test` (5), `round_log_test` (7). Its Q2
  (Quit logs nothing) still stands; the away lines' gap is finding 4.
- **s10a** (the phase; the pad only in a round): true. `round_phase_test`; "the round's phase is none on the menus
  and playing in a round, and after Resume"; "a round that waits for a phone away or for the host is none"; five
  layout tests in `puzzle_screen_test`.
- **s10b** (the own player): true. `join_screen_test`'s six own-player tests: TV/PC → no own player, the old hint
  (line 229); "Show on this device" → `_ownPlayer` null (`join_screen.dart:242`), sides not tappable (214); "Play
  on this phone" → a side, marked, a full side refuses (182), back from away joins again (248). In a round the own
  player gets no case of its own: finding 2.
- **s10c** (the beat): true. `ready_beat_test` (5). The beat is 3008 ms, not 3000: finding 3.

## Findings — most severe first

1. **must** · `away_card.dart:68` · B1, B4 · While the card is up a phone's B pops the round. The card claims
   `Controls.menus(only: here)`, which puts menus back over the round's `Controls.game()` (`puzzle_screen.dart:175`),
   so `ControllerMenus` runs again and `_Key.b` pops the route of the focused control (`controller_menus.dart:257`)
   — the round's, because `canPop: result == null` is true until the results (`puzzle_screen.dart:170`). The round
   ends `quit` on the level list, one route short of the picker: the landing 1107e fixed for the results. Every
   drop makes it reachable. `away_card_test` presses no B.
2. **should** · `pause_menu.dart:133` · A3 · A host on "Play on this phone" has its own player in the roster as a
   paired controller, and `_stopped` gives it no case of its own: when its link drops the card says "P1 is away"
   about the host itself and covers the pad for the 30 s. The join screen has this case (`join_screen_test:248`);
   the round has neither a test nor a rule. The trigger needs a device; the state is reachable by this code.
3. **should** · `pause_menu.dart:159` · B2 · The beat counts 16 ms ticks, not the host's clock: 3000 / 16 → 188
   ticks × 16 = 3008 ms, the card showing 3 for 63 ticks, 2 for 62, 1 for 63; a frame longer than a tick stretches
   it by the stall. `_beat` also runs while the round is stopped (it resets to 3 s each tick, so the away time is
   never counted).
4. **should** · `pause_menu.dart:196` · B1 · `_awayNos` forgets a number only while its player is in the roster and
   not away; a player who leaves (Go on without them, grace out, a new number) stays in it, so the next phone with
   that number that drops logs no "P2 away: the round waits for them", and "P2 back" can name another phone.
5. **later** · `puzzle_screen.dart:99` · C (M13) · The round's moments and log lines live in one game's screen: the
   Arena's rounds log no start or end (`game_screen.dart` logs only a keyboard player joining), and M13's countdown
   and warning would land there too. Cost now: the calls move to `GameSession`; after M13, per game.
6. **later** · `away_card.dart:130` · C (M13) · The card's text is a copy of the phone's away card and has already
   diverged ("P2 is away" here, "Player 2 is away" in `controller_app`); its colour (0.88) and `ReadyCard`'s (0.75)
   are literals. Cost now: one string table and theme entry; later: a re-skin touches both.

## B — the questions the brief names

- **The card's countdown vs the server's grace.** Same `graceS` (`players_away.dart:27` reads
  `ServerGameHost.hostGraceS`), same clock (`GameHost.nowMs`), ceil on both sides, so no drift by construction. The
  card starts at the roster event, a frame after the slot's own timer, and its number moves once a second, so it
  can read up to ~1 s high; it never outlives the slot, because the slot's end emits the roster and the notifier
  drops the player then, not on the tick.
- **The join screen's own player.** All three setups are in Part A (s10b): covered. What is not: the own player in
  a round (finding 2).
- **Back on the results.** The route can't pop (`canPop` false), so B and Back run `onPopInvokedWithResult` →
  `_leaveForGames` → `leaveForGamePicker`, tested both ways; the same B in a round is finding 1.
- **The log lines.** Start, end, results and the menu's pauses are tested; Quit logs nothing (1107e Q2, decided);
  the away lines' number reuse is finding 4.

## A3 — the pairs

| pair | tested by |
| --- | --- |
| pause menu × Get ready | "Start during the beat opens nothing, and the round goes on after it" |
| pause menu × phone away | "Start opens no menu while the round waits for an away phone"; a menu already open stays over the wait and the card waits for it (`build`: card only with `_pausedBy == null`) — not tested |
| pause menu × host away | "a Pausable with the host away pauses the game without the menu" |
| phone away × Get ready | "a round that waits during the beat holds the beat, and it starts again from 3" |
| phone away × host away | "the host going away and a phone away pause the round once" (also that the card hides while the app is away, once) |
| phone away × results | "the results show no card: no round runs to wait for one" |
| phone away × leaving | not tested — finding 1 |
| host away × Get ready, × results | not tested: `_beat` resets to 3 s each tick while stopped, so the full beat starts over when the app is back; `enabled` false ends it (`next = 0`), and the phase is none either way |
| results × leaving | "on the results B on the phone goes to the game picker", "on the results the Back button goes to the game picker", "a race shows the winner, and Rematch keeps the teams" |
| the round × B (playing or on the beat) | not tested; the round's own claim is `Controls.game()` (menus false), so B does nothing — the card's claim is what breaks it |
| the beat × TV | "with no beat asked for (the TV), there is no card and the round steps at once" |
| abandoned round × pause menu | "an abandoned round ends while the game is still paused", "leaving with Quit ends the game quit, not abandoned" |

## Not checked

- r1's area (protocol, connection, game_kit, metrics) and r3's (controller_app, puzzle_game).
- The real device: whether the host's own in-process link drops with the app (finding 2's trigger).
- `tv_test_app` has no tests; its two screens filter away phones by reading only (`haptic_panel_screen.dart:108`,
  `latency_screen.dart:22`), the TV's A1 answer. `docs/design/*` and `review.sh`'s 37 notes: read, not triaged
  one by one.

## Checks

- `tools/review.sh` on `526a6fc..HEAD`: 0 fail, 37 note, no FAIL to copy. `tools/check.sh format analyze host tv`:
  PASS format (2 s), analyze (12 s), host (117 tests, 83 s), tv (26 s), all passed (125 s).
- `git status` lists the three `tv_test_app/windows/flutter/generated_*` files as modified with no content diff
  (`git diff` is empty): line endings only, from the tv check. Not edited by this pass.

## Commit message

docs(m12): build 4 review R2, the host's screens

Read-only pass over packages/party_host and tv_test_app, 526a6fc to 9df6884,
against parts A to D of the review rules, with the A3 table and the checks.
One must: a phone's B pops the round while the away card is up.
Three should: the host's own player counted as an away phone; the beat's
16 ms ticks; the away numbers the log never forgets. Two later C rows.

## Status row

| Build 4 review R2 | **Done** ([build4-review-r2-report.md](build4-review-r2-report.md)): the host's screens read against A–D, review 0 fail, all checks pass; open: 1 must, 3 should, 2 later, and R1 and R3 unchanged by this pass |

## Delete

- none
