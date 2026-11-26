job: night1b n1d — scoring v2 pinned: x2 last round, no random bonuses, one champion rule
stop: no new points-by-place mapping (the plan keeps game points; "placement points become Bolts" is M17b); no change to scoreboard rows, ties, left players or awards; no pause logic; no UI
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_state.dart:262-310 (rows: sorted by total, ties share a place, a player who left keeps their row) · packages/party_host/lib/src/night/champion.dart (whole, 114 lines: ChampionChain.quickNight, ChampionEntry, champions()) · packages/party_host/lib/src/night/party_night.dart:8-47 (nightPointsScale 1, lastRoundPointsScale 2, settingsForRound) · packages/party_host/test/champion_test.dart (the pin against rows) · plan, quoted (M17-proposals Q3): "Keep x2, announced at the start. Drop random bonuses." Owner O1, Nov 26: "I am good with the defaults suggested" (Quick night champion = most points, ties share).
changes: NightState.championsAmong
model: haiku
turns: 45
expected-min: 20
tests-first: exempt for the x2 and no-bonus pins (behaviour already right on the base); the championsAmong test fails on the base
do:
1 night_state.dart: add `Set<String> championsAmong(Iterable<GamePlayer> players)`: map each of `rows(players)` to `ChampionEntry(id: row.id, points: row.total)` and return `ChampionChain.quickNight.champions(...)`. Doc: the night's champion under the Quick night rule; the scoreboard's place 1 and this must agree (the test pins it). Import champion.dart (same folder). Keep the file at 380 lines or fewer (it is 343).
2 Tests: NEW packages/party_host/test/night_scoring_test.dart, written and run first: (a) nightPointsScale is 1 and lastRoundPointsScale is 2; (b) NightChaos.settingsForRound(lastRound: true) has pointsScale 2 and chaos off, lastRound: false has scale 1 and keeps the host's chaos; (c) NightState.record adds exactly the result's points to totals, no extra bonus (two rounds, three players; each total equals the sum of the points given); (d) championsAmong equals the ids of NightRow.place == 1 rows for: one leader, a tie for first, everyone at 0, a player who left holding the lead (keeps the win share, as the rows do today).
3 Report: the getter, and one line saying "place" was left as the scoreboard's shared place (ties share, a player who left keeps theirs).
4 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/night_state.dart · packages/party_host/test/night_scoring_test.dart
check: format analyze host
report: docs/briefs/m17/night1b/n1d-report.md
