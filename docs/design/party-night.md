# M14 design: Party night

Status: **written by Claude on Nov 9, 2026**, from the approved PRD (docs/PRD-v2.md "Party requirements" G1–G5, G9, C20, T15 and "Milestone 14"), the research in docs/briefs/m14/ and the refreshed scan (docs/briefs/m14/scan-m14-refresh-report.md). The PRD is approved, so the rules work starts now. The new screens get mock-ups first (section 10); a screen's job waits for the owner's OK on its mock-up. Open questions are in section 12, each with the default the work follows until the owner answers.

M14 is built on the branch `m14` (worktree `E:\AI\game-controller-m14`), cut from `m13`. Device-test fixes for M13 land on `m13` and are merged in.

## 1. The night in one paragraph

The host picks **Party night** on the game picker, chooses 3 or 5 rounds and sees the three awards they are playing for. For each round the host picks Shape Race or the Bumper Round. Every round ends on its results, then the **scoreboard**: each player's nickname, badge and total beside a star, and "Round 2 of 3". Before the last round it says the round is worth double. After the last round the awards are revealed one at a time, then the final scoreboard crowns the night. Outside a night, every game plays exactly as it does today, plus the Arena's waiting card, the cat (by the Chaos setting) and the best times.

## 2. Decisions

| # | Decision | Why |
| --- | --- | --- |
| N1 | **One result seam.** Each game's screen hands a `RoundResult` (new, in `game_kit`) to its `onFinished`: the game's name, the winners (a set), draw, each player's points this round, each player's counters for the awards, and each player's line for the phone's results card. The night reads only this. The records (`round_end`, `player_result`) stay a metrics sink | Scan question 4: the games share no result today and the Arena has no `onFinished`. A typed value is testable and keeps the night out of both games |
| N2 | **Points are per player.** A game credits a side's points to every player on it (G1), so a side of two and a side of one earn the same for the same play. The night keeps one total per player, keyed by controller id, so teams may change between rounds | G2: "each player keeps their own total"; the Arena has no sides |
| N3 | **The game applies the double.** A night's last round tells the game "points ×2", so the pop-ups show the doubled number (+4 for a snap) and the result is already doubled. Award points (+3) are never doubled | A child sees why the last round matters; one place does the sum |
| N4 | **Points show only in a night.** Outside a night the rules still count them (so tests cover them) but nothing is drawn | Keeps a single race calm and as it is today. Owner, Nov 9, 2026 (Q1): "Agree with default" |
| N5 | **The night is host state**: a `PartyNight` notifier in `party_host` (rounds, round index, totals, awards, counters, who has played). Nothing in a game imports it. It ends after the final scoreboard, or when the host leaves the night ("End the party night?"); nothing is saved (the hall of fame is M15, G8) | Scan §4: nothing above a round remembers one today |
| N6 | **The host picks each round's game on the card before it**: the night's start card and the scoreboard both end in two big buttons, "Shape Race" and "Bumper Round". Shape Race then goes through its puzzle pick and join screen (teams may change there); the Bumper Round goes to the Arena's waiting card | PRD: "The design settles how the host picks each round's game". No extra screen between rounds |
| N7 | **In a night the Arena is always the Bumper Round.** With one player joined, a CPU marble, Robo, plays the second marble (section 7a), so a night and a Bumper Round work for one player. Outside a night the waiting card offers Bumper or Race | G9 needs two marbles; a night round must end, and today's race has no end. Owner, Nov 9, 2026 (Q3): "Can we have a simple CPU player for a single player?" |
| N8 | **Arena awards are added, starting with Coin Collector** (most coins picked up in the night's Bumper Rounds, at least 3); more are proposed in section 6. An award nobody qualifies for is skipped in the reveal with "Not won tonight" | PRD asks whether the list gains an Arena award; a night of mostly Bumper Rounds would otherwise have awards nobody can win. Owner, Nov 9, 2026 (Q2): "Yes to coin collector" |
| N9 | **Joined phones see the night through their results card.** `view_end` gains an optional `result`; it carries this player's outcome and, in a night, the standings. The scoreboard and awards themselves stay on the host's screen | A joined phone draws only from frames and messages (review-rules B5); the card is its window onto the screens between rounds |
| N10 | **Sounds ride on the event.** The Arena's `GameEvent` gains a sound name, played in place of the haptic's name; its haptic becomes optional, and a world event (a coin appearing) has no player. Bumps and a lost coin buzz; a coin pickup gives a light tick; a coin appearing does not buzz | Scan question 3: coins are sound-first; new `HapticEvent`s cost a pattern and a duration case each |
| N11 | **Snapshot versions.** Shape Race's snapshot goes to version 2 with the cat (PRD); its points keys are added in the same version. The Arena's goes to version 2 with the Bumper Round. A phone one build older asks for an update | The PRD's acceptance test; a v1 phone must not draw a different game |
| N12 | **The library's defaults change nothing.** `PuzzleSettings` gains `chaos` (library default off) and `pointsScale` (default 1); the Arena's mode defaults to race. The host's saved Chaos setting defaults to A little | Acceptance: "with Chaos off and outside a night, every rules test passes unchanged" |
| N13 | **Nicknames need no protocol change.** The phone saves a nickname (10 characters) and sends it as `hello.name`; with none, the phone's default name becomes `Phone 1A2B` (10 characters, not "Android phone 1A2B"). The host also cuts names to 10. A new nickname shows from the next join | Scan §6: `hello.name` already reaches the roster and the HUDs |
| N14 | **Best times live in the host's prefs**: the top 3 per puzzle and level, each with the time and the nicknames of that board's players (any finished board: solo, team or a side of a race). A new record is the results card's moment: "New record!", the celebration sound and confetti | T15; kept on the host like C20 says |
| N15 | **Mock-ups first for the new screens** (section 10), drawn by docs/design/look-mockups.html in Sunny and Night as in M13. Rules jobs do not wait for them | The owner reviewed M13's screens before they were built; the rules have no look |

## 3. Points in Shape Race (G1)

- The rules count per side: snap on the first try +2, after a wrong drop +1, finishing first +5 (on one board: finishing before time-up), a big piece carried home by two +1, shooing the cat +1 (to the shooer's side). Each value × `pointsScale`.
- Each award adds a **pop-up** event: side, place (the piece or the cat), amount, icon. It lives 1.2 s.
- Snapshot (version 2): top-level `pts` (each side's points) and `pop` (the live pop-ups, each with its age in ms, so a joined phone draws the same rise and fade). Both are drawn only when the frame says it is a night round (`nt: true`).
- Pop-ups: a big "+2" in Fredoka with a star icon beside the piece, rising 24 px and fading over 1.2 s; with effects off it appears and goes without motion (G5). Never colour alone: the number and icon carry the meaning.
- The counters the awards need go into `RoundResult.stats` per player: `snaps`, `wrongDrops`, `carries`, `catsShooed`.

## 4. The night (G2)

- **Start card** (Party night on the picker): "3 rounds" / "5 rounds" (3 is focused), the three awards drawn for the night, each with its picture and one line, and, when Chaos is on, "The cat visits the side that's ahead". Then "Pick round 1": Shape Race / Bumper Round.
- **Awards drawn at the start**: three from the six (G4's five and Coin Collector), at least one of Best Helper, Cat Catcher or Comeback. Drawn from a seeded random, so a test can fix them.
- **After each round**: the game's own results card first (as today); its "Next" goes to the scoreboard. Play again, Change teams and Back are replaced by "Next" in a night, and Back on the scoreboard asks "End the party night?".
- **Scoreboard**: players in total order, each row: badge (colour and number), nickname, a star icon and the total, and the round's points as "+7" beside it. Ties share a place. "Round 2 of 3" on top; before the last round a banner: "Last round: double points!". The two game buttons under it.
- **Players coming and going**: a player who joins mid-night starts at 0; one who leaves keeps their row, greyed, and is counted at the end if they come back.
- **Music**: the start card and scoreboard are a `LobbyHold`, so they play the lobby music where it plays today (look-and-sound §8).

## 5. The cat (G3)

The PRD's rules stand as written. How it is built:
- `CatChaos`, its own file in `puzzle_game`, stepped by the match after each side's tick. States: away → warning (2 s: meow, a paw at the edge of that side, the shadow on the target piece) → walk → bat → leave. Shooed (a worker on the cat and A, during the warning or the walk): it runs off and stays away for the round, +1 to the shooer's side.
- Its random comes from the match's seed (the host's), so a test can replay it.
- Targeting: the side ahead in pieces placed; in a draw either, never the same side twice in a row; none in the first 20 s or the last 10 s, none in a night's last round. On one board (solo or team) it visits that board and never knocks a placed piece.
- A little: at most once a round, only a loose or tray piece, batted to another free spot on that side. Party: at most twice, and once it may knock a placed piece loose (only on a side ahead by at least one piece, never the picture's last piece or one placed in the last 3 s): the piece bounces to that side's tray with its outline glowing, and the side keeps its points.
- Snapshot (version 2): top-level `cat`: state, side, position, target piece, warning time left.
- The Chaos setting (Off / A little / Party) is in Puzzle settings, saved on the host, default A little; it applies in and out of a night.
- Sound: `meow` at the warning; the bat and the run-off reuse `bump` and `dash`.

## 6. Awards and the end of the night (G4)

- Revealed one at a time on the host after the last round's results: the award's picture and name, then the winners' badges and nicknames, a one-line reason ("Fewest wrong drops: 1") and "+3", with the `fanfare` cue. Every tied player gets it. An award nobody qualified for shows "Not won tonight" for 2 s.
- Then the **final scoreboard**: the night's winner (or winners) on top with a crown, `celebration`, confetti (G5 limits), and "Back to games".
- Qualifiers, from the night's counters: Sharpshooter (fewest wrong drops, at least 3 snaps), Best Helper (most carries home together), Cat Catcher (most cats shooed), Speedy Snapper (most snaps), Comeback (most points in the last round), Coin Collector (most coins picked up, at least 3). Zero never wins a "most" award.
- **Proposed additions (Claude, Nov 9, 2026, for the owner's pick)**, each taken from a party game's end-of-game bonus and fitted to a family night (docs/briefs/m14/research-party-games-report.md §6, research-party-design-report.md §3, research-arena-party-report.md):

  | Award | Who gets it | Game | A losing player can win it? | Taken from |
  | --- | --- | --- | --- | --- |
  | **Round Winner** | most rounds won (at least 2) | both | no | Mario Party's Minigame Star; Pummel Party's "most minigames won" |
  | **Try Again** | most pieces snapped after a wrong drop (at least 2) | Shape Race | yes | Mario Party's Misfortune Star, turned from bad luck into not giving up |
  | **Big Bopper** | most shoves (a dash into another marble, at least 3) | Bumper | no | Pummel Party's "most damage dealt", with no damage |
  | **Bounce House** | bumped the most times (at least 3) | Bumper | yes | Mario Party's Doormat Star, said as fun, not shame |
  | **Gold Rush** | most gold coins picked up (at least 2) | Bumper | partly | Mario Party's Coin Star, for the last 15 seconds |
  | **Steady Roller** | fewest coins dropped (with at least 5 picked up) | Bumper | partly | the Arena's Sharpshooter |

  Held back: a fastest-snap award (it needs a new timer per snap) and "most dropped coins picked up" (too close to Coin Collector). With these the list has twelve; still three per night.
- **The draw, with more awards**: of the night's three, at least one a losing player can win (Best Helper, Cat Catcher, Comeback, Try Again or Bounce House) and at least one either game can earn (Comeback or Round Winner), so the reveal never ends with nothing won. The start card names them, so nobody is surprised (LEGO Party cut random bonuses at launch for feeling unearned, then brought them back as an option; Mario Party's Pro Rules announce the bonus up front).
- **Robo never gets an award**: awards are for people. It can win a round and the night, honestly, like any player; it plays only Bumper Rounds and its level is gentle (section 7a), so a lone player who also plays Shape Race rounds is well placed. Faking the result is the "participation trophy" the research warns against (research-arena-party-report.md).

## 7. The Bumper Round (G9)

- **Rules file**: after `arena.dart` is split (groundwork), the Bumper Round is its own file on the shared marble movement; the race stays as it is. `ArenaMode { race, bumper }`; the mode is chosen before the round and never changes inside it.
- **Contact**: one pass over the pairs each step, in roster order (fixed by player number) so it is deterministic: overlapping marbles are pushed apart and bounce. A dashing marble shoves the other hard. A marble that hits a wall within 0.5 s of being shoved by another counts as "shoved into a wall". A shove never pushes a marble through a wall (the move is sub-stepped as today).
- **Coins**: three field coins at a time, each new one sparkling for 1 s (not takable), never placed under a marble, at seeded free spots. A hazard or a shove into a wall drops one coin (worth 1) beside the marble, takable at once by anyone but the dropper, who is dizzy for 1 s (no dash) and then safe for 1 s (drops nothing). A marble with no coins drops nothing but is still dizzy. Dropped coins are extra to the three. In the last 15 s new field coins are gold, worth 2.
- **Clock**: 60 s counting down; it stands still whenever the round stands still (`Pausable`'s holds). At 0 the round is over: the most coins wins, ties share the win, and the result has `winners` and `draw` like the puzzle's (scan question 2). Night points: +1 per coin, +5 to each winner, both × `pointsScale`.
- **Snapshot (version 2)**: top-level `md` (mode), `tl` (time left, ms), `co` (coins: position, gold, sparkle age, dropper); per marble `c` (coins), `dz` (dizzy), `sf` (safe). The HUD shows each player's coins beside their badge with a coin icon, on the host and joined phones.
- **Sounds** (the a1 files): `dash`, `bump`, `bump_big` (a dash that shoves), `coin`, `coin_gold`, `coin_lost`, `coin_appear`; the music `arena`, `arena_hurry`, `arena_final` following the clock at 15 s and 5 s (look-and-sound §8). `MusicLoop` gains the Arena's trio, chosen by the game; `GameScreen` reports its clock and its end to `HostMusic` as `PuzzleScreen` does. The race Arena stays on `arena`.
- **Results card** (like Shape Race's): the winners with a crown, each player's coins; Play again / Change mode / Back, or "Next" in a night.

## 7a. Robo, the CPU marble (owner, Nov 9, 2026: "Can we have a simple CPU player for a single player?")

- **When**: in the Bumper Round, when exactly one player is joined. The waiting card shows Robo as the second marble ("Robo joins you") and the round starts when the one player is ready. A second person joining takes Robo's place before the next round. Robo never plays when two or more people are in.
- **Who it is**: a marble with the next free player colour, a small antenna as its accessory (look-and-sound §5b) and the name "Robo" with a robot icon instead of a number, on the host and on joined phones. It is never a controller: no phone, no haptics, no stats or ratings records (a CPU's numbers would spoil the play-testing figures).
- **How it plays** (`CpuPilot` in `test_game`, one input per step from the game's own state, on the host, so nothing new goes over the network):
  - rolls to the nearest coin it can take, gold first in the last 15 s, steering round hazards with a margin;
  - dashes toward a far coin, and now and then at the player when they are close and have coins: at most one shove every 4 s, so it bumps but never bullies;
  - its wobble comes from the round's seeded random, so a round can be replayed in a test.
- **Three levels** (owner, Nov 9, 2026: "Make 3 difficulty settings for CPU. Easy medium and hard."), picked on the waiting card while Robo is in ("Robo: Easy / Medium / Hard"), remembered on the host, Easy the first time. One table of numbers in `CpuPilot`, so tuning is a data change:

  | | Easy | Medium | Hard |
  | --- | --- | --- | --- |
  | Reacts | 0.5 s late | 0.3 s late | 0.15 s late |
  | Top speed | 75% | 85% | 95% |
  | Wobble | big | small | almost none |
  | Coins it goes for | the nearest | gold first in the last 15 s | the best worth for the distance, and coins others drop |
  | Shoves | never seeks one | at most one every 4 s, when the player is close and has coins | at most one every 2 s, aimed so the player goes toward a wall or hazard |
  | Hazards | wide berth | some margin | tight lines |
  | Aim (tuned on devices) | a child around 8 wins about 4 rounds in 5 | about even with a child | an adult has to try |

  Every level plays by the same rules as a person: never faster than a marble may go, and it sees only what the game knows. Hard is better, never a cheat.
- **The rules don't know Robo is a CPU**: the session adds Robo's input to the same map of inputs the players' phones fill (`arena_session.dart`), so contacts, coins and the clock are the same code.
- **Shape Race**: no CPU in M14 (a worker that picks, carries, turns and drops is a bigger job); Claude suggests it for M15, beside power-ups.

## 8. The Arena's waiting card

- Shown over the Arena when it opens, on a TV and a phone host alike: the pairing code, each joined phone's badge and nickname, and "Press A when you're ready" with a ✓ for each ready player. The mode buttons, Bumper and Race, are under it (in a night, Bumper only). With one player joined, Bumper brings in Robo (section 7a).
- The 3-2-1 starts when at least one player has joined and every joined player is ready; on the TV too (today only the phone host has the ready beat).
- A player who joins during a Bumper Round waits on the card's "Joins next round" line; in the race they join at once, as today.
- `Pausable` keeps owning everything once the round runs (pause, the host away, a player away). The waiting card is before the round and the results after it: one owner each (review-rules A3).

## 9. Nicknames, results on joined phones and best times

- **Nicknames (C20)**: a "Nickname" field in the phone's settings (up to 10 characters, letters, numbers and spaces), saved beside the controller id; "Shows next time you join". Section 2 N13.
- **Results on joined phones**: when a round ends, the host sends each phone that draws the round a `view_end` with `result`: its own outcome (`win`, `loss`, `draw`, or `done` with the time on one board), its side's time or pieces (or coins), its points in a night, and in a night `{round, of, standings}`. The phone keeps the last frame and shows the card over it: "You win!", "You lose", "Draw", "Done! 1:42", then "Waiting for the host to pick what's next." The card goes on the next `view_start`, or on a second `view_end` without a result (the host left the results). A phone that gets no `result` (a host one build older) goes back to its pad as in M12. docs/protocol.md lists the field.
- **Best times (T15)**: a "Best times" button on Shape Race's puzzle pick opens the board (per puzzle and level, the top 3, time and nicknames). A new record on the results card: "New record!", `new_record` cue and confetti.

## 10. Mock-ups (for the owner's OK)

Drawn by docs/design/look-mockups.html, each in Sunny and Night, saved under docs/design/look-mockups/ with the prefix `m14-`:
1. The game picker with the Party night card
2. The night's start card (rounds, the three awards)
3. Shape Race in a night: a "+2" pop-up and the cat's warning (paw, shadow)
4. The scoreboard, round 2 of 3, and the same before the last round (double banner)
5. An award reveal, and the final scoreboard with the crown
6. The Arena's waiting card (code, three phones, two ready, mode buttons), and the same with one player and Robo, its level buttons showing
7. The Bumper Round: coins, a gold coin, a dizzy marble, the clock and the coin HUD
8. A joined phone's results card in a night
9. The best-times board and a "New record!" results card
10. The phone's nickname field

## 11. Sounds for the new moments

One job, made like a1 (the "Bubble Pop" set, mastered like the event sounds, free to ship, rows in CREDITS.md): `meow` (the cat's warning: short, friendly, clearly a cat), `points` (a soft pop under a pop-up, quieter than `coin`), `fanfare` (an award, about 2 s), `celebration` (the night's winner and a won round, about 2.5 s), `new_record` (about 1.5 s, brighter than `celebration`).

## 12. Owner's answers and open questions

Answered Nov 9, 2026: Q1 points only in a night ("Agree with default", N4); Q2 Coin Collector ("Yes to coin collector", N8); Q3 a CPU for one player ("Can we have a simple CPU player for a single player?", N7 and section 7a), with three levels ("Make 3 difficulty settings for CPU. Easy medium and hard.").

Open (the work follows the default until answered):
- **Q4**: Which of the six proposed awards (section 6) join the list? Default: all six.
- **Q5**: Robo in the Bumper Round only for M14, and a Shape Race CPU in M15? Default: yes.

## 13. Implementation order

Each step is a flash job with a brief and a review gate, at most three at once, side by side only when they share no file.

**Wave 1, groundwork** (no owner gate):
- **g1 puzzle groundwork** (`puzzle_game`): split `game.dart` (399) by a pure move; split `puzzle_rules.dart` (391) and move the three test-only rules into `check` (two turned pieces, no tray overlap at seeds 0–199, the smallest piece on the narrowest phone); `Level.hard` refused in the schema and parser until it has rules; the parser's bare casts given messages (R4 9 and 10).
- **g2 Arena split** (`test_game`): `arena.dart` (487) split by a pure move into the marble movement, the race rules and the field; the size FAIL goes green.
- **g3 host groundwork** (`party_host`, `game_kit`, `assets`): the empty-rounds record (an abandoned round's `round_end` adds no round to the stats); the round music resuming where it was after the app was hidden (R4 8); the a1 `SoundKey`s and CREDITS rows (playing nothing yet); the `RoundResult` type in `game_kit` with its test.

**Wave 2**: **a1 points** (G1, `puzzle_game`, after g1), **b1 Bumper rules** (G9 rules, snapshot, events and sounds, `RoundResult`, `test_game`, after g2 and g3), **m1 mock-ups** (section 10, `docs/design`).

**Wave 3**: **s1 sounds** (section 11, `tools/audio`, `assets`), **c1 the night** (N1–N7, `party_host`: `PartyNight`, the start card, the scoreboard, the picker card, `onFinished` from both games; after m1's OK), **a2 the cat** (G3, `puzzle_game` and Puzzle settings, after a1).

**Wave 4**: **b2 the Arena's screens** (the waiting card, the ready beat on the TV, the results card, the music's clock; after m1's OK), **c2 awards and best times** (G4 with the added awards, T15, after c1 and s1), **c3 the phone** (nicknames and results on joined phones, `controller_app`, `protocol`, after c1).

**Robo** is **b3** (section 7a: `CpuPilot`, its seat in the session and on the waiting card, its badge), after b1's rules and with b2's waiting card; it runs in wave 4 if b2 lands first, else right after it. The three levels' aims (section 7a) are checked in the device tests.

**Then**: the full review R5 (worker first, Claude verifies), the comfort check (G5) over every new effect, device tests on a TV host, a phone host and a joined phone, then a build on the owner's word.
