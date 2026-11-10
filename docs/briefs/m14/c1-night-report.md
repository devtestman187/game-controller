# M14 c1 — the party night (G2)

Stop: the brief's `stop:` is "after it", so the job runs through the notifier, the awards, the three screens, the
picker card, the Shape Race rounds that feed it and the checks, then stops there. c2's reveal is a marked place,
not built. (The "(G2)" in the job's title is PRD v2's goal G2, not a plan gate.)

## The night's API

`packages/party_host/lib/src/night/` holds the state; nothing in a game imports it.

- `NightLength` (`three` = 3, `five` = 5) with `rounds`.
- `NightPlayer` (`({int number, String? nickname})`) — what a row knows about a player.
- `NightState` (immutable, `@immutable`): `factory NightState.start({length, awards, players})`; `length`, `round`,
  `awards`, `totals` (`Map<String, int>` by controller id), `counters` (`Map<String, Map<String, int>>`, the
  `RoundResult.stats` summed), `roundsWon`, `played`, `lastRoundPoints`, `seen`; getters `rounds`, `roundsLeft`,
  `isOver`, `isNextRoundTheLast`, `roundsWonBy`, `counter`; `remember(players)`, `record(RoundResult)`,
  `rows(players)` (rows in total order with `place`, `tied`, `isHere`).
- `NightAward` / `NightAwardGame` / `NightAwardPicture`: the 12 awards with their name, line, picture key, the game
  that can earn it and whether a losing player can win it; `nightAwardsPerNight = 3`; `drawAwards(Random)`.
- `PartyNight` (a `Notifier<NightState?>` in `party_night.dart`, not `providers.dart`) with
  `partyNightProvider`, `start({length, awards})`, `recordRound(RoundResult)`, `end()`. Its `build()` listens to
  `gamePlayersProvider` and `remember`s the roster, so a leaver keeps a row and a joiner is at 0.
- `NightChaos` (the a2 seam): `catVisitsTonight()`, `catSitsOut({lastRound})` and
  `settingsForRound(settings, {lastRound})`, which returns the settings with `night: true` and `pointsScale` 1 (or
  2 on the last round).
- `nightPointsScale = 1`, `lastRoundPointsScale = 2`, `nightBumperRoundReady = false` (b2 turns it on).
- `packages/party_host/lib/src/text/night_text.dart`: every night word in one place, so `host_text.dart` stays as
  it is.

`PartyNight.recordRound` is the only writer: `PuzzleScreen`'s Next calls it with `MatchResult.round`, then opens
the scoreboard.

## The screens and their frames

| Frame | Built as | Test |
| --- | --- | --- |
| 1 — game picker | Three cards in one row: Shape Race, Arena, **Party night** last, its drawn crown-and-three-rosettes picture, "3 or 5 rounds, points, awards", and the focus ring on the night's card on a TV/remote host | night_screens "the picker's Party night card opens…", host_focus_ring "the picker rings the card that has the focus" |
| 2 — start card | 1040 px card: "Rounds" with "3 rounds" (focused, focus-yellow fill) and "5 rounds", "The night's three awards" and the three drawn award cards, the cat's line, "Pick round 1", the Shape Race button and Bumper Round disabled with "Soon" | night_screens "the picker's Party night card…" and the D-pad test |
| 4 — scoreboard | 900 px card, "Round 2 of 3": a row per player with the crown slot, place ("3=" for a tie), badge, nickname, a star, the total and the round's "+7"; the two game buttons under | night_screens scoreboard group |
| 5 — scoreboard before the last round | "Last round: double points!" banner over the rows, and the same round plays at scale 2 | night_screens "before the last round…"; night_round_test "the night's last round plays at scale 2…" |
| 7 — final scores | "Final scores", the crown on the winner (or winners), "Back to games" which ends the night | night_screens "after the last round…" |

Leaving: Back/Escape/B on the start card returns to the picker; on the scoreboard it asks "End the party night?"
(No stays, Yes clears the night and goes back to the games). The start card and the scoreboard are `LobbyHold`s.

c2's reveal goes between the last round's results and this scoreboard: `_Scoreboard`'s comment in
`night_scoreboard_screen.dart` marks the place.

## Files

- `packages/party_host/lib/src/night/night_awards.dart` (new) — the 12-award catalogue and `drawAwards`.
- `packages/party_host/lib/src/night/night_state.dart` (new) — the night's immutable state, its rows and places.
- `packages/party_host/lib/src/night/party_night.dart` (new) — the notifier, the provider and `NightChaos`.
- `packages/party_host/lib/src/text/night_text.dart` (new) — the night's words.
- `packages/party_host/lib/src/ui/night_widgets.dart` (new) — award card, crown, disc, banner, the two game
  buttons, the leave dialog.
- `packages/party_host/lib/src/ui/night_start_screen.dart` (new) — the start card.
- `packages/party_host/lib/src/ui/night_scoreboard_screen.dart` (new) — the scoreboard, its leave question and its
  final scores.
- `packages/party_host/lib/src/ui/night_scoreboard_widgets.dart` (new, part of the screen) — one score row.
- `packages/party_host/lib/src/ui/games_screen.dart` — the Party night card, the row of three cards and where each
  opens (start card, or the scoreboard of a night still going).
- `packages/party_host/lib/src/ui/games_screen_widgets.dart` — `_GameRow` and the card's width share.
- `packages/party_host/lib/src/ui/game_picture.dart` — the night's picture on the picker.
- `packages/party_host/lib/src/ui/host_button.dart` — `fill`, for the chosen rounds button.
- `packages/party_host/lib/src/ui/leave_round.dart` — `isGamePickerRoute`, so the night's screens clear back to the
  picker.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` — the round's night settings and Next, which records the
  round and opens the scoreboard.
- `packages/party_host/lib/src/ui/puzzle_screen_widgets.dart` — the results keep only Next in a night.
- `packages/party_host/lib/party_host.dart` — exports for the new files.
- `packages/party_host/test/support/night_harness.dart` (new) — a roster the test sets, a container, a round's
  result, three fixed awards and the two navigation helpers.
- `packages/party_host/test/party_night_test.dart` (new) — 16 tests: the state and the Chaos seam.
- `packages/party_host/test/night_awards_test.dart` (new) — 5 tests: the catalogue and the draw.
- `packages/party_host/test/night_screens_test.dart` (new) — 8 widget tests: picker, start card, D-pad, Escape,
  scoreboard rows, banner, final scores, Back asking.
- `packages/party_host/test/night_round_test.dart` (new) — 4 widget tests: the round's settings on the first and
  last round, Next on the results, and the unchanged results outside a night.
- `packages/party_host/test/controller_menus_test.dart` — the picker's first focus is now the night's card, so the
  phone's A opens the start card and left walks to Shape Race.
- `packages/party_host/test/host_focus_look_test.dart`, `test/host_focus_ring_test.dart` — the TV's first ring is
  on the night's card.
- `packages/party_host/test/games_screen_test.dart` — the card-width check runs at a TV size, where a card keeps
  its 380 px.

## Computed test values

| What | Value |
| --- | --- |
| totals across rounds with changing teams | p1 9, p2 12, p3 7; rounds won 1 / 2 / 1 |
| the last round fed a `RoundResult` built at scale 2 | 7 + 4 + 14 = 25 |
| ties | totals 11, 8, 8 → places 1, 2, 2 and `tied` on both 8s ("2=", "2=") |
| a joiner | 0 points, last row |
| a leaver | keeps the row (nickname "Dad", badge 2), greyed (`isHere` false), counted again on return |
| `drawAwards(Random(7))` | Best Helper, Cat Catcher, Round Winner (in catalogue order) |
| 300 seeds | always 3 distinct, always at least one losable and one either-game award |
| a real Shape Race house round, solo, scale 1 | points 5, counters snaps 0, wrongDrops 0, carries 0, catsShooed 0, tryAgains 0 |
| the scoreboard after two 5-point rounds | total 10, place 1, round's points "+5" |
| the picker's card width | 380 px at 1280, 288 at 960, 252 at 852, never under 240 |

## Checks

`tools/check.sh format analyze host kit tv phone` — all pass. host 276 → 309 tests (+33: 16 + 5 + 8 + 4); kit 71,
phone 439 and tv unchanged. `tools/review.sh` — 0 fail, 19 note (numeric literals, as elsewhere in the package).

## Self-check (review rules, part A)

1. **Every host setup.** A TV/PC host: the night's card takes the focus on the picker and the ring is on it
   (host_focus_ring "a TV shows the ring from the start…"). Play on this phone / Show on this device: the picker
   still fits at 852×393 and keeps Shape Race's focus, so the owner's joined-phone case is unchanged
   (`controller_app` `host_menu_fit_test`, `host_focus_pad_test`, both PASS). A joined phone: the D-pad picks 5
   rounds, A starts the night (night_screens "the D-pad and a phone's A choose 5 rounds…"). An older build: no
   protocol or snapshot change, so not affected.
2. **When kept state starts and ends.** The night starts on the start card's game press; it ends on the final
   scores' "Back to games" or on "End the party night?" Yes (`party_night_test` "no night runs until one starts,
   and it can be ended", night_screens "Back asks first: No stays…"). With no round running it holds the last round's
   points and nothing runs: no timer, no listener but the roster's.
3. **How it combines.** The night + the pause menu: the pause menu is untouched and the round's pause is still its
   own (`night_round_test` "outside a night the results keep…"; the pause tests PASS). The night + a player
   leaving/joining: the row stays at 0 or greyed (party_night_test). The night + host away, Get ready or a dropped
   link: not affected — the night holds no timer, input or snapshot; those stay the round's own states.
4. **Stay in the job's folder.** Only `docs/briefs/m14/c1-night-report.md`, `packages/party_host/lib` and
   `packages/party_host/test` changed; `game_kit` needed nothing.
5. **Stop rather than overstep.** The picker's third card changed what the phone tests see (fit and first focus);
   both were kept green inside `party_host` rather than by editing `controller_app/test` — see question 1.

## Questions

1. The picker's first focus: I followed "focused first" on a TV/remote host, but a touch-first host (Play on this
   phone, Show on this device) keeps Shape Race's focus, because two `controller_app` tests assert it and they are
   outside this job's `allow:`. Should the night's card take the focus everywhere (and those two tests be updated),
   or stay as built?
2. `NightChaos` is the a2 seam: `catVisitsTonight()` currently answers true and `settingsForRound` sets
   `night: true` with the round's scale; when a2's `PuzzleSettings.chaos` lands, `catSitsOut` and the start card's
   cat line should read the host's saved setting and the last round should pass `chaos: off`. Is that the shape
   a2 should use?
3. The Bumper Round is behind `nightBumperRoundReady = false`, so its button is null and shows "Soon"; b2 flips the
   flag and makes `_startBumperRound` the Arena's waiting card. Is that enough of a hook for b2?
4. In a night the results' Back still leaves to the picker with the night running (only Rematch/Play again/Change
   teams were replaced by Next). Should Back end the night or ask, as the scoreboard's does?
5. The picker's three cards share the screen's width (380 → 288 at 960, 252 at 852, floor 240 where they wrap).
   The alternative is keeping 380 and letting the picker scroll at 960 and on a phone, which fails the phone
   picker's "fits without scrolling" test. Which does the mock-up want at small sizes?

## Suggestions

- c2's reveal: `night_scoreboard_screen.dart` marks the place; a small `NightRevealScreen` pushed between the last
  results and the scoreboard would keep the scoreboard's own tests untouched.
- A phone's own results in a night ("Show on this device") would want the same Next; it is out of this job's files
  and worth a later one.

## Commit message

M14 c1: the party night's picker card, start card and scoreboard

The night's state in PartyNight: rounds, totals, counters, places, awards.
Twelve awards and drawAwards. The start card with 3/5 rounds, the three
awards and the cat's line; the scoreboard with places, ties and the last
round's banner; the final scores with the crown. Shape Race rounds play
with night: true, scale 1 then 2, and their Next records the round and
opens the scoreboard. Chaos and the Bumper Round wait behind one named
seam each.

## Status row

M14 c1 done: the party night — PartyNight state, the 12-award draw, the picker's Party night card, the start card, the scoreboard and final scores, Shape Race rounds with night: true at scale 1/2 and Next into the scoreboard, leaving with "End the party night?"; format, analyze, host (309), kit (71), phone (439) and tv pass; open: c2's reveal, a2's Chaos behind NightChaos, b2's Bumper Round behind the flag.

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted. Result 0, applied cleanly; no lib file over 400 (puzzle_screen.dart 332), review.sh 0 fail. The night's state is immutable, nothing in a game imports it, and both seams (`NightChaos`, `nightBumperRoundReady`) are where the brief asked.

One fix by Claude, test-first: in a night the results hid Back, but the remote's B, Escape and a phone's back still left for the picker and **dropped the round's points**. Now Back on a night's results records the round like Next and opens the scoreboard, whose Back asks "End the party night?" (night_round_test "Back on a night round's results records the round like Next"). host 309 → 310.

Answers:
1. Stay as built: a touch-first host keeps Shape Race's focus (m12 bug 1107f); a TV/remote host focuses the night's card.
2. Yes: Claude connects `catVisitsTonight`/`catSitsOut` to a2's `PuzzleSettings.chaos` when a2 lands, and `settingsForRound` sets Chaos off in the last round.
3. Yes, the flag plus `_startBumperRound` is enough for b2.
4. Back records the round (the fix above).
5. Shared widths are right: frame 1 is three cards in one row on a TV, and a phone must fit without scrolling.

Open for later: the picker's own Shape Race card while a night runs also plays a night round (it is still the night, so it counts); the night's screens are checked against the mock-ups by eye at R5 and on devices. The phone's own results in a night (Show on this device) go to c3.
