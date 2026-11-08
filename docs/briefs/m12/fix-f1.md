job: m12 build 4 fix-f1 G4 — the host side: B on the away card; the host's own player never away
stop: after G4.
read: docs/code-health.md N1, N5 · docs/briefs/m12/build4-review-r2-report.md findings 1, 2 · docs/briefs/m12/build4-review-r1-report.md (A3 table) · packages/party_host/lib/src/ui/{away_card,pause_menu,controller_menus,puzzle_screen}.dart · packages/party_host/lib/src/players_away.dart · packages/connection/lib/src/{away_slots,server_game_host,host_server,game_types}.dart and the in-process link (find it: `InProcessListener`) · controller_app/lib/src/host/phone_host.dart (how the own player pairs) · their tests · docs/coding-guidelines.md
do:
1 N1: while the away card is up, B on any phone (and the remote's Back) must not pop the round: the card's controls give A and the arrows to its buttons and nothing pops the round's route. The round's own `Controls.game()` already ignores B; keep that.
2 N5: the host phone's own player (paired over the in-process link) never gets an away slot: a drop of that link (it happens on every return from a lock: the host log's `[own] No heartbeat … dropping`) is the host's own business, covered by the host-away pause. Mark it where the host can see it (the link the player came in on, not a player-ID compare), and keep the TV's keyboard and simulated players as they are.
code health: also connection's "`_sendView` re-sends everything to a re-pairing viewer except `host_away`", if a viewer can pair while the host is away (say if it can't, and skip it).
tests (each failing first): B and the remote's Back with the card up: the round stays, no `quit`; the own player's link drops mid-round on a phone host: no slot, no `player_away`, no card, the round's only pause is the host-away one; a joined phone's drop still holds a slot (unchanged). Existing tests: list any old → new.
in the report: test counts before and after, the files changed, computed values.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/fix-f1-report.md · packages/party_host · packages/connection
check: format analyze connection host phone tv
report: docs/briefs/m12/fix-f1-report.md
