# M14 m2: "By game and feature" — report

Status: done. Every check in `check:` passes; `tools/review.sh` reports 0 fail (7 notes, all of them
pre-existing spans of files this job touched, listed under "Notes").

## What changed

Rounds now say what they were, in the summary's existing `tags` list (the schema stays 1: the key only
appears when there is something to say, so an older session reads as it did), and the report sums them into
one new table. The games write their own facts; the host adds the one fact no game can know — which of a
night's rounds this one is — through a `roundTags` argument on each game's session, so no game imports
`party_host`, and no screen re-implements the Robo seat or the map's choice.

- `packages/metrics/lib/src/report_games.dart` (new) — `RoundTag` (the tag names and `of`/`valueOf`), `FeatureRow`, `gameFeatureRows`, `gameFeatureTable`, `partyNights`, and the readers that place a round or a rating in its rows.
- `packages/metrics/lib/src/session.dart` — `roundEnded(..., tags:)` files the round's tags; `rating(..., roundTags:)` files the round's tags on the answer, so a rating counts where the round it asked about counts. Both go through `_roundTags`: at most `maxRoundTags` (8), each matching `^[a-z0-9_.-]{1,32}$` (the dash for map ids like `toy-factory`), so nothing but a technical string can get in.
- `packages/metrics/lib/src/report_table.dart` — `report()` prints the new table and the party-night line between "By device and mode" and "By host and where they watched".
- `packages/metrics/lib/src/report_rounds.dart` — the round CSV gains a `tags` column (space separated; a tag holds no comma, so the columns stay lined up). The CSV is already per round, so no second CSV is needed.
- `packages/metrics/lib/metrics.dart` — exports `report_games.dart`.
- `packages/metrics/test/report_games_test.dart` (new) — the table's rows and numbers from a fixed set of sessions, the unknown row, the nights line, the CSV, the report's order.
- `packages/metrics/test/round_tags_test.dart` (new) — what a round and a rating keep: the tags, none, the dropped and the capped ones, the rating's round.
- `packages/metrics/test/report_rates_test.dart`, `packages/metrics/test/report_two_hosts_test.dart` — the CSV expectations with the new column.
- `packages/party_host/lib/src/session_recorder.dart` — a `round_end`'s tags go into the round, and are kept for the rating prompt it asks, so the answer says which round it was about.
- `packages/party_host/lib/src/night/party_night.dart` — `nightRoundTags(night)`: `['night_2of3']` during a night, `[]` outside one.
- `packages/party_host/lib/src/ui/game_screen.dart` — sets the round's host tags when the round starts and passes them to `ArenaView`.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` — passes them to `PuzzlePlayView` (read as the round starts).
- `packages/party_host/test/round_stats_test.dart` — a round's tags reach the summary's round.
- `packages/party_host/test/party_night_test.dart` — `nightRoundTags` for no night, the first round and the second.
- `packages/party_host/test/night_round_test.dart` — a night's Shape Race round hands `PuzzlePlayView` `night_1of3`.
- `packages/party_host/test/arena_night_test.dart` — a night's second Bumper Round hands `ArenaView` `night_2of3`.
- `packages/test_game/lib/src/arena_session.dart` — the round's own tags: mode, map, Robo's level when it had a seat, `finished`, then the host's.
- `packages/test_game/lib/src/arena_view.dart` — `roundTags` to the session, at creation and on every widget update.
- `packages/test_game/test/arena_session_test.dart` — a Bumper Round with Robo on a map, a round with two players (no Robo tag), an abandoned round (no tags at all).
- `packages/puzzle_game/lib/src/puzzle_session.dart` — the round's own tags: the Chaos level it played at, `finished` when a side completed the picture, then the host's.
- `packages/puzzle_game/lib/src/puzzle_report.dart` — `round_end` carries the tags when there are some.
- `packages/puzzle_game/lib/src/play_view.dart` — `roundTags` to the session.
- `packages/puzzle_game/test/puzzle_session_test.dart` — a solo picture finished at Chaos party, and a round that ran out of time (no `finished`).

## The tags

Every tag is `kind_value` on the round's `round_end`, read by one row of the table. A tag of a kind the
report doesn't know is kept in the summary and ignored by the report, so a newer game can add one.

| Tag | Written by | Means |
| --- | --- | --- |
| `finished` | the game | The round reached its game's own end: the Bumper Round's clock ran out, a race reached its goal, a Shape Race side completed the picture (the celebration, T15). A Shape Race round that ran out of time has none. |
| `mode_race`, `mode_bumper` | the Arena | The Arena's mode (G9). |
| `map_<id>`, e.g. `map_playroom`, `map_toy-factory` | the Arena | The map the round played on, by id (k1b). |
| `robo_easy`, `robo_medium`, `robo_hard` | the Arena | Robo's level, only on a round Robo had a seat in (§7a: a Bumper Round with one player). |
| `chaos_off`, `chaos_little`, `chaos_party` | Shape Race | The Chaos level the round played at (G3; a night's last round plays at off, as `NightChaos` sets it). |
| `night_<n>of<m>`, e.g. `night_2of3` | the host | A party-night round: its number of the night's, and how many the night plays (G2). Read when the round starts, since the night counts the round when it ends. |

Nothing names a person: a map's id, a level, a number. The tag pattern keeps any words out even if a
caller passes them.

## A sample of the table

From the fixed set the new tests use (two sessions: a night of two Bumper Rounds with Robo and a race, a
Shape Race night of two rounds, and two rounds from before M14):

```
By game and feature
group            rounds  minutes  players  avg players  finished  good  okay  bad
---------------  ------  -------  -------  -----------  --------  ----  ----  ---
arena bumper          2      2.0        4          2.0         2     1     0    0
arena race            1      0.5        2          2.0         1     0     1    0
puzzle                2      3.7        6          3.0         1     0     0    1
map playroom          2      2.0        4          2.0         2     1     0    0
map toy-factory       1      0.5        2          2.0         1     0     1    0
robo easy             1      1.0        2          2.0         1     -     -    -
robo hard             1      1.0        2          2.0         1     1     0    0
chaos little          1      1.8        3          3.0         0     -     -    -
chaos party           1      1.8        3          3.0         1     0     0    1
night 1 of 3          2      2.8        5          2.5         2     1     0    1
night 2 of 3          2      2.8        5          2.5         1     -     -    -
night 3 of 3          1      0.5        2          2.0         1     0     1    0
unknown               2      2.5        3          1.5         0     0     0    1

Party nights: 2 started, 1 finished, 2.5 rounds a night
```

The rows answer different questions about the same rounds: a round counts in its game and mode, its map,
Robo's level, its Chaos level and its night's round. A rating counts in the rows of the round it asked about
and nowhere else (one good rating of the first Bumper Round is one of `arena bumper`, `map playroom`,
`robo hard` and `night 1 of 3`). A dash means nobody rated that row; a zero means nobody said bad.

## The numbers, worked out

From that fixed set (the values the test expects, so a change in any of them fails the test):

- `arena bumper`: 2 rounds of 60 s = 120 s = 2.0 min, 2 + 2 players, 2.0 a round, both finished, one good.
- `arena race`: 1 round of 30 s = 0.5 min, 2 players, 2.0, finished, one okay.
- `puzzle`: 2 + 110 s = 220 s = 3.7 min, 3 + 3 players, 3.0, one finished (the second ran out of time), one bad.
- `map playroom` and `map toy-factory`: the rounds above with those maps, same numbers.
- `robo hard` (round 1) and `robo easy` (round 2): 1 round of 60 s each, 2 players, finished; only the hard one was rated.
- `chaos party` (finished) and `chaos little` (not): 1 round of 110 s = 1.8 min, 3 players, 3.0; the bad rating is the party round's.
- `night 1 of 3`: 60 + 110 s = 170 s = 2.8 min, 2 + 3 players = 5, 2.5 a round, both finished, one good and one bad.
- `night 2 of 3`: the same 170 s, 5 players and 2.5, one finished, no ratings.
- `night 3 of 3`: 30 s = 0.5 min, 2 players, 2.0, finished, one okay.
- `unknown`: the two untagged rounds, 90 + 60 s = 150 s = 2.5 min, 1 + 2 players = 3, 1.5, none finished, the untagged bad rating.
- `Party nights: 2 started` (two rounds are a night's 1 of 3), `1 finished` (one round is its 3 of 3), 5 night rounds over 2 nights = `2.5 rounds a night`.

## Tests: before and after

| Check | Before | After |
| --- | --- | --- |
| metrics | 91 | 106 |
| kit | 73 | 73 |
| arena | 199 | 202 |
| puzzle | 360 | 362 |
| host | 376 | 380 |
| phone | 463 | 463 |
| tv | pass | pass |

The 15 new metrics tests are 9 in `report_games_test.dart` and 6 in `round_tags_test.dart`; arena gained 3,
puzzle 2, host 4. Each was written to fail first: the report tests failed on the missing table, the tag tests
on the missing `tags` key (the collector dropped what it was given), and the two screen tests on the widget's
missing `roundTags`.

`tools/check.sh format analyze metrics kit arena puzzle host phone tv`: all PASS (metrics 106, kit 73,
arena 202, puzzle 362, host 380, phone 463, tv).

## Notes

`tools/review.sh`: 0 fail, 7 notes, all on files older than this job's lines: `session.dart` 351 lines (the
additions are ~20), `game_screen.dart` 399 and `puzzle_screen.dart` 399 (both were already within a few lines
of 400; see Decisions 8), and three function lengths the tool measures loosely. One of those is a false
start at `puzzle_session.dart:23` (`labels: {` of `puzzleLayout` is read as a function's opening, and its span
runs to the end of the private constructor).

## Decisions (low-usage mode)

1. Tags in the round's existing `tags` list, not a new summary field: the brief prefers it, the schema stays 1, and an older session reads exactly as before (the key is left out when there is nothing to say).
2. Both games write their own facts (mode, map, Robo, Chaos, finished) and the host adds only the night tag through a `roundTags` argument: a game may not import `party_host`, and the screen is the only place that knows the night.
3. The host copies the round's tags onto the rating it asked about (`'round': [...]`): that is how a rating lands in the right rows without being counted twice (a rating's own game row is the round's).
4. A rating without tags (an older session, or a game that writes none) goes under `unknown` with its round: nothing is dropped.
5. Ratings show a dash when a row has none, and a zero when a row has ratings but none of that face: it matches the report's other tables ("nobody said" vs "nobody said bad").
6. The nights are one line under the table ("Party nights: 2 started, 1 finished, 2.5 rounds a night") rather than columns, since a night is not a round.
7. The CSV gains a `tags` column instead of a second file: it is already one row per round, and a tag holds no comma.
8. `PuzzleSession` takes no `roundTags` constructor argument, unlike `ArenaSession`; `PuzzlePlayView` sets the field after making the session (and on each update). Reason: `puzzle_screen.dart` was 4 lines under 400 and `puzzle_session.dart` 2 lines under a review-tool span; both had to stay inside the limits. `ArenaSession`'s argument stayed because the Arena screen's round start needs the tags fixed there.
9. The table keeps the summary's game names (`arena`, `puzzle`) rather than the shop names ("Arena", "Shape Race"): the report has always named games by their records, and a rename would be a separate change.
10. The Arena's `finished` is true for every round the report counts: a round the rules never ended isn't recorded as a round at all (abandoned, M14 N1). `finished` is therefore a real signal for Shape Race and a constant for the Arena; it is kept for both because the column asks about rounds, not games.

## Self-check (review-rules part A)

1. **Every host setup.** Not affected: the tags are written by the host's game session whichever app hosts, and the summary is the same file for all; `puzzle_game`/`test_game` tests cover the sessions, `night_round_test` the phone's host screens and `arena_night_test` the host harness, and an older host or phone reading the session sees the summary it always did (`round_tags_test`: "a round with no tags has none in its summary").
2. **When kept state starts and ends.** The host's tag starts with the round (`game_screen._start`, `puzzle_screen`'s first build) and is empty outside a night (`PartyNight` null); the session keeps it only until its `round_end`, and a new round builds a new session (`night_round_test`, `arena_night_test`, `party_night_test`: "a round started during the night says which of the night's it is").
3. **How a new state combines with the others.** No state is added: nothing pauses, hides or blocks. The tags ride the `round_end` that already exists, so pause, away and Get ready change nothing, and an abandoned round (pause menu's Abandon, the host lost) records none (`arena_session_test`: "an abandoned round claims no finish in its tags"; `puzzle_session_test`'s abandon test sees the round's data unchanged).
4. **Stay in the job's folder.** Only files inside `allow:` were written (24 files, below); nothing else was touched.
5. **Stop rather than overstep.** Nothing outside `allow:` was needed and the brief matched the code; the file-length limits forced the shape of Decision 8 rather than a stop.

## Files

See "What changed" above: 24 files, 3 of them new (`report_games.dart`, `report_games_test.dart`,
`round_tags_test.dart`).

## Questions

1. The table says `arena bumper`, `arena race` and `puzzle`. Is that the wish, or should it print the shop names ("Arena bumper", "Shape Race")? One label function changes it.
2. Should a night's rounds also get a row of the night as a whole (its three rounds' totals), or is the `night N of M` set plus the "Party nights:" line enough?
3. Chaos is written for every Shape Race round, including a night's last round, where `NightChaos` sets it to off; so a night's last round counts under `chaos off`. Keep it that way?

## Commit message

M14 m2: the stats report's "By game and feature" table

Rounds keep tags in the session summary (schema 1): the Arena's mode,
map and Robo's level, Shape Race's Chaos level, whether the round
finished, and the host's night round (night_2of3). The host copies a
round's tags onto the rating it asks. The report sums them into one
"By game and feature" table — a row per game and mode, per map, Robo
level, Chaos level and night round — plus a party-night line, and the
round CSV gains a tags column. Rounds from before M14 count as unknown.

## Status row

M14 m2 done: the report's "By game and feature" table (rows per game and mode, map, Robo level, Chaos level and night round; the party-night line), round tags recorded by the Arena, Shape Race and the host, a tags column in the round CSV, old sessions under unknown; format, analyze, metrics (106), kit (73), arena (202), puzzle (362), host (380), phone (463) and tv pass; open: the owner's device tests and a look at the table on real sessions.

## Delete

- none
