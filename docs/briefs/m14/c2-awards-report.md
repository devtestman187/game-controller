# M14 c2 — the awards' reveal and best times (G4, T15)

Stop: the brief's `stop:` is "after it", so the job runs through the awards' decision, the reveal screen, the
final scores' celebration, best times, the checks and this report, then stops at G4. Nothing of c3 is built.

## What was built

- **The three awards are decided from the night's counters** when its last round is recorded
  (`PartyNight.recordRound` → `NightState.awarded(...)`), in the order the night drew them, so the reveal follows
  the night's own order. `night_award_results.dart` holds the qualifier table and `decideAwards`; ties share an
  award (design section 6), and a "most" award is never won with 0. Only players the night has met may win, so
  Robo is never named.
- **An award's +3 goes into the final scores' total only** (`NightState.rows` adds `awardPoints * awardsWonBy(id)`);
  `totals` still holds the rounds alone, so nothing else changes and the +3 is never doubled (N3).
- **The reveal is its own screen** (`NightRevealScreen`) pushed between the last results and the final scores by
  both Nexts (`puzzle_screen.dart` and `game_screen.dart`, when `partyNightProvider` is over). One award at a time:
  title header, its disc, the winners' badges and nicknames, the reason ("Fewest wrong drops: 0"), a star and
  "+3 points", with `fanfare` and confetti; an award nobody won says "Not won tonight" for 2 s and plays nothing.
  A won award stays 4 s. Escape (or the remote's Back) skips the rest to the final scores. The scoreboard's tests
  are untouched.
- **The final scores celebrate once**: `NightScoreboardScreen` is now stateful, plays `celebration` when the night is
  over (on open from the reveal, or when it becomes over) and draws `NightConfetti` behind the card.
- **Best times** (`best_times.dart`): the host keeps the fastest 3 per puzzle board (`<puzzleId>|solo` and
  `<puzzleId>|team`) in `SharedPreferences` under `bestTimes`, each with its time in ms and the nicknames of that
  board's players. A finished board saves its time as its results open (`recordBestTimes`); a board that ran out of
  time saves none. A new best (or a board's first time) plays `new_record` once and wears a "New record!" chip on
  its results row, with the board's best beside it ("Best 1:35").

## The qualifier table as built

`_qualifiers` in `packages/party_host/lib/src/night/night_award_results.dart`; every reading comes from the night's
summed `RoundResult.stats`, except the two the night counts itself.

| Award | Counter | Gate | Takes | Test's numbers (p1 / p2) |
| --- | --- | --- | --- | --- |
| Sharpshooter | `wrongDrops` | `snaps` ≥ 3 | fewest | 0 / 2 → p1 |
| Best Helper | `carries` | ≥ 1 | most | 2 / 1 → p1 |
| Cat Catcher | `catsShooed` | ≥ 1 | most | 1 / 3 → p2 |
| Speedy Snapper | `snaps` | ≥ 1 | most | 5 / 4 → p1 |
| Comeback | the last round's points (night's own) | ≥ 1 | most | 6 / 2 → p1 |
| Coin Collector | `coins` | ≥ 3 | most | 6 / 7 → p2 |
| Round Winner | rounds won (night's own) | ≥ 2 | most | 2 / 1 → p1 |
| Try Again | `tryAgains` | ≥ 2 | most | 4 / 2 → p1 |
| Big Bopper | `bumpsGiven` | ≥ 3 | most | 4 / 2 → p1 |
| Bounce House | `bumps` | ≥ 3 | most | 5 / 2 → p1 |
| Gold Rush | `goldCoins` | ≥ 2 | most | 3 / 1 → p1 |
| Steady Roller | `coinsDropped` | `coins` ≥ 5 | fewest | 1 / 4 → p1 |

Ties: every player level on the winner's number gets the award (`bestHelper` 2, 2, 1 → p1 and p2, value 2). A
player with no number for a counter never qualifies, so an empty night shows twelve "Not won tonight". The three
Arena awards read counters no game reports yet — see Decision 1.

## Files

- `packages/party_host/lib/src/night/night_award_results.dart` (new) — `NightAwardOutcome`, `awardPoints`, the
  twelve qualifiers and `decideAwards`.
- `packages/party_host/lib/src/night/night_state.dart` — `outcomes`, `awardsWonBy`, `awarded`; `rows` adds the award
  points to a total.
- `packages/party_host/lib/src/night/party_night.dart` — `recordRound` decides the awards when the night is over.
- `packages/party_host/lib/src/text/night_text.dart` — `notWon`, `winners`, `awardPoints`.
- `packages/party_host/lib/src/text/record_text.dart` (new) — "New record!", "Best 1:45", `clock`.
- `packages/party_host/lib/src/best_times.dart` (new) — `BestTime`, `BestTimeResult`, `BestTimes`, its notifier and
  the saved `bestTimes` key.
- `packages/party_host/lib/src/ui/night_widgets.dart` — `NightConfetti` and its static painter.
- `packages/party_host/lib/src/ui/night_reveal_screen.dart` (new) — the reveal between the results and the final
  scores, its timers, fanfares and Escape.
- `packages/party_host/lib/src/ui/night_reveal_widgets.dart` (new, part) — the award card, its body and a winner's
  row.
- `packages/party_host/lib/src/ui/night_scoreboard_screen.dart` — stateful for the once-only celebration, confetti
  over the final scores, `_ScoreCard` used.
- `packages/party_host/lib/src/ui/night_scoreboard_widgets.dart` — `_ScoreCard` (the card and its buttons moved out
  of the screen so both builds stay short).
- `packages/party_host/lib/src/ui/puzzle_screen.dart` — `_times`, `recordBestTimes` and the `new_record` cue on
  finish, Next into the reveal after the last round, the results' second part.
- `packages/party_host/lib/src/ui/puzzle_results_widgets.dart` (new, part) — `_Results`, `_ResultSideRow` with the
  best time and `_NewRecordChip`.
- `packages/party_host/lib/src/ui/puzzle_screen_widgets.dart` — the results moved out; the shared head, buttons and
  photos stay.
- `packages/party_host/lib/src/ui/puzzle_best_times.dart` (new) — `playersOn` and `recordBestTimes`.
- `packages/party_host/lib/src/ui/puzzle_choice.dart` (new) — `PuzzleChoice` moved out of `puzzle_screen.dart`.
- `packages/party_host/lib/src/ui/game_screen.dart` — the Arena's Next opens the reveal after a night's last round.
- `packages/party_host/lib/src/ui/games_screen.dart`, `packages/party_host/lib/src/ui/join_screen.dart` — import
  `puzzle_choice.dart` (and the picker drops `puzzle_screen.dart`, now unused).
- `packages/party_host/lib/party_host.dart` — exports for the five new public files.
- `packages/party_host/test/night_award_results_test.dart` (new) — 8 tests: the twelve qualifiers, the draw rule,
  nobody, zero, Robo, the night's order, the +3, a round after the end.
- `packages/party_host/test/night_reveal_test.dart` (new) — 4 widget tests: order and fanfares, "Not won tonight"
  and its 2 s, Escape, last results → reveal → final scores.
- `packages/party_host/test/best_times_test.dart` (new) — 7 tests: saved, beaten, solo apart from team, the top
  three, the prefs round-trip, and two results-card widget tests.
- `packages/party_host/test/game_screen_test.dart` — `openGame` picks Race as well as the Playroom, see Decision 7.

## Computed test values

| What | Value |
| --- | --- |
| a busy night's twelve awards (p1 / p2) | p1: Sharpshooter 0, Best Helper 2, Speedy Snapper 5, Comeback 6, Round Winner 2, Try Again 4, Big Bopper 4, Bounce House 5, Gold Rush 3, Steady Roller 1; p2: Cat Catcher 3, Coin Collector 7 |
| a draw | carries 2, 2, 1 → winners p1 and p2, value 2 |
| zero | `carries` 0 / 0 → no Best Helper; `snaps` 3 / 2 with `wrongDrops` 0 / 0 → p1's Sharpshooter, value 0 |
| Robo | counters 40 snaps, 3 rounds, 9 last-round points, but never in `people` → not in any winners |
| the +3 | three rounds of p1 5 / p2 2: `totals` p1 15, p2 6; rows p1 18, p2 6 |
| the reveal's reasons | "Most carries home together: 3", "Most points in the last round: 5", "Fewest wrong drops: 0" |
| the reveal's timings | won 4000 ms, missed 2000 ms; three fanfares, no `celebration` until the final scores |
| best times kept | 120000, 100000, 110000, 90000 → [90000, 100000, 110000] |
| a level time | 95000 against a 95000 best → not a record |
| the saved solo time in a widget test | 0…1000 ms, names `['iPhone 3F1C']`, shown "Best 0:0…" |
| a slower round against a 1 ms best | no chip, no `new_record`, "Best 0:00" |

## Test counts

| | Before | After |
| --- | --- | --- |
| host | 339 passed, 1 failed (340) | 359 passed (340 + 8 + 4 + 7) |
| puzzle | 358 | 358 |
| phone | 445 | 445 |
| tv | pass | pass |

The one baseline failure was `game_screen_test`'s `openGame`, which drove the Arena without a mode after b2 made
Bumper its default; Decision 7 repairs it inside this job's files. `puzzle_game` needed no change.

## Checks

`tools/check.sh format analyze host puzzle phone tv` — all PASS (format, analyze, host 359, puzzle 358, phone 445,
tv). `tools/review.sh` — 0 fail, 10 note (numeric literals in the awards' table and the existing `colors.player(4)`;
sizes of files I touched are at most 395 lines).

## Decisions

1. **The three Arena awards read Arena counters that do not exist yet**: `bumps` (Bounce House), `goldCoins` (Gold
   Rush) and `coinsDropped` (Steady Roller). The Arena reports only `coins` and `bumpsGiven` today, and
   `packages/test_game` is outside `allow:`, so those three awards say "Not won tonight" until the Arena reports
   them. The qualifier table is written for the day it does.
2. **Confetti is painted in `party_host`** (`NightConfetti`) rather than reusing `puzzle_game`'s `Celebration`,
   which needs the game's field rect; a static, seeded scatter also keeps a menu from paying frames (G5's limit).
3. **Best times are keyed by puzzle id and solo/team**, top 3, with names. Design N14 says "per puzzle and level";
   a puzzle id is one level, so the two say the same thing, and a team is never measured against one player.
4. **The best time sits on the results row**, inline beside the time, rather than on a new line under the rows: a
   small phone's results card overflowed by 22 px with a line of its own.
5. **T15's "Best times" board screen is not built**: the brief asks for the time on the results with `new_record`
   when beaten, which is what is built; the board button on the pick is Question 3.
6. **The reveal's words live in `RecordText` and `NightText`**, not `HostText`, which is near its limit and has
   another job adding to it.
7. **`game_screen_test`'s `openGame` now sets `ArenaMode.race`**: its tests drive the race's dash and wall hit, and
   b2 made Bumper the card's default, so it failed before this job (the baseline's one failure).
8. **The reveal never waits on a child**: Escape/Back skips the rest, and each award's timer is cancelled when the
   screen goes; the final scores then take its place with `pushReplacement`.
9. **An award's +3 is added only in `rows`**: `totals` stays the rounds' own, so nothing that reads totals (the
   scoreboard's "+7", a test, a later hall of fame) sees an award as points played.
10. **`PuzzleChoice`, `_ScoreCard` and the results widgets moved** into their own files/parts so no lib file passes
    400 lines and no build passes 60 (the review's limit), with their keys unchanged.

## Self-check (review rules, part A)

1. **Every host setup.** A TV/PC host: `night_reveal_test`'s four tests and `night_screens_test`'s scoreboard group
   pass; the confetti is a `CustomPaint` with no input. Play on this phone / Show on this device: no new screen is
   in the phone flows; the results' best time is inline so the card still fits at 852×393 (`best_times_test`, and
   `controller_app`'s host fit tests pass). A joined phone: not affected — the reveal and the final scores are the
   host's, and no protocol message changed. A build one older: nothing new goes over the wire; a prefs key an older
   build does not know is ignored.
2. **When kept state starts and ends.** The best times start empty, are written on each finished board and read
   when the results build; malformed saved JSON is logged and treated as empty (`best_times_test` "the times are
   saved on the host…"). The reveal starts when the screen is built with a night over (or when it becomes over),
   each award's `Timer` ends at its advance, and all timers are cancelled in `dispose` and by `_finish`, whose guard
   makes one push. With nothing going on (no night, no round) no timer and no listener runs.
3. **How it combines.** The reveal cannot meet the pause menu (the night's last round's results come after its
   pause ended); host away, Get ready and a dropped link stay the round's own and the reveal holds no input but
   Escape; the scoreboard's celebration is once per screen (`_celebrated`); the leave question is unreachable from
   the reveal. Pairs tested: reveal + Escape (`night_reveal_test` "Escape skips…"), reveal + the night's end
   ("a night's last results lead to the reveal…"), final scores + confetti and celebration (the same test's end).
4. **Stay in the job's folder.** Only `docs/briefs/m14/c2-awards-report.md`, `packages/party_host/lib` and
   `packages/party_host/test` changed; `puzzle_game` needed nothing. `git status` also lists
   `tv_test_app/windows/flutter/generated_*` as modified with an empty content diff (line endings only, written by
   the check suite's `flutter` run); they are untouched and left as they are.
5. **Stop rather than overstep.** Nothing this job needs is outside `allow:`; the one thing it could not do — the
   Arena's missing counters — is Question 1, and the awards say "Not won tonight" instead.

## Questions

1. The Arena reports only `coins` and `bumpsGiven`; Bounce House (`bumps`), Gold Rush (`goldCoins`) and Steady
   Roller (`coinsDropped`) therefore always say "Not won tonight" today. Should b3/the Arena report them?
2. Robo is left out by deciding only among `night.seen`, which never holds Robo; if the Arena one day reports Robo's
   counters, the same rule still holds. Is that enough, or should the Arena explicitly not report a CPU's stats?
3. T15's design (section 9) also asks for a "Best times" button on Shape Race's pick, opening a board of the top 3
   per puzzle. This job shows the times on the results only; which job builds the board?
4. `NightConfetti` duplicates the idea of `puzzle_game`'s `Celebration`; should the puzzle's celebration gain a rect
   parameter so both share one painter?
5. Best times per puzzle id and solo/team — is that what "per puzzle and level" means (a puzzle id is one level),
   or should the level be part of the key too?

## Suggestions

- When the Arena reports `bumps`, `goldCoins` and `coinsDropped`, the three awards light up with no change here.
- The reveal's times (4 s / 2 s) could become a host setting in the look-and-sound screen if a family finds 4 s
  short on a long reason line.
- A hall of fame (M15, G8) wants the best times and the night's awards in one saved record; `BestTimes.toJson` is
  already that shape.

## Commit message

M14 c2: the awards' reveal and best times

The night's three awards are decided from its counters when the last
round is recorded, ties sharing them and Robo never named. A reveal
screen shows them one at a time between the last results and the final
scores, with fanfare and confetti, "Not won tonight" for a missed one;
the final scores then celebrate once. Best times: the host keeps the
fastest three per puzzle board (solo and team) with names, saves each
finished board, and its results show "Best 1:35" and a "New record!"
chip with the new_record cue.

## Status row

M14 c2 done: the twelve awards' qualifiers and draw rule decided from the night's counters (Robo never named), the reveal screen between the last results and the final scores with fanfares, "Not won tonight" and the once-only celebration, and best times kept on the host and shown on the results with new_record; format, analyze, host (359), puzzle (358), phone (445) and tv pass; open: the Arena's bumps/goldCoins/coinsDropped counters for three awards, T15's best-times board screen.

## Delete

- none
