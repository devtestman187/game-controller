# m12 bug triage — 1107e: back after a finished round started a new game

Read-only triage of `docs/briefs/m12/bug-1107e-triage.md`: nothing fixed, no code changed. Read: the brief and
`device-1107-session2.txt` (log 18:19:18–18:21:57, Diagnostics copied 18:22:00), the phone host route and its nested
games navigator, `party_host`'s results/menus/pause/join/menus widgets, `game_kit`'s session, `puzzle_game`'s report and
play view, `metrics`' session/collector and `live_stats`, the TV app's menus, and the existing host/results tests.

## Q 1 — every "back" on the host phone after a round, and which one starts a round

**Answer.** Four things can be "back"; only the last starts a round.
- System back/swipe: the host route's `PopScope(canPop: false)` calls `HostingNotifier.stop()` and ends the whole host
  (`controller_app/lib/src/host/host_screen.dart:58-64`). Ruled out: the log has no stop or "session saved" line.
- The results' Back button: `maybePop` (`packages/party_host/lib/src/ui/puzzle_screen_widgets.dart:160-163`).
- B on the host phone's own pad, or on a joined phone — the same path: `ControllerMenus`
  (`puzzle_screen.dart:155-170` gives the results A "OK"/B "Back"; `controller_menus.dart:252-255` → `maybePop`).
- A on Play again/Rematch: the focus lands there when the results open (`puzzle_screen.dart:123-126`) and `_rematch`
  `pushReplacement`s a fresh `PuzzleScreen` (`:136-139`) — the only way to start a round (Start is disabled on the
  results, `Pausable(enabled: result == null)`, `:170`; no timer starts one).
**Cause.** Back (button or B) pops the *nested* games navigator (`host_screen.dart:67`, `HostGames`'s Navigator), which
holds only the puzzle route (`JoinScreen._start` `pushReplacement`d it), so the pop lands on `ShapeRaceScreen`'s level
list — one short of the picker — where a `puzzle-<id>` tile is focusable (`games_screen.dart`): the next A opens
the join screen and a new round of the same puzzle. That is why back started a game: the picker is one route further up.
**Confidence.** likely (sure for the code paths); no log line covers the back press, results or new round, so which one
the owner used is *unsure*; the joined phone's view ending `finished` proves a pop, not a rematch.
**Fix / Test / Risk.** Q5.

## Q 2 — what the joined phone was sent and showed, and why the host phone's own view differs

**Answer.** The joined phone only ever had the round's view: `view_start`/`frame`/`view_end`. Popping the host's puzzle
disposes the play view, which ends the view `finished` (`packages/puzzle_game/lib/src/play_view.dart` dispose →
`PuzzleSession.dispose(finished: match.result != null)` → `GameSession.dispose`, `game_session.dart:209-213`,
`ViewEndReason.finished`). The phone stops drawing, `viewActiveProvider` goes false and it returns to its own pad
without disconnecting: the owner's "the remote phone properly quit".
**Cause of the difference.** The host phone's own player is an ordinary player *without* `Capability.view`
(`ownPlayerIdentity`, `controller_app/lib/src/host/hosting.dart`), so the host phone never had a view to end — it
renders the puzzle in-process. `view_end` therefore changes nothing on the host phone's screen; whatever happened next
was in the host's own navigator (Q1).
**Confidence.** sure (protocol, view and identity code). The joined phone's `quitsMidGame 1` is *not* the view end: it
is the mid-round socket drop of Q4 (`packages/metrics/lib/src/session.dart:99` counts a disconnect while in game).
**Fix / Test / Risk.** None here — the joined phone already behaves as the brief asks; the fix is host-side (Q5).

## Q 3 — comparison with a TV host

**Answer.** On a TV the results behave exactly as on the host phone, because the widgets are shared: the TV app wraps
the whole app in the same `ControllerMenus` (`tv_test_app/lib/main.dart:50`) and opens the games list as a route named
`gamesRouteName` (`tv_test_app/lib/src/ui/home/home_screen.dart`, "Play"). So B on the results — from the TV's own
input or from a phone controlling the TV — runs the same `maybePop` (`controller_menus.dart:252-255`), and the Back
button is the same widget (`puzzle_screen_widgets.dart:160-163`): both pop to the same level list, one route short.
**Cause.** "One route short" is shared `party_host` behaviour, not a phone-host special case. Phone-host-only are
(a) the system back/swipe, which exists as a route only in the phone host (`host_screen.dart:58-64`) and stops hosting
instead of popping, and (b) the host phone's own pad working the host's own menus while it hosts — a TV has no host
route to stop.
**Confidence.** sure for the shared results path; likely that a phone controlling the TV drives the same B (it is the
same `ControllerMenus` and the same per-player layouts).
**Fix / Test / Risk.** Q5: a fix in `puzzle_screen.dart` also changes the TV, which is consistent but is a product call.

## Q 4 — the side numbers
**Q4a, `frames: drawn 0, dropped 0` (session 1: 14397).** Not the counter: the shown summary is the last *saved* one
(`_save()` per 1 min `checkpoint` sets `state.current`, `live_stats.dart:220`, `:244-251`), dated 18:21:26.4 by its
`durationS: 120`. In `summary()` `rounds` (`session.dart:276`) and each player's `games` (`session_player.dart:108`) are
*live references*, `frames` a value (`:277`), so the round written after that checkpoint shows in
`games.puzzle.wins: 1` and `rounds[0]` but not in `frames`; proof: `PuzzleReport.write` writes `player_result`,
`round_end`, `frames` in order (`puzzle_report.dart:23-71`).
**Cause.** the totals are copied by value, so they date from the checkpoint. **Confidence.** sure (code and the copy).
**Fix.** Copy in `summary()` (`List.of(_rounds)`, a deep copy of `p.games`). **Test first** (metrics): take a summary,
then record `frames` and a round; its `frames` stays 0 while its `rounds`/`games` must not grow. **Risk.** Low.
**Q4b, B3CA's numbers.** `received_to_drawn` median 5, p95 10, one max 3625 ms is a *pause* counted as input latency:
while paused `advance` keeps `_last` current (`game_session.dart:174-175`), so the resume frame is not a stall (`:178`)
and `drawn()` reports the whole pause (`:199-207`). It fits the host leaving the screen ~4 s: `Pausable` pauses on
`hostAway` (`pause_menu.dart:132-138`), its socket then received nothing, B3CA's heartbeat timed out at 18:20:37.608
(4004 = `CloseCodes.heartbeatTimeout`, `network.dart:39`, 4 s window `host_server.dart:296`), reconnected 0.416 s
later — one host hiccup, not the phone's link. **Confidence.** likely; which pause is *unsure*.
`view.frames 4395` of ~6350 (69 %), `gaps 450`, `late 496`, jitter 2/6/319 ms, `touch_to_frame` 33/52/1288 ms: spread
over the round, so ~41 fps throughout, not one stall (the 1288 ms frame is likely the reconnect, *unsure*). **Fix.** Do
not report a pause as input latency; **test**: a paused session's input reports no sample.

## Q 5 — the fix: every back on the results goes to the game picker; a new round only on Play again

**Answer.** Two changes in existing patterns; back then lands on `GamesScreen`, Play again/Rematch still start a round.
- Every back on the results goes through the picker: wrap `PuzzleScreen`'s build (`puzzle_screen.dart:155`) in
  `PopScope(canPop: result == null, onPopInvokedWithResult: (didPop, _) { if (!didPop) leaveForGamePicker(context); })`.
  `leaveForGamePicker` exists already (`pause_menu.dart:144-145`, used by Quit and `abandonRound`), and `maybePop` asks
  the route first, so B (`controller_menus.dart:252-255`) and the Back button (`puzzle_screen_widgets.dart:160-163`) are
  both redirected unchanged — and the TV matches (Q3).
- Let the host phone's system back try the games before stopping the host (`host_screen.dart:62-64`): if
  `widget.host.gamesKey.currentState?.canPop() ?? false` then `maybePop()` there, else `stop()`.
**Test (write it first, watch it fail).** In `packages/party_host/test/puzzle_results_test.dart`, the harness of the
existing "on the results B on the phone goes back" test, with a named `GamesScreen` (`gamesRouteName`) and a
`ShapeRaceScreen` under the puzzle: `await press(tester, fake, 'p2', GamepadButton.b);` then
`expect(find.byKey(const Key('pickShapeRace')), findsOneWidget);` and
`expect(find.byType(PuzzleScreen), findsNothing);`. A second test taps `resultsBack`; the existing "A presses Play
again" test stays the guard for "a new round only there".
**Risk.** Shared with the TV (intended; a product call, see questions). The existing B test pushes the puzzle alone, so
`leaveForGamePicker` pops to the first route and it still passes; Rematch/Change teams never pop; the joined phone has
no local puzzle screen. `popUntil` ignores `canPop`, so no loop, and the view still ends `finished` on the pop.

## Files changed

- `docs/briefs/m12/bug-1107e-triage-report.md` — this report (the only file the job allows).

## Checks

- `report` — PASS: the report exists with Q1–Q5, the confidence labels, and the three end sections. No test, app or
  device was run: the job is read-only and changes no code.

## Questions

1. Which back did the owner use (the results' Back button, B, or the system back)? The log has no line for it; should a
   line be added for backs, new rounds, pauses and `host_away`/`host_back`?
2. The results are shared `party_host` widgets, so the Q5 fix also changes the TV. Ship it for the TV too, or keep it
   phone-host-only?
3. The brief says "every kind of back" goes to the picker — that includes the system back, which today stops hosting.
   My Q5 second bullet makes it go up inside the games instead; confirm that is what is wanted.
4. Should `SessionSummary.summary()` stop aliasing `_rounds` and each player's `games` (Q4a), or is the growth of a
   saved checkpoint wanted?

## Suggestions (not acted on)

- Log `host_away`/`host_back`, pause/resume and the results' back/new round: the log ends at 18:21:57 and the whole
  mystery sits in the last 3 s it does not show.
- Do not report `received_to_drawn` for inputs that arrived while paused — a pause is not input latency (Q4b).
- `quitsMidGame` counts a host-side heartbeat drop as the player quitting; that makes a host hiccup look like the
  player leaving.

## Commit message

```text
Triage 1107e: results back goes one route short of the game picker

Read-only: no code changed. Report with Q1-Q5 (back paths on the host phone, the
joined phone's view_end finished, the TV comparison, the frames-drawn-0 snapshot
alias and B3CA's pause-as-latency 3625 ms, and the fix plan with tests first).
```

## Status row

| 1107e | Triage done (report only): back on the results pops to the level list, one route short of the picker, so the next A starts a round; fix plan and failing tests written down, not implemented | open: the fix, the summary aliasing, pause logging |

## Delete

- none
