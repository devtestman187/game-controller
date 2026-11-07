# M12 bug triage — 1107d: a joined iPhone locked mid-round

Read-only triage; no fix, no file changed but this report. Read: `device-1107-session.txt`, `bug-1107c-triage.md`,
`packages/connection/lib/src/{controller_client,client_connection,host_connection,host_server,server_game_host,game_host,game_types,host_pairings,memory_game_host}.dart`,
`controller_app/lib/src/{ui/controller_screen,ui/joined_view,ui/waiting_card,providers/view,host/phone_host,discovery}.dart`,
`packages/party_host/lib/src/{host_service,host_presence,ui/pause_menu,live_stats,session_recorder}.dart`,
`packages/puzzle_game/lib/src/{match,game,puzzle_session,puzzle_report,settings}.dart`, `packages/game_kit/lib/src/game_session.dart`,
`packages/metrics/lib/src/session.dart`, `docs/design/m12.md` §2.10, `m12-joined-view.md` §0.3, `coding-guidelines.md`.

## Numbers (computed from the two logs and the summary)

| what | value | how |
| --- | --- | --- |
| B3CA's session | 40.12 s | 17:47:37.902 → 17:48:18.021 (summary `connectedS: 40`) |
| silence when the beat noticed | 270.5 s | log line; last message ≈17:48:17, beat 17:52:47 |
| same, wall clock | ≈270.5 s | 17:48:16.5 → 17:52:47: the `Stopwatch` (`controller_client.dart:74`) kept time while the isolate was frozen |
| frozen after the beat | 983 s | 17:52:47 → 18:09:10; the 250 ms retry did not run |
| 18:09:10 → the real resume | 7 s | 18:09:10 → 18:09:17 `App resumed` |
| round's simulated time | 120.02 s | `settings.dart:15` (default 120 s) |
| B3CA's view frames | 21.37 s at 60 Hz | 1282 / 60 → the round began ≈17:47:56.6 (≈21 s before the drop), ended ≈17:49:56.6 |
| host session end | ≈17:55:51.8 | 17:47:29.823 + 502 s |
| round record | 1v1, draw, `players: 1` | `games.puzzle.rounds_1v1: 1`, `draw: 1` for player 1, B3CA's `games: {}` |

## Q 1 — what happened, step by step

**Answer** (1) 17:47:37.9 B3CA pairs as player 2 (`host_connection.dart:347-369`); a 1v1 Shape Race starts ≈17:47:56 with both players. (2) 17:48:16 B3CA logs `Restarting discovery` (`discovery.dart:146-150`); of its four callers only `controller_screen.dart:83` runs while connected (an `AppLifecycleState.resumed`; the others are a 4th reconnect attempt `:105`, the Connect screen's button, and hosting stopping), so the app was shown again ~1–2 s before it died. Why: **unsure** (a quick unlock, a notification wake, or the lock sequence itself). (3) iOS suspends the isolate: its timers stop (`client_connection.dart:111`) and the socket is torn down; the host's dart:io reports done at 17:48:18.021 and `host_connection.dart:116-121` logs the code the channel read (`web_socket_channel.dart:55` → dart:io's `WebSocket.closeCode`). **1002 is not a code this repo sends**: `network.dart:22-43` has 1001 and 4000–4005, the client's own closes add 1000 (`client_connection.dart:134`), and `transport_test.dart:37` pins null before any close. So it is either a frame from the peer's side or dart:io's own naming of an abnormal close — **unsure which** (I can't read dart:io's source on this PC); what is sure is that no app code chose 1002. (4) The host drops the player at once: `_ended` marks the pairing seen and calls `sessionEnded` (`host_connection.dart:374-393`, `host_server.dart:379`); the snapshot changes, `_checkPlayers` runs (`server_game_host.dart:17, 285-298`) and the id leaves `players` (`:135-150`). (5) The round goes on: `GameSession._sample` forgets the id (`game_session.dart:229-249`), `PuzzleSession.step` keeps stepping (`puzzle_session.dart:111-145`), and `PuzzleGame.update`'s first loop removes the player — dot and held piece gone, placed pieces kept (`game.dart:231-237, 212-218`). The match keeps both sides (`match.dart:85-93, 135-143`) and the shared 120 s clock, so at time-up it compared the boards (`match.dart:199-206`), equal at 0 → draw (`match.dart:57`), and `round_end` lists only the players present (`puzzle_report.dart:63-66`) → `players: 1`; B3CA gets no `player_result` (its `games` and `gameStats` are empty in the summary, which is how we know it *was* in the round: `quitsMidGame: 1`). (6) 17:52:47 the heartbeat Timer finally ran on a short background slice: `nowMs` had advanced 270.5 s, so `_beat` declared the silence and dropped the channel (`client_connection.dart:199-213`), scheduling the first retry 250 ms later (`controller_client.dart:293-304`). Neither `App resumed` (`controller_client.dart:251`) nor a lifecycle discovery restart appeared → **not a resume: a brief wake**; and the retry did not run for 983 s → the isolate froze again at once. What woke it: **unsure**.

**Confidence** sure for steps 1, 4, 5 and 6's mechanism (code path and the summary's numbers agree); likely for 3's cause (iOS suspend closes the socket); **unsure** for 1002's origin, the 17:48:16 `resumed` and the 17:52:47 wake.
**Fix** none here — see Q 4. **Test** none (read-only). **Risk** —

## Q 2 — what should happen: a dropped player vs the host's own lock

**Answer** A TV-hosted (or phone-hosted) game holds **no round slot** for a dropped player: the player is out of `players` the moment the connection ends (`server_game_host.dart:135-150`) and the rules delete its dot (`game.dart:232`). There is no round grace at all, on any host type. Two things *are* held. The **number**: `markSeen` plus `pickPlayer`'s one-minute reservation keep it for the returning controller and away from newcomers (`host_pairings.dart:160-165, 180-193`), tested in `m6_test.dart:36-48`. The **side**: `PuzzleMatch.teams` is fixed when the match is made (`match.dart:85-93`), so a returning controller is still on its side. So a player who comes back gets its number (`host_connection.dart:353`), its side, its placed pieces, its layout, its status panel, `view_start` and the latest frame (`server_game_host.dart:288-307`; `view_test.dart:211`), but its dot is re-made at the start position and a held piece was put back (`game.dart:207-218`). The host phone's **own** lock is the opposite: `HostPresence` pauses the round at once, holds it for `graceS` 30 s, tells the viewers (`host_presence.dart:47-77`, `phone_host.dart:106-121`) and abandons it after that (`pause_menu.dart:151-154`). A joined player's lock does none of that — no pause, no message, no grace — which is the asymmetry the owner hit. The other player sees only the opponent's dot vanish from the next frame, with its count frozen; nothing says "P2 is away": the board and the phone HUD only carry the two counts, as L/R with no name (`match_painter.dart:206, 214, 241-242`), while each frame's roster lists who is in the round (`game_session.dart:272`), and a status panel can't be sent to a phone that is gone (`host_server.dart:220-225`).

**Confidence** sure for every claim above (code); what it *should* be is Claude's call — I'd give a joined player the same 30 s the host's own lock gets.
**Fix** Q 4 (c). **Test** — **Risk** —

## Q 3 — on unlock

**Answer** **Reconnect at once: yes, and already done.** `controller_screen.dart:76-96` calls `client.resume()` on `resumed`; with a live channel `replaceQuietChannel` replaces it when quiet > `heartbeatTimeout/2` (2 s) and retries with a zero delay (`controller_client.dart:245-255`, `client_connection.dart:140-146`), and with a pending reconnect it calls `retryNow` (`controller_client.dart:231-237`); both are tested (`m6_test.dart:160-185, 187-202`). **Rejoin:** the saved token re-pairs without a code (`client_messages.dart:132-139`); if the round still runs, the phone gets `view_start`, the latest frame and its side back (Q 2). It never lands on the picker or the Connect screen by itself: only `initState` opens Connect (`controller_screen.dart:61`). **But if the round ended while it slept** — this incident: 21 s in, then 4.5 min away — nothing resets the view: only a `ViewEnded` clears `viewActiveProvider` (`providers/view.dart:25-46`), that message went out while the phone was suspended, and nothing is sent to a rejoining phone when no view runs (`server_game_host.dart:302-307`). So the phone keeps drawing the last frame of a finished round under the pad: the screen behind 1107c's card. Confidence sure from the code; **unsure** that the owner read that frozen game as a separate problem. **The waiting card for its own lock: yes, and it blames the host.** `HostWaitNotifier` cannot tell "the host went away" from "I went away": any drop while a view is up starts the 30 s count from the moment the client noticed (`providers/view.dart:103-110`) and only a reconnect clears it (`:104-105`); the tested case is `joined_view_test.dart:354-367`. Here the drop was noticed at 17:52:47 in the background, so the 30 s were long gone at unlock and the card said "The host may have left" (`waiting_card.dart:44-62`) at once — for a host that was still there until 17:55.

**Confidence** sure (code and the log's order of events). **Fix** Q 4 (d). **Test** — **Risk** —

## Q 4 — the smallest fixes, in order

**Answer** (a) **Reconnect on resume — done, only a test is missing.** `controller_screen_test.dart:46-58` checks the input release and the discovery restart on `resumed` but never that `client.resume()` was called (the fake records it, `fakes.dart:69`). Test: `handleAppLifecycleStateChanged(resumed)` → `app.client.calls` contains `resume`; nothing new in `lib/`. (b) **Say "Player 2 is away" on the other phones.** Every frame's roster already names the players (`game_session.dart:272`) and the view has a place for it (the L/R counts plus a caption, `match_painter.dart:241-242, 283`); with (c) the player stays in the round, so the flag has to travel from the host: the roster entry grows from `[number, name]` to `[number, name, away]`, its decoder accepting both lengths (missing = present; `view.dart:228-230` throws today, and only a `view`-capable phone ever sees frames, so a m12 viewer is the only reader). Risk: that is a protocol change, so it wants its own gate and a decode test both ways. (c) **Keep the dropped player in the round for the same 30 s — host-side only.** `ServerGameHost` keeps the id in `players` for `awayGraceS` after its session ends, with `gamepad()` neutral (already `server_game_host.dart:156-160`) and a new `away` field on `GamePlayer` (`game_types.dart:6-51`); the rules then leave the dot where it was, because `update` only removes ids missing from its inputs (`game.dart:231-237`) and `GameSession` passes one state per player in `players` (`game_session.dart:229-249`). Files: `server_game_host.dart:135-150` plus a check on the server clock (no `Timer` in a game), `game_types.dart`. Breaks: `players` no longer equals `snapshot.connected` — the pause menu's list and `label` show the away player for 30 s (wanted), `haptic`/`askRating` return false (already do), `LiveStats` reads the server snapshot and is unaffected (`live_stats.dart:164-171`). Test first (fails today): pair two controllers to a `HostServer`, drop one, move a fake clock 29 s → `host.players` still has it (`ServerGameHost`); 31 s → gone. (d) **Don't say "Waiting for the host" for this phone's own lock.** The app knows it was hidden (`didChangeAppLifecycleState`): give `HostWait` a kind and let the card say "Your phone was asleep. Reconnecting…" while a view is up (`providers/view.dart:51-113`, `waiting_card.dart:42-69`). Risk: it hides the true "host left while I slept" case (this one), so it is only honest together with (c), or the card must say both. Test first: hide, emit `reconnecting`, show → the phone's text, not the host's (in the style of `joined_view_test.dart:179-197`). (e) **Also worth a look, not a fix here:** the 4107 ms `received_to_drawn` is one host-side sample — `GameSession.drawn` reports `now − arrivedAt` and only skips the advance that saw the stall (`game_session.dart:199-207`), so a frame built just before a 4.1 s gap in the *host's* drawing reports it; the phone's own numbers to the cut are normal (`touch_to_frame` max 52 ms, `frame_jitter` 31 ms, 27 gaps / 62 late). **Unsure** what stalled the host. Already done and only needing tests: (a) above, the 60 s number hold (`m6_test.dart:36-48`), the re-sent view on rejoin (`view_test.dart:211`), and the side kept by the match (by construction; no test names it).

**Confidence** sure for the file/line claims; likely that (c) is the fix the owner means by "handled"; the grace value and the pause-vs-run question are Claude's.
**Fix** as (a)–(d). **Test** the three named above, one failing first each. **Risk** listed per item; (c) is the only one that changes what the games see, and it touches `players`, which the pause menu and the join screen also read (`pause_menu.dart:164-167`, `join_screen_widgets.dart:46`).

## Files changed

- `docs/briefs/m12/bug-1107d-triage-report.md` — new: this triage.

## Checks

- None run. The brief's only `check:` is this report; `dart`/`flutter` invocations are blocked in this sandbox (`dart --version` asked for approval), and no test can produce an iPhone's suspend.

## Questions

1. Is the away grace for a dropped player the same `hostGraceS` (30 s), and does the round **pause** while they are away (symmetric with the host's own lock) or keep running as today?
2. When the grace runs out, does the round continue without them (today), or end as `abandoned` like a host that stayed away too long?
3. Where should "P2 is away" be said: a third roster element in `frame` (a protocol add, `view`-gated, Q 4b), or not at all until the round-pause question is answered?
4. Should the phone say something different when it was the one asleep (Q 4d), or keep one card for both cases?
5. Can the owner say what the phone did at 17:48:16 (`Restarting discovery`) — lock, a notification, a quick unlock? It is the last thing the app logged before it froze.
6. Is the 4107 ms host-side `received_to_drawn` worth its own look (Q 4e), or leave it until it repeats?

## Suggestions (not acted on)

- A host-side log line when a player leaves mid-round ("iPhone B3CA left in the middle of a round"), so the next report's log names the moment without arithmetic on the summary.
- Keep B3CA's `player_result` when a player is dropped mid-round: today `PuzzleReport.write` loops the players still in each side's game (`puzzle_report.dart:28`), so a leaver's numbers are lost; the away slot in (c) would fix it for free.
- A `connection` test for an abrupt close (no close frame) that pins what `closeCode` is, so the next report can say what 1002 means with a pointer instead of "unsure".
- The waiting card never ends by itself (`HostWaitNotifier` has no timeout) — that is 1107c's Q 2 and is still open.

## Commit message

```
docs(m12): triage a joined iPhone locked mid-round

At 17:48:16 iOS suspended B3CA and tore its socket down; the host
read close code 1002, dropped player 2 at once and ran the 1v1 on
with one player: a 0-0 draw at time-up, recorded players: 1. Its
own beat only ran at 17:52:47 on a brief wake, then froze until
18:09:17. On resume it reconnects at once and gets its number and
side back, but the round had ended, nothing clears the stale view,
and the card blames the host. Fix: keep a dropped slot for
hostGraceS, say a player is away, and name the phone's own sleep.
```

## Status row

| Bug triage 1107d | G0 survey done ([bug-1107d-triage-report.md](bug-1107d-triage-report.md)): B3CA's lock (17:48:16, iOS suspend) cut the socket; the host read 1002 and dropped player 2 at once (`server_game_host.dart:135-150`), the 1v1 ran on with one player (`game.dart:231-237`) to a 0-0 draw recorded `players: 1`, and the phone's beat only ran at 17:52:47 on a brief wake, then froze until 18:09:17. Reconnect on resume, the 60 s number hold and the re-sent view already exist; the gaps are no round grace for a dropped player, nothing said to the others, and a "Waiting for the host" card that blames the host for the phone's own lock. Fix proposed: `awayGraceS` in `ServerGameHost` (player kept, neutral input), an away flag on the roster, a phone-asleep card; one test for the app's resume call. Open: the grace value and pause-vs-run, where the away flag travels, and what 1002 was |

## Delete

- none
