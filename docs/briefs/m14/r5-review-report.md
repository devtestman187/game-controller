# M14 r5: the full review (worker pass)

The whole milestone against docs/review-rules.md, docs/design/party-night.md, the PRD's Milestone 14 and its
acceptance tests and the diff: findings only, ranked; no code changed; a "fix" is a suggestion.

## Findings

1. **must** · `packages/party_host/lib/src/ui/game_screen.dart:332` · `packages/test_game/lib/src/arena_session.dart:180` · B1/B3 · When the Bumper clock runs out, `_finished` sends the result end (`server_game_host.dart:264`), then the results stage replaces the field in the same frame, `ArenaView.dispose` ends the session and `GameSession.dispose` (`game_kit/lib/src/game_session.dart:249`) sends a `view_end` with no result; `viewResultProvider` (`controller_app/lib/src/providers/view.dart:95`) sets the card to null and the view off, so a joined phone never shows its Bumper result though Shape Race's card stays. *Fix:* keep the field/session alive under the results as Shape Race does, or defer the view's end to the host leaving the results.
2. **must** · `packages/test_game/lib/src/arena_bumper.dart:94-175`, `arena_coin.dart:9-40` · B/C, G9, design §7 · The coin rules beyond "take one, bring one" are absent: no 1 s sparkle that can't be taken (`_takeCoins` ignores the coin's age), no drop of exactly one coin on a hazard or a shove into a wall, no dizzy/safe second and no `dz`/`sf` in the snapshot, no gold coin worth 2 in the last 15 s, and `coins` carry no gold/sparkle/dropper, so `coin_gold`, `coin_lost` and `dash` never play. A tester's "a hazard or a shove into a wall drops exactly one coin … gold coins appear only in the last 15 seconds" (PRD line 770) fails. *Fix:* add the two coin kinds, the sparkle gate, the drop/dizzy/safe state and the three missing sounds to the rules and the snapshot.
3. **must** · `packages/party_host/lib/src/night/night_award_results.dart:48-50,107-111` · `packages/test_game/lib/src/arena_bumper.dart:154-157` · B/C, G4, design §6 · The Bumper reports only `coins` and `bumpsGiven`, so `bumps`, `goldCoins` and `coinsDropped` never exist and Bounce House, Gold Rush and Steady Roller always reveal "Not won tonight"; the draw can put one of them in a night's three. Also Round Winner needs a race winner, and a one-board round has no winners (`puzzle_game/lib/src/match.dart:265-270`), so a solo/team night can't win it either. *Fix:* report the counters with finding 2, count a finished one-board round as its side's round won, or draw only from awards the night's games can earn.
4. **must** · `packages/party_host/lib/src/ui/games_screen.dart:120-160` · C, T15, design §9:204, PRD deployable builds · There is no best-times board screen and no "Best times" button on Shape Race's puzzle pick: only `best_times.dart` and the results chip exist. "Nicknames show on … the best-times board" and the TV's "best-times board" deliverable fail. *Fix:* a board screen reading `BestTimes` (top 3 per puzzle and level, times and names) opened from the pick.
5. **should** · `controller_app/lib/src/ui/result_card.dart:30-57` · design §3a/§9, PRD acceptance 8 · The joined phone's result card covers the last frame with text only; design §3a says "its own results card (section 9) holds the same photo", which the host's card draws (`ui/puzzle_results_widgets.dart:63-97`). *Fix:* draw the side's board from the last frame as a framed photo in the phone's card.
6. **should** · `packages/game_kit/lib/src/frame_view.dart:159` · B7 · The version test is exact equality both ways, so an M14 phone joined to an M13 host shows "Update the app to see this game" even though the phone is the new build; design §9's "a host one build older" pairing (result simply absent) can never be drawn, and v1 frames are not decoded anyway. *Fix:* keep the previous snapshot's viewer for a version one behind, or tell the user which side to update.
7. **should** · `packages/party_host/lib/src/ui/arena_waiting_card.dart:173-177` · `packages/party_host/lib/src/ui/game_screen.dart:204-220` · design §7b · A night's card shows Surprise me lit until the host picks, but `_start` reads `settings.mapId`, so the round plays the map saved before the night; and Surprise me avoids only the immediately previous map (`arena_settings_provider.dart:108`), so a 5-round night can repeat a map. *Fix:* pass the card's choice (null = surprise) to `_start` and remember the maps the night has used.
8. **should** · `packages/party_host/lib/src/ui/night_scoreboard_widgets.dart:114-116` · `packages/party_host/lib/src/night/night_state.dart:252` · design §4/§7a · Robo is never on the roster, so `isHere` is false and its scoreboard row wears the leaver's 0.45 opacity all night although it is playing. *Fix:* skip the away opacity for `roboPlayerId`.
9. **should** · `packages/party_host/lib/src/night/round_results.dart:27-36` · design §9 · The phone's standings drop every row with number 0, so Robo is missing from the night table a phone sees: its `place` can be "2nd" while only one player is listed above it, and the night Robo is winning looks wrong. *Fix:* send Robo as a standing with its name and no badge.
10. **should** · `packages/test_game/lib/src/cpu_pilot.dart:92-106`, `cpu_tuning.dart:10-48` · design §7a · Robo only ever returns a move: no dash toward a far coin and no shove, so the level table's Shoves column (never / 4 s / 2 s) and "dashes toward a far coin" are not built and Hard is weaker than designed. *Fix:* a level's dash/shove interval in the pilot's input.
11. **should** · `packages/party_host/lib/src/ui/night_reveal_screen.dart:120-126` · A3, design §6 · Only Escape is bound to skip; a remote's Back or the system's pop closes the reveal back to the picker, so the final scores and their celebration never show although the comment says Back skips the rest of the reveal. *Fix:* a `PopScope` that calls `_finish`.
12. **should** · `packages/party_host/lib/src/ui/night_start_screen.dart:41-59`, `night/party_night.dart:71-74`, `ui/games_screen.dart:64` · A2/A3 · A night started then backed out of before round 1 (round 0) leaves the picker opening a **new** start card: it draws fresh awards and its own length, its buttons no-op `start`, and the running night keeps the first awards, so the card names awards the night isn't playing for. *Fix:* show the running night's awards and length, or start the night only when round 1 starts.
13. **later** · `packages/puzzle_game/lib/src/puzzle_cat.dart:35-50`, `puzzle_points.dart:40-42` · design §3/§5 · A knocked piece has `wronged` reset, so re-placing it awards the first-try +2 again: the punished side can score the piece twice. Cost now: a per-piece "ever placed" flag (and, if shown, a snapshot key).
14. **later** · `packages/party_host/lib/src/ui/night_start_screen.dart:41` · design §4 · The start card's awards come from an unseeded `Random()`, so a test can't fix the card's draw as design §4 asks (tests start nights directly instead). Cost now: one seed line.
15. **later** · `packages/puzzle_game/lib/src/match_painter.dart:270` · design §3a ("everywhere the round is seen", a3 Q3) · The mirror shows no finish celebration, so a phone-hosted round seen on a TV is quiet there. Cost now: reuse the burst in the mirror painter.

## Acceptance tests (PRD v2 M14)

| # | Test | Verdict |
| --- | --- | --- |
| 1 | 3- and 5-round night on a TV and phone host, scoreboard between rounds, double banner, awards one at a time | Built and unit-tested; the full run is device-only |
| 2 | Points pop up on the host and every joined phone; a side of two and one earn the same | Pass (rules and snapshot tests); feel device-only |
| 3 | Cat: once on A little, warning first, 20 s/10 s, never twice, never a placed piece; Party knock keeps points; shoo works; off with Chaos off | Pass (cat tests); feel device-only |
| 4 | A joined phone one build older is asked to update | Pass (`frame_view.dart:159`, its test); the reverse direction fails (finding 6) |
| 5 | Start card names three awards; every tied player wins one | Pass |
| 6 | Colour and accessory on the phone, drawn everywhere, nearest free when taken, told so, defaults for an old host | Pass (protocol, reservation and phone tests) |
| 7 | Nicknames on scoreboard, awards and best-times board; best times survive a restart | **Fail**: no best-times board (finding 4); storage passes |
| 8 | 2.5 s celebration on host and joined phones, framed photo on the results card, no celebration at time-up, nothing moves with effects off | Pass on the host; **fail** on the joined phone's card (finding 5); the 2.5 s is device-only |
| 9 | Joined phones show their own results card and it goes on the next step | Pass for Shape Race; **fail** for the Bumper (finding 1); device-only |
| 10 | Arena with nobody joined shows the waiting card; the countdown waits for every A | Pass |
| 11 | Bumper with 2/3/4 players, 60 s, coins, tie; exactly one coin dropped per hazard/shove into a wall; gold in the last 15 s; Robo at three levels; a joiner replaces it; night points | **Fail** on the drop and the gold coins (finding 2); the rest passes |
| 12 | Five maps pass `tools/level.sh check` and play on both hosts; Playroom race unchanged; `new map` passes; every M13 puzzle command has a `level.sh` form | Five maps and the tool exist; **not run** (see Not checked) |
| 13 | A 4-player cat round keeps its frame rate; nothing flashes more than 3 times a second | Device-only; no flash found by reading |
| 14 | No existing Shape Race rule changed with Chaos off and outside a night | Not verified here (tests not run) |

## Combination table (A3)

| Pair | Result |
| --- | --- |
| Night round × pause | Tested (Pausable tests); every clock stops |
| Night round × host away / player away | Tested (Pausable tests); held, and the beat restarts from the top |
| Arena results × a joined phone's result end | **Not tested**: the second end clears the card (finding 1) |
| Night results × Next / Back | Tested (`night_screens_test`); Back records as Next does |
| Awards reveal × Back | **Not tested**: Back leaves the reveal for the picker (finding 11) |
| Joined phone result card × `view_start` / a second `view_end` | Tested (`controller_app` view tests) |
| Celebration × effects off / time-up | Tested (`celebration_test`, results tests) |
| Night started, left before round 1 × a new start card | **Not tested** (finding 12) |

## Decisions to revisit

- b1 D3 and D15 (no gold coins, sparkle, drop, dizzy; a dash plays `rumble`): findings 2, and the `dash` cue unused.
- c2 D1 and D5: three awards unwinnable and one unsendable (finding 3); no best-times board on a named M14 build (finding 4).
- b3 D9-10 (Robo never dashes or shoves): the Shoves column is unbuilt (finding 10). a3 Q1/Q3 (phone photo, mirror celebration): findings 5, 15.
- b2 D5 and the card's "Surprise me": finding 7. a2 Q2 ("never the same side twice" can miss on the second visit) is the stricter reading of design §5: accept it; a2 Q7 is a device test.
- b2 D1 (the card opens on Bumper) does not break N12: N12 is the library's default (`arena.dart:68`, race). c1's "Back records" is right; the reveal's Back is finding 11.

## Device-test list

1. Phone host + 2 joined phones, Bumper Round: both phones show their own result card when the clock hits 0 and it stays until Next (finding 1).
2. A Bumper Round with a hazard and a shove into a wall: one coin drops, the dropper is dizzy and can't dash for 1 s, nobody can take the dropped coin for the dropper's safe second (finding 2).
3. The last 15 s of a Bumper Round: gold coins appear, the gold cue plays, coins read as gold on a joined phone (finding 2).
4. A 5-round night of Bumper Rounds on Surprise me: no map repeats and the card's selection matches the map played (finding 7).
5. A night with Round Winner/Watch the reveal; a night of only Shape Race rounds (no Bumper), and a solo night: which awards come up "Not won tonight" (finding 3).
6. A night's final scores with a Robo round: Robo's row opacity and its place on a joined phone's standings (findings 8 and 9).
7. A finished Shape Race board on a phone host: the joined phone's celebration, then whether its card shows the picture (finding 5).
8. The awards reveal: press a remote's Back once (finding 11), and Escape.
9. An M13 phone joined to this host and this phone joined to an M13 host: both should say what to do (finding 6).
10. Four players and the cat on the Android TV and a joined phone: frame rate and no flash (acceptance 13).

## Not checked

- `tools/level.sh check` (acceptance 12): the sandbox refused the command twice; `map_check_test`, `map_schema_test`, `four_maps_test` were not run.
- The full test suites: the brief's check is `format analyze` only, so "no existing rule changed" (acceptance 14) rests on a1's report.
- The mock-ups: not re-rendered or compared frame by frame (no browser run). Frame rate, sounds and haptics: device only.

## Self-check (review-rules A1–5)

1. **Every host setup**: findings 1, 5, 6 and 9 are about a joined phone or an older build; each names the setup it fails on.
2. **When kept state starts and ends**: the reveal's timer (`night_reveal_screen.dart:88`) is cancelled on dispose and on `_finish`; the card timer in `puzzle_screen.dart:182` is cancelled on dispose; the Arena's session end is finding 1.
3. **How a new state combines with the others**: the combination table above; the untested pairs are named.
4. **Stay in the job's folder**: this job wrote only this report.
5. **Stop rather than overstep**: nothing needed code; the one check the sandbox refused is under Not checked instead of guessed.

## Decisions

- Ranked 1–4 `must`: 1 is provable and a tester hits it on a phone host; 2 and 3 are in the PRD or G4; 4 is a named build.
- Kept "fix" to one phrase per finding (review-rules D). No double `recordRound` found in one key or tap sequence.
- Treated docs/design/party-night.md as authoritative over the mock-ups where they differ (b2 D1).

## Blocked
None.

## Files changed and checks

- `docs/briefs/m14/r5-review-report.md`: this review (the only file changed).
- `tools/check.sh format analyze`: PASS format (3 s), PASS analyze (12 s); logs in `%TEMP%/thumbparty-check-20261110-170212`.

## Commit message

M14 r5: the full review of the party night (worker pass)

Findings only, no code changed: the Bumper Round's joined-phone result
card is cleared as it appears, the coin drop/gold/dizzy rules and
three of the twelve awards are not built, and the best-times board is
missing, with the acceptance table, decisions and device list.

## Status row

- **r5 (worker pass)**: reviewed; findings in `r5-review-report.md` (4 must, 8 should, 3 later). Open: the fixes, Claude's verification, then the device tests.

## Delete

- none
