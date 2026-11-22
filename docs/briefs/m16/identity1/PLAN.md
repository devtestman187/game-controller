# M16 identity1 plan (item 5, player identity): DRAFT, not run

Owner decisions (Nov 21) are quoted in each brief. Note: docs/HANDOFF.md has no section "11A"; only section 11 was seen.

## What already exists (M14 L7), so this batch is smaller than the PRD reads
Picker in Settings, colour+accessory in the hello, host `_reserveCharacter` with `nearestFreeIn`, `player` message carrying the character, taken notice, `PlayerBadge/ToyBadge` take a character, night/results/score rows carry `character`.
Gaps: no stable ID or spoken name; no way to change the character after the hello (so no lobby/between-rounds gating); phones never get other players' characters (frame roster `pl` is `[number, name]` only); nickname rules and 4 px clip; no Change link on the connect screen; wording of the taken banner; several painters draw by number.

## Waves
| Wave | Job | Scope | Owned files | Turns | Min |
|---|---|---|---|---|---|
| 1 | i1a | ID, spoken name, wire (`identity` capability, `players`, `set_character`, frame `chars`), protocol.md | 10 | 85 | 35 |
| 1 | i1b | nickname rules, clip, Change link, banner text | 13 | 85 | 35 |
| 1 | i1c | split host_server.dart (399), reservation tests | 4 | 65 | 30 |
| 2 | i1d | host: gated change, players broadcast, frame chars (needs a, c) | 9 | 105 | 45 |
| 2 | i1e | phone: capability, send change, own/everyone's character, lobby list | 15 | 100 | 40 |
| 2 | i1f | Arena painters + HUD | 8 | 80 | 35 |
| 3 | i1g | Shape Race workers, score bar, badges, audit | 11 | 100 | 40 |

Total about 620 turns, about 2 h 05 min (35+45+40 by wave max). That is 7 jobs, one over the "about 6" target: the two wave-2/3 painter jobs could not be one job under 120 turns. Waves are in waves.txt. File ownership is disjoint inside each wave; shared files across waves (host_server.dart c then d, phone_text.dart b then e, docs/protocol.md a then d, profile.dart is different files) are sequential only.

## Painter audit (draws by number / forPlayer, not by chosen character)
- test_game: `arena_roster.dart` `arenaCharacterFor` uses `forPlayer(number)` (marble, Robo); `arena_hud_widgets.dart:266` dot `colours.player(player.number)`. Roster type is a `(number, name)` record. Fix: i1f.
- puzzle_game (Shape Race): `worker_painter.dart:82` `ToyCharacter.forPlayer(p.number)`; `PlayerView` has number only. Fix: i1g.
- party_host: `score_row.dart:259` bar `colors.player(row.number)`; `player_badge.dart:89` Robo disc (a Robo seat, fine, check). Fix: i1g.
- controller_app: `host_chip.dart:49` `PlayerBadge(number: player)` with no character. Fix: i1e.
- Already by character (need only a non-default test): PlayerBadge/ToyBadge users (night start names, reveal, scoreboard, results, join side panel, away card, pause menu, arena waiting, result card).
- Defaults only when missing: `round_results.dart:40-48`. Not players: puzzle side colours, map cards, game pictures, confetti.

## File sizes / conflicts
Over or at limit and touched: `host_server.dart` 399 (i1c splits it to <=370), `server_game_host.dart` 395 (i1d must move code out), `messages.dart` 380 (i1a adds a `part` line, must move one out), `score_row.dart` 346 (i1g splits), `settings_profile_section.dart` 371 (i1b moves the nickname row out), `host_connection.dart` 364. No same-wave ownership conflict. `puzzle_screen.dart` (372) is deliberately not touched.

## Pause points
The driver stops and reports (does not continue) at the end of wave 1 after the wave review, at the end of wave 2 after the wave review, and again before any fix-job round, so the main session can check usage. Baseline: weekly 44%, 5-hour window resetting 03:10Z; pause threshold weekly 54%. If usage passes 10% of the owner's limit the batch pauses at the next of these points.

## Watch list (process2 confirmation)
mine.sh used by workers; STOP.md written at every stop and read first; churn handled automatically; lock + RUN_MAX_MIN in force; worker-extract appended; check.sh tools passes; no hand-merges; turns and minutes inside limits; driver usage below bugs1 (about 63 calls, 132k cache-write, 6.5M cache-read).

## Risks / owner questions
1. Palette names start with Blue (colour 1), so IDs read `blue.ears`, not the example `red.bow`; spoken "the Blue Bow". Fine unless the owner wants a rename.
2. Mid-round change holds until the round ends (i1d); the phone shows its pick at once but the TV changes next round. Assumed OK.
3. Cat Chaos draw path unverified; i1g audits it.
4. i1d is the riskiest (105 turns, three files near the limit).

## Flow (owner approved Nov 21)
1. Wave 1 on the current process2 setup; driver polls with 2.5-min waits (baseline).
2. Pause after wave 1 review: a Haiku agent scores the watch list from run.log (items not exercised are marked "not tested"); main session checks usage.
3. process3 tools batch, tools/ only, about 45 min: B.1 (three wait-run.sh fixes), B.8 (runner enforces 120-turn cap), B.4 (RESULT line), B.5 (tidy.sh); `bash tools/check.sh tools` must pass before resuming.
4. Waves 2 and 3 on the improved tools; a Haiku waiter polls wait-run.sh while the Sonnet driver makes no calls (B.2 trial). Usage compared against wave 1 and bugs1.
5. After the batch: B.3, B.6, B.7, B.9.
