job: m12 bug triage — a joined phone stuck on "Waiting for the host to come back · The host may have left" with no way out; read-only
stop: after the triage. Change no file but the report; fix nothing.
read: controller_app/lib/src/ui/{waiting_card,joined_view,connect_panels,connect_screen}.dart · the controller screen, its top bar (full and compact over a game) and the mode menu (find them) · controller_app/lib/src/providers.dart (`hostWaitProvider`, `viewActiveProvider`, `showsGameProvider`, `connectionActionsProvider`) · packages/connection/lib/src/{controller_client,client_connection,game_host}.dart (reconnect, `HostWait`) · docs/design/m12-joined-view.md §0.3 and m12.md §2.10 · controller_app/test/joined_view_test.dart · docs/briefs/m12/device-1107-session.txt · docs/coding-guidelines.md

the owner's report:
- did: iPhone B3CA joined iPhone 6D8B's "Play on this phone" game (build m12.4) and played Shape Race; later the host stopped hosting · expected: a way to leave · happened: "I cannot leave the current game. It shows 'waiting for host to come back. The host may have left'. But there's no way for me to leave that game. Is that expected? It's not a good design"
- the joined phone's log (B3CA, times local): 17:47:37 paired, player 2 · 17:48:16 `[discovery] Restarting discovery` (no client line) · 17:52:47 `No heartbeat for 270.5 s, the connection is gone`, `Reconnecting in 250 ms (attempt 1)`, a `-65569 DefunctConnection` discovery error · 18:09:10 connecting again · 18:09:17 `App resumed, trying to reconnect now` · then attempts 2–9 to 192.168.50.193 and fe80::…%en0, timed out or `Connection refused (OS error 61)` (the host stopped hosting), every 3 s, still going at 18:10:02. Diagnostics: `Connection: reconnecting`, `Player: -`, `Discovery: running true, 0 found`.
- the host's log: 17:48:18 `iPhone B3CA disconnected (code 1002)`, session 40 s, `quitsMidGame: 1`; the round that followed counted 1 player.

questions:
1 Why there's no way out: list every way a player leaves a host from the controller screen (the top bar's connection button or chip, the mode menu, the Connect screen's Stop/Disconnect, the back gesture) and say, for a joined phone over a game with the card up and the client `reconnecting`, which are hidden, covered or disabled, with file:line. Is a TV-hosted controller stuck the same way when the TV goes, or only a phone that shows the game?
2 How long the card stays: what clears `hostWaitProvider` and the view, and does anything ever end the wait (the countdown at 0, a reconnect giving up, `host_away` never followed by `host_back`)? Does the reconnect ever stop on its own?
3 The timeline: what the 17:48:16 discovery restart and the host's close code 1002 mean (the phone locked or backgrounded? iOS closing the socket on suspend?), why the client only noticed at 17:52:47, and whether the 4107 ms `received_to_drawn` max fits the same moment. Mark it "unsure" where the log can't tell.
4 The fix, to this design (Claude's call; say what conflicts with the contract or the tests):
  - the card always has a **Leave game** button: it stops reconnecting and goes back to the Connect screen, as the Connect screen's Stop does today (the saved pairing stays);
  - at 0, or with no countdown once the link has been gone for the grace (30 s), the card says **The host has left** with "You can keep waiting, or leave." and Leave game as its main button; reconnecting goes on behind it, so a host who comes back still gets the player back;
  - whatever Q1 finds hidden over a game that is the normal way out, say whether it should show while the card is up.
  Files, lines, what it could break, and the failing widget tests you'd write first.

format (the report, at most 20 lines per question block): `## Q N — <name>` with Cause/Answer, Confidence (sure / likely / guess) and what proves it, Fix, Test, Risk. Mark anything inferred "unsure". No code longer than 5 lines.

allow: docs/briefs/m12/bug-1107c-triage-report.md
check:
report: docs/briefs/m12/bug-1107c-triage-report.md
