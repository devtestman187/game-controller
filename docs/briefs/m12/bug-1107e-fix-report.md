# M12 bug 1107e — G4 report: the back from the results, the summary's copies, the paused input, the log

Done at G4, the gate the brief names, and the five items of the brief: every back on the results goes to the game
picker; the host phone's system back pops the games before it stops hosting; a summary keeps copies of its rounds and
each player's games; an input that arrived during a pause is no `received_to_drawn` sample; the host log (`host`) has
the round's short lines. New file: `packages/party_host/test/round_log_test.dart`. No file outside `allow:` was
edited (see Question 4 about the three generated Windows files a `flutter pub get` touched).

## Files changed

- `packages/party_host/lib/src/ui/puzzle_screen.dart` (240 lines) — the screen is wrapped in a `PopScope` whose
  `canPop` is `result == null`: on the results the route refuses to pop and the callback calls `leaveForGamePicker`,
  so the Back button, B on any pad and the system back all land on the picker. `_log` (a `LogSink` on `logProvider`,
  source `host`) is made in `initState`; `'Round started: …'` is logged there, `'Round ended: …'` in `_finished`,
  `'Results: …'` in `_rematch`, and `'Results: back to the games'` in the new `_leaveForGames`. `build` was 71 lines
  with the new wrapper (review.sh's 60-line limit), so the screen tree moved to `_screen(Puzzle?, MatchResult?)`.
- `packages/party_host/lib/src/ui/puzzle_screen_widgets.dart` (183 lines) — the results' title and end time are now
  top-level `_resultsHead(result)` (a record: title + colour), `_endTime(result)` and `_playersLine(count)`, so
  `_Results` and the new log lines say the same words: `Done!`, `Time's up!`, `Left wins!`, `Right wins!`, `Draw!`.
- `packages/party_host/lib/src/ui/pause_menu.dart` (241 lines) — `_pause` logs `'Round paused: P<n> pressed Start'`
  and, when the menu closes without Quit, `'Round resumed: the menu closed'`; a listener on `hostAwayProvider` logs
  `'Round paused: the host went away'` / `'Round resumed: the host is back'`; `_tick` notes the away players
  (`_noteAway`) and logs `'P<n> away: the round waits for them'` / `'P<n> back: the round goes on'` once each.
- `packages/party_host/lib/src/testing/host_fakes.dart` (340 lines) — `FakeGameHost.away` (a set of control IDs) puts
  `away: true` on those players, so a test can make a phone drop without a socket.
- `packages/party_host/test/support/host_harness.dart` (205 lines) — three helpers the new tests share: `startRound`
  (P1 joins and starts from the join screen), `lockEveryPiece` (puts every piece of a side in place by hand, so the
  round ends on the next steps) and `endRound` (the three 16 ms frames the rules need to see the end).
- `packages/party_host/test/puzzle_results_test.dart` (259 lines) — the two triage tests: B on the phone and the
  Back button on the results land on the picker (`pickShapeRace` found, `ShapeRaceScreen` and `PuzzleScreen` gone).
- `packages/party_host/test/round_log_test.dart` (**new**, 131 lines) — seven tests, one per kind of line (below),
  each mounting the host with a `LogBuffer` of its own through `logProvider`, and, for the host-away lines, a
  `ValueNotifier(false)` as `hostAwayProvider`.
- `controller_app/lib/src/host/host_screen.dart` (80 lines) — the route's `PopScope` callback now asks the games'
  navigator first: while `gamesKey.currentState.canPop()` it calls `games.maybePop()` (which reaches the results'
  `PopScope` and so the picker), and only at the picker root does it stop hosting.
- `controller_app/test/host_mode_test.dart` (289 lines) — 'the system back on the results goes to the picker and the
  host stays on': a real solo round on this phone, `handlePopRoute()`, then `pickShapeRace` is up, `PuzzleScreen` is
  gone, `HostScreen` is still there and `host.live` is true. The picker's system-back test was already there ('the
  system back press stops hosting rather than leaving the server behind it') and still passes: at the picker root,
  `canPop()` is false and the host stops.
- `packages/metrics/lib/src/session.dart` (309 lines) — `'rounds'` is a list of copies of the round maps.
- `packages/metrics/lib/src/session_player.dart` (190 lines) — `'games'` is a copy of each player's game counts.
- `packages/metrics/test/metrics_test.dart` (246 lines) — 'a summary does not change as the session goes on'.
- `packages/game_kit/lib/src/game_session.dart` (301 lines) — `_resumedAtMs` (set in the `paused` setter when the
  round comes back); `_sample` still remembers every new arrival, so it is never counted twice, but only puts the ones
  that arrived after the resume in `_fresh`.
- `packages/game_kit/test/session_test.dart` (240 lines) — 'an input that arrived while paused is no
  received_to_drawn sample'.
- `docs/briefs/m12/bug-1107e-fix-report.md` — this report.

## The log lines, exactly

All with the source `host`. `P<n>` is the player's number; a title and a time are the results' own words.

| When | Line |
| --- | --- |
| a round starts, a solo round | `Round started: puzzle, solo, 1 player` |
| a round starts, a race | `Round started: puzzle, 1v1, 2 players` |
| a round ends | `Round ended: Done! (12.3 s)`, `Round ended: Left wins! (45.6 s)`, `Round ended: Time's up!` |
| a player leaves the results by back (Back, B, system back) | `Results: back to the games` |
| a player leaves the results to play again | `Results: Play again` |
| a player leaves the results to rematch | `Results: Rematch` |
| the round pauses from the menu | `Round paused: P1 pressed Start` |
| the round resumes from the menu | `Round resumed: the menu closed` |
| the round pauses because the host app went away | `Round paused: the host went away` |
| the round resumes because the host app came back | `Round resumed: the host is back` |
| a phone is away and the round waits for it | `P1 away: the round waits for them` |
| that phone is back | `P1 back: the round goes on` |

Values seen in real runs: `Round started: puzzle, solo, 1 player`, `Round ended: Done! (0.3 s)`,
`Round started: puzzle, 1v1, 2 players`, `Round ended: Left wins! (0.1 s)`, `Results: back to the games` (from the
phone app's own run, host_mode_test.dart). The time is the winning (or solo) side's `timeS` to one decimal; it is left
out when no side finished (`Time's up!`).

## Tests, each failing first

I put every test in place, ran it with the fix reverted, then restored the fix and ran it again. The failures:

- `puzzle_results_test.dart` — 'on the results B on the phone goes to the game picker' and 'on the results the Back
  button goes to the game picker': *Found 0 widgets with key [<'pickShapeRace'>]* (both; the route popped one short).
- `round_log_test.dart` — 'a player leaving the results by back goes in the host log': the same key was missing, so
  the line was never logged.
- `host_mode_test.dart` — 'the system back on the results goes to the picker and the host stays on': with the old
  `stop()`-only callback, *Found 0 widgets with key [<'pickShapeRace'>]*, and the host was stopped.
- `metrics_test.dart` — 'a summary does not change as the session goes on': *Expected: empty / Actual: [{'game':
  'puzzle', 'timeS': 3.5, 'players': 1}]* — the early summary's `rounds` was the session's live list.
- `session_test.dart` — 'an input that arrived while paused is no received_to_drawn sample': *Expected: empty / Actual:
  [(playerId: a, stage: received_to_drawn, ms: 36)]*.

The other six log tests are new lines that did not exist before, so they fail on the old code by construction.

## Test counts, before and after

Measured with `tools/check.sh` on this machine, before the first edit and after the last one:

| Check | Before | After |
| --- | --- | --- |
| metrics | 88 | **89** |
| kit | 33 | **34** |
| puzzle | 106 | 106 |
| host | 83 | **92** (the two results tests, the seven log tests) |
| phone | 338 | **339** |
| tv | (the check prints no count) | unchanged |

## Checks run

- `tools/check.sh format analyze metrics kit puzzle host phone tv` — PASS, all eight (format 1 s, analyze 5 s, metrics
  89 in 3 s, kit 34 in 4 s, puzzle 106 in 13 s, host 92 in 13 s, phone 339 in 22 s, tv 9 s).
- `tools/review.sh` — `review: 0 fail, 3 note`: the three notes are `game_session.dart` 301 lines,
  `session.dart` 309 lines and `host_fakes.dart` 340 lines (lib limit 400, aim 300); none of them is a fail.
- One earlier `tools/check.sh …` run had `phone` fail once on 'a phone hosting plays its own game: the pad, the menus,
  and a solo Shape Race' while eight suites ran back to back; the test passes alone, in the file alone and in the two
  later full runs, so it is the timing-sensitive test s9c warns about (it waits on the host's real work), not this
  job's change.

## Questions

1. The player-away *pause* does not exist yet: job B of bug 1107d (`playersAwayProvider`, the away card, "the round
   waits for them") is planned but not built, and today only the arena's `Paused`/`goOnWithout` machinery knows about
   away players. So the away lines are round moments (`P1 away: the round waits for them`), not `Round paused: …`
   lines, and no `Round paused: P1 went away` can be logged until B lands. Should B add that pair of lines, or is the
   current wording what the milestone wants?
2. Quit in the pause menu logs nothing of its own: it goes back to the picker without a `Round resumed: …` line (the
   round did not resume) and without an end line (the round was quit, not finished). Is a `Round quit: …` line wanted
   in a later job, or should the log stay with the four kinds the brief lists?
3. The round-start line says the game (`puzzle`), the format and the number of players, no names or codes, since the
   log can be shared. A race's sides are the format's words; the puzzle's own id is not logged. Is the puzzle worth
   a line when it is a fixed one instead of a random one?
4. Three generated Windows files (`tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h`,
   `generated_plugins.cmake`) show as modified: `flutter pub get`, which every test run does, rewrites them. I did not
   edit them and can't restore them (no git checkout in this job). They should be left as they are unless CI wants
   them regenerated.

## Suggestions

- When job B lands, its away pause should log through the same `_log` (the pause menu's sink is the natural place) so
  the log has one wording for "the round waits" whether the reason is the menu, the host or a phone.
- `FakeGameHost` is at 340 lines (review.sh's aim is 300). The away set is two lines; splitting the view, stats and
  haptics fakes out would take it back under if that matters later.

## Commit message

Fix the results' back, summary aliasing and paused-input samples

Every back on a round's results (the Back button, B on any pad, the
system back) now goes to the game picker, not one route short of it
where the next A started another game, and the host phone's system back
pops the games' navigator before it stops hosting. A summary keeps
copies of its rounds and of each player's games, so one taken mid-session
is not changed by what follows. An input that arrived during a pause is
no received_to_drawn sample: it waited for the round, not for the host.
The host log has the round's short lines: start, end, leaving the
results (back, Play again, Rematch), and pausing and resuming why.

## Status row

M12 bug 1107e fixed at G4: the results' every back lands on the game picker, the host's system back pops the games
before stopping, summaries no longer alias the session, a paused input is no received_to_drawn sample, and the host
log has the round's lines; open: the player-away pause and its log line (bug 1107d job B).

## Delete

- none
