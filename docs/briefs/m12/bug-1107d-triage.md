job: m12 bug triage — a joined phone locked mid-game: what the host, the round and the phone do; read-only
stop: after the triage. Change no file but the report; fix nothing.
read: docs/briefs/m12/device-1107-session.txt · docs/briefs/m12/bug-1107c-triage.md (the joined phone's log, the same test) · packages/connection/lib/src/{controller_client,client_connection,host_connection,game_host}.dart · the phone app's lifecycle handling (find it: "App resumed, trying to reconnect now") · packages/party_host/lib/src/{host_service,host_presence}.dart · how a game treats a player who drops mid-round (packages/game_kit, packages/puzzle_game: find it) · docs/design/m12.md §2.10 and m12-joined-view.md §0.3 · docs/coding-guidelines.md

the owner's report: "I did lock after 40 seconds or so." So: iPhone B3CA, joined to iPhone 6D8B's "Play on this phone" game (build m12.4) as player 2, locked its screen about 40 s after pairing. The owner wants this case handled.
- B3CA's log: 17:47:37 paired · 17:48:16 `[discovery] Restarting discovery` · nothing until 17:52:47 `No heartbeat for 270.5 s, the connection is gone`, `Reconnecting in 250 ms (attempt 1)` · nothing until 18:09:10 connecting, 18:09:17 `App resumed, trying to reconnect now` (the host had stopped by then).
- the host's log: 17:48:18 `iPhone B3CA disconnected (code 1002)`, session 40 s; the summary has `quitsMidGame: 1` for B3CA and the round after it `players: 1`, a draw at the 120 s time-up.

questions:
1 What happened, step by step, with file:line where the code decides: iOS suspending the app and closing its socket (is 1002 what dart:io's server reports for that?), the host dropping the player, the round going on with one player (or starting with one), and why the phone logged nothing on resume at 17:52:47 except the heartbeat (did it resume, or wake briefly in the background?). Mark "unsure" what the logs can't tell.
2 What should happen, compared with the TV host and with the host phone's own lock (m12 §2.10: the host away up to 30 s pauses the round): does a TV-hosted game hold a dropped player's slot, and for how long? Does a player who comes back get the same player number and their side of the match? What does the other player see meanwhile?
3 On unlock: does the phone reconnect at once (the lifecycle hook), and does it rejoin the running round, or land on the picker or the Connect screen? Is there a gap where it shows the waiting card for its own lock (the card is meant for the host being away)?
4 The fix to propose, smallest first: e.g. reconnect at once on resume, keep the player's slot and number for a grace on the host, say on the other phones "Player 2 is away", and don't show "Waiting for the host" on the phone that itself was locked. For each: files, lines, what it could break, and the failing test you'd write first. Say which parts are already done and only need a test.

format (the report, at most 20 lines per question block): `## Q N — <name>` with Answer, Confidence (sure / likely / guess) and what proves it, Fix, Test, Risk. Mark anything inferred "unsure". No code longer than 5 lines.

allow: docs/briefs/m12/bug-1107d-triage-report.md
check:
report: docs/briefs/m12/bug-1107d-triage-report.md
