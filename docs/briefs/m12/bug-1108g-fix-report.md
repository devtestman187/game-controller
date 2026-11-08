# m12 bug 1108g — the away grace and the host's pause in the host log

Job: [bug-1108g-fix.md](bug-1108g-fix.md). Gate: stop after the fix. Status: done.

## The bug

The log had no line when an away player's grace ran out: `P2 away: the round waits for them` at 08:14:39 and
`P2 back: the round goes on` at 08:15:14 read as a 35 s wait when the round had gone on at 30 s. And with the race
results up (the round over) the host app going away logged `Round paused: the host went away`, and coming back
`Round resumed: the host is back`, though no round was running.

Nothing told the host app *why* a slot had ended: the roster only showed the player gone. The host now says why.

## What changed

- **`AwaySlots` reports every slot's end and the reason** (`AwayEnd.back`, `graceOver`, `wentOnWithout`,
  `roundOver`) on `ends`, a broadcast stream it owns and closes in `dispose`. `end(id, reason)` fires it once per
  slot; `endAll` (the round over) uses `roundOver`; the grace timer uses `graceOver`. The viewers' messages
  (`player_away`/`player_back`) and the roster re-report are exactly as before.
- **`ServerGameHost.awayEnded`** re-serves that stream (like `sounds`), and `goOnWithout` ends the slot as
  `wentOnWithout`.
- **`HostService.awayEnded`** passes it to the host app (`LiveHostService` delegates to the game host; the fake
  has a controller). This is the same seam as `gameSounds`, so no game-facing interface (`GameHost`) changed.
- **`AwayLog`** (new, `party_host/lib/src/away_log.dart`) keeps the round's waits and writes the lines; `Pausable`
  feeds it the roster on its tick and the host's end events as they arrive (so a line lands at the moment the
  slot ends, not up to 16 ms later).
- **The host's own line** (`Pausable._noteHostAway`): `_running` (`enabled && no menu`) now decides the words.
  Running: `Round paused: the host went away` / `Round resumed: the host is back` (unchanged). Otherwise (the
  results, a menu open): `The host went away` / `The host is back`.
- **The card, the timer, the countdown, the stats and every message are untouched** (rule 3). `_stopped` was
  rewritten in terms of `_running` and means exactly what it did.

## The lines (rule 1 and 2)

| When | Line |
| --- | --- |
| a phone drops, the round waits | `P<n> away: the round waits for them` (unchanged) |
| back within the grace | `P<n> back: the round goes on` (unchanged) |
| the grace runs out | `P<n> didn't come back in 30 s: the round goes on without them` (the host's real grace) |
| Go on without them | `Go on without P<n>: the round goes on` (once per player) |
| back later in the same round, after either | `P<n> back` (no "the round goes on": nothing waited any more) |
| host away, round running | `Round paused: the host went away` / `Round resumed: the host is back` |
| host away, no round running | `The host went away` / `The host is back` |
| the round ends with phones away | nothing (the round's end is logged by the results' own lines) |

## Files changed

- `packages/connection/lib/src/game_types.dart` — `AwayEnd` enum and the `AwayEnded` record (`player`, `reason`,
  `grace`).
- `packages/connection/lib/connection.dart` — exports them.
- `packages/connection/lib/src/away_slots.dart` — `ends` stream, `end(id, reason)`, `endAll` = `roundOver`, the
  grace timer = `graceOver`; `dispose` closes the stream.
- `packages/connection/lib/src/server_game_host.dart` — `awayEnded` (delegates to `_away.ends`); `goOnWithout`
  passes `wentOnWithout`. 399 lines after the change (394 before), under the 400 limit.
- `packages/connection/test/player_away_test.dart` — 4 tests (below).
- `packages/party_host/lib/src/away_log.dart` — **new**: the round's away lines.
- `packages/party_host/lib/src/ui/pause_menu.dart` — uses `AwayLog`, listens to `awayEnded`, `_running` and the
  host-away words. 385 lines after (382 before).
- `packages/party_host/lib/src/host_service.dart` — `awayEnded` on the interface and on `LiveHostService`.
- `packages/party_host/lib/src/testing/host_fakes.dart` — `FakeGameHost.awayEnded`, `FakeGameHost.graceOver(id)`
  (the grace running out), `goOnWithout` fires its event; the stats fakes moved out (next line).
- `packages/party_host/lib/src/testing/fake_stats.dart` — **new**: `FakeStats` and `FakeUploader` moved as they
  were, because the 400-line rule would have been broken otherwise. No behaviour change.
- `packages/party_host/lib/testing.dart` — exports `fake_stats.dart`.
- `packages/party_host/test/round_log_test.dart` — 4 tests (below).

No existing test's expected value changed.

## Tests (each failing first)

`packages/party_host/test/round_log_test.dart` (widget tests through the host's log):

1. `the host leaving on the results goes in the host log as a host leaving, not a pause` — before the fix it failed
   with `does not contain 'The host went away'` (the old line was `Round paused: the host went away`); also checks
   `The host is back` and that neither "Round paused/resumed" line is written.
2. `the host leaving with the pause menu open goes in the host log as a host leaving` — same old line; the log grows
   by exactly 2 lines.
3. `a phone that stays away past the grace goes in the host log when its slot ends, and its return later is only a
   return` — before the fix the only line was the away one, so it failed with `does not contain 'P2 didn't come back
   in 30 s: the round goes on without them'`. Checks the line at once (one pump after the host ends the slot), that
   the card is gone, that `P2` lines are exactly the away one and this one, and that the return later logs `P2 back`
   and not `P2 back: the round goes on`.
4. `Go on without them goes in the host log once` — failed before with `does not contain 'Go on without P2: the round
   goes on'`; one line only, and no grace line.

`packages/party_host/test/round_log_test.dart`, unchanged and still green: `the round pausing for the host being away
goes in the host log` (mid-round, today's wording) and `a player who is away and back goes in the host log` (back
within the grace, today's two lines).

`packages/connection/test/player_away_test.dart`, group `a slot that ends says why` (4 tests; before the seam existed
they could not compile, as they name `AwayEnded`; with the seam in and the log still unchanged they changed no
behaviour, and the party_host tests above show the bug):

- `a phone back within the grace says back` — reason `back`, player `phone-1` no. 1 and still `away`, grace 5 s
  (`_grace`).
- `a grace that runs out on its own says so, with its seconds` — reason `graceOver`, grace 300 ms (the host's real
  grace, not the default 30 s), and the player is gone from `players`.
- `Go on without them says so` — reason `wentOnWithout`, no wait for the timer.
- `the round being over ends every slot, and says so` — two away phones, two `roundOver` events for numbers 1 and 2.

## Computed values

- `P2 didn't come back in 30 s: …` — 30 is `FakeGameHost.grace.inSeconds` = `ServerGameHost.defaultAwayGrace` =
  `hostGraceS` (30 s), and in the connection test the same line's number comes from a 300 ms grace, so it is the
  host's grace and not a count of elapsed time.
- Test counts: `connection` 278 → **282** (+4); `host` (party_host) 142 → **146** (+4); `phone` 382 (no test added
  there); `tv` passes. Nothing was removed or skipped.

## Self-check (review-rules part A)

1. **Every host setup.** A TV, a PC and a phone host all end a slot in the same `AwaySlots.end`, so the line is
   theirs alike — `a grace that runs out on its own says so, with its seconds` (connection). A joined phone hears
   the same `player_away`/`player_back` messages as before (`player_away_messages_test`, unchanged); an older build
   is unaffected because no message changed.
2. **When kept state starts and ends.** `AwayLog`'s wait starts on the first roster that shows a player away and
   ends on the roster (phone back), on the host's end event (`graceOver`/`wentOnWithout`) or with the round
   (`roundOver`, `Pausable.dispose`) — `a phone that stays away past the grace …` (both endings) and `the round
   being over ends every slot, and says so`. With no round, no slot exists, so no line starts.
3. **How it combines.** Host away × the results and × a menu: `The host went away`/`The host is back` (the two new
   tests). Host away × mid-round: unchanged (`the round pausing for the host being away goes in the host log`).
   Host away × a phone away: unchanged, still `Round paused: the host went away` (`pause_menu_test`, `the host going
   away and a phone away pause the round once`). `Pausable` remains the one owner of the round's pause and phase.
4. **Stay in the job's folder.** `git status` shows only files under `packages/connection` and `packages/party_host`
   (plus this report); the three `tv_test_app/windows/flutter/generated_*` modifications were there before the job.
5. **Stop rather than overstep.** Nothing outside `allow:` was needed. Two files would have passed 400 lines, so the
   stream was moved into `AwaySlots` (server_game_host: 399) and the stats fakes into `fake_stats.dart` (348), both
   inside the allowed folders; no design problem was worked around.

## Not sure / questions

1. **Rule 1's Go on without case, later return.** The brief says a phone back after its grace is only `P<n> back`;
   I used the same for a phone back after Go on without them, since the round isn't waiting for it either. Say if
   it should say something else.
2. **"A round running" for rule 2.** I read the brief's three exclusions literally: the results, after the end,
   the menus. A round waiting for a phone still counts as running, so host away then keeps today's
   `Round paused: the host went away` (that is also what the existing `pause_menu_test` expects). Say if a wait
   should make it `The host went away` too.
3. **Who is "P2" on a return.** Both the old and the new line follow the player *number*: a different phone that
   took a released number before the same player came back would be logged as `P2 back`. Tracking the controller ID
   instead would fix it; it is a change of its own.

## Suggestions

- `server_game_host.dart` is at 399 lines: split it (the status throttling is the cleanest seam) before the next
  step adds to it.
- `pause_menu.dart` (385) and `host_service.dart` (369) are near the limit too; the pause menu's "Get ready" beat
  could be its own file when next touched.

## Commit message

```
Log a phone's grace running out, and pause only a running round

An away phone's grace running out had no log line, so a 35 s drop read as a
35 s wait; and the host going away on the results said "Round paused".

- AwaySlots reports every slot's end and why; ServerGameHost passes it on.
- AwayLog writes "P2 didn't come back in 30 s: the round goes on without
  them", "Go on without P2: the round goes on", and a plain "P2 back" for a
  phone the round had stopped waiting for.
- On the results or with a menu open the lines are "The host went away" and
  "The host is back".
```

## Status row

| Bug 1108g | **Done** (not committed yet): the host log says `P2 didn't come back in 30 s: the round goes on without them` at the moment a slot ends (`AwayEnded` on `ServerGameHost.awayEnded` → `HostService.awayEnded`), `Go on without P2: the round goes on`, and a plain `P2 back` after either; `Round paused/resumed` only while a round runs, else `The host went away`/`The host is back`. connection 278 → 282, host 142 → 146, all checks pass, `review.sh` 0 FAIL. Open: the owner's build 5 re-check; `server_game_host.dart` is at 399 lines and needs a split before the next addition |

## Delete

- none

## Claude's answers

- Approved. Claude's change: `AwayLog.ended` keeps a phone's wait on `AwayEnd.back`, so "P2 back: the round goes on" is written whether the end event or the roster arrives first (the stream is asynchronous); `test/away_log_test.dart` covers both orders and fails without it. Host 148.
- `server_game_host.dart` is at 399 lines: logged in code-health to split before it next grows.
