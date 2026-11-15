## Summary

A robot's win is now visible, and the rounds CSV says who won each round.

- `SessionCollector.roundEnded` takes `robotWin` (default false) and writes
  `robot: true` into the round JSON only when it is true. No player's wins
  count it, and old rounds without the key parse as before.
- `ArenaSession` adds `robotWin: true` to the `round_end` data when
  `game.winnerId == roboPlayerId`; `playerId` stays null, as before.
- `SessionRecorder` passes it on: `robotWin: r.data['robotWin'] == true`.
- The rounds CSV header ends `…,host_app,winner,draw,players`:
  the winning player's number, `robot`, or a team's numbers (`1 2`); `1` for a
  draw; the round's player count. Never a name or a device id.

Tests first, seen failing then passing:

- metrics `round_winner_csv_test.dart` (new, 6 tests): on the old code the file
  did not load — `Error: No named parameter with the name 'robotWin'`. After
  the change 6/6 pass; the package went from 117 to 123 tests, all passing.
- test_game `robot_win_record_test.dart` (new, 3 tests): on the old code the
  Robo test failed `Expected: true / Actual: <null>` at line 51 (no
  `robotWin`), the other two passed since they assert its absence. After the
  change 3/3 pass (`arena_session_test.dart` too, 19/19 in the two files).
- party_host `round_stats_test.dart` (one test added): with the recorder's
  `robotWin:` line removed it failed (1 of 4), restored it passes 4/4.

Checks: `tools/check.sh format analyze metrics arena host` — format PASS,
analyze PASS, metrics PASS (123), arena PASS (235), host FAIL once on the known
Windows temp-folder flake in `live_stats_lifecycle_test.dart`
(`PathNotFoundException … tp-stats-life-…/sessions`, the flake m12 s8c notes and
b6's report met); `tools/check.sh host` alone then passed 460/460, and a second
combined run failed again at that same flake. Nothing in this diff touches files
or temp folders.

## Files changed

- `packages/metrics/lib/src/session.dart` — `roundEnded` gains `bool robotWin`
  (doc line), and the round JSON gains `'robot': true` when it is set.
- `packages/metrics/lib/src/report_rounds.dart` — `roundsCsvHeader` gains
  `winner,draw,players` at the end; `_roundCsv` appends the three cells and
  `_winner` names the winner (`robot`, numbers, space joined, or empty).
- `packages/metrics/test/round_winner_csv_test.dart` — new: header, player
  winner, robot win, draw, team win, an old round.
- `packages/metrics/test/csv_app_version_test.dart` — the a1 header check now
  asks that `host_app` is the tenth column (it is no longer last), and the row
  expectations gain `,,` (or `,`) for the new columns.
- `packages/metrics/test/report_games_test.dart`,
  `packages/metrics/test/report_rates_test.dart`,
  `packages/metrics/test/report_two_hosts_test.dart` — CSV row literals gain the
  `,,<players>` cells; no assertion was removed.
- `packages/party_host/lib/src/session_recorder.dart` — passes
  `robotWin: r.data['robotWin'] == true`.
- `packages/party_host/test/round_stats_test.dart` — one test: a `round_end`
  with `robotWin: true` and winner `robo` files a round with `robot: true`, and
  the player's game counts show `rounds` but no `wins`.
- `packages/test_game/lib/src/arena_session.dart` — `round_end` data gains
  `robotWin: true` when Robo won.
- `packages/test_game/test/robot_win_record_test.dart` — new: Robo wins and the
  round says so; a player's win and a two-player Bumper Round carry no
  `robotWin`.
- `docs/briefs/m14/stats1/a2-round-winner-report.md` — this report.

## Computed test values

- Header: `session,host,game,hz,time_s,battery_start,battery_end,thermal,tags,host_app,winner,draw,players`
  — 13 fields (10 from a1 + 3).
- Winner row (session s1, windows, 60 Hz, 60 s, host app 0.14.0, two players,
  phone-b = player 2 won):
  `s1,windows,arena,60,60.0,,,,,0.14.0,2,,2`.
- Robot row (one player, Robo won):
  `s1,windows,arena,60,60.0,,,,,0.14.0,robot,,1`; the round JSON is
  `{game: arena, hz: 60, timeS: 60.0, players: 1, robot: true}`.
- Draw row (two players): `…,0.14.0,,1,2`; round JSON adds `draw: true`.
- Team row (winners [1, 2]): `…,0.14.0,1 2,,2`.
- Old round `{game, hz 60, timeS 12.5}` with host app 0.13.0:
  `s1,windows,arena,60,12.5,,,,,0.13.0,,,`.
- a1's summary round (no `players` key), no app: `a1,windows,arena,60,60.0,,,,,,,,`
  (13 empty-led fields, 12 commas).
- Robo's Bumper Round with `Random(1)` and a lone still player: phase `over`
  after the minute, `winnerId == 'robo'`, `round_end.playerId` null,
  `data['robotWin']` true.

## Decisions

- A team win joins its numbers with a space (`1 2`): a CSV cell holds no comma,
  and the round must still say who won.
- `robot` fills the winner cell and no player number is written, since a robot
  win has no player number to give.
- `draw` is `1` (not `true`), as the brief asks; a round that is neither a win
  nor a draw leaves both cells empty.
- `players` is the round's own count and stays empty for a summary without it,
  so older exports keep their shape.
- `robotWin` in metrics only writes `robot: true`: no `winner`, no `winners`,
  no player's win count changes (brief: playerId stays null).
- Four existing metrics CSV expectations were edited for the appended columns
  rather than adding a second CSV function: the columns are additive and the
  old ones keep their places.
- `robotWin` is set where the round's `playerId` is already nulled for Robo, so
  both rules sit in one place.

## Self-check (review-rules part A)

1. Every host setup: unaffected by host type — the round data comes from the
   session on either host and the CSV reads the summary. Tested by
   `report_two_hosts_test.dart` (TV and phone rows) and
   `round_winner_csv_test.dart`.
2. Kept state: `robotWin` lives only in the round JSON, written with the round
   and dropped with it; an abandoned round still writes no winner data.
   Tested by `round_stats_test.dart` (abandon and robot cases).
3. Combining states: it neither pauses nor blocks anything; a draw and a robot
   win cannot both be true (a robot win has one winner id and `draw` false, as
   the Bumper Round sets them). Tested by the robot test's data assertions.
4. Folder: only files in `allow:` were written.
5. Stop rather than overstep: nothing outside `allow:` was needed.

## Questions and suggestions

1. Should a robot win appear in the report's printed tables (e.g. a "Robo wins"
   count per game)? Only the CSV says it today.
2. Is a space the right team separator, or would `+` (`1+2`) read better in a
   spreadsheet? Either keeps the cell comma-free.
3. `tools/check.sh … host` failed 4 of 5 runs on the known temp-folder
   flake; it passed 460/460 alone. Worth a bug of its own.
4. `session_recorder`'s pass-through could take its `robotWin` from the round's
   winner id instead of a second key; the brief asked for the key, so that is
   what it reads.

## Hand-over

- The rounds CSV now ends with `winner,draw,players`; any reader keyed on the
  old 10 columns must read by name or from the left, as the header is longer.
- Rounds from a host older than this build simply leave the three cells empty;
  no migration is needed.
- A robot win is in the round JSON as `robot: true`; nothing counts it for a
  player, and no new public type was added.
- Not done: no table counts robot wins, and the arena's own HUD/results are
  untouched.
- Open: the host-suite temp-folder flake (question 3).

## Commit message

stats: winner, draw and players in the rounds CSV; robot wins recorded

A robot's win was invisible: the arena's round_end nulled its player and said
nothing else, and the rounds CSV had no winner column. Now the arena writes
robotWin when Robo wins, the recorder passes it on, and metrics keeps it as
robot: true in the round, counting no player's win. The CSV gains winner (a
player number, robot, or a team's numbers), draw (1 or empty) and players (the
count) after host_app, so older columns keep their place; rounds without the
key leave the cells empty. Tests: a new metrics CSV test and a new test_game
robot-win test, both seen failing first, plus one recorder test.

## Status row

Round winner, draw and player count in the rounds CSV, and a robot win recorded as `robot: true` with no player's win counted — done; report tables still don't count robot wins, and the host-suite temp-folder flake is open.

## Delete

- none
