job: m12 bug 1107d A2+C G4 — the other phones learn a player is away, and say so
stop: after G4.
read: docs/briefs/m12/bug-1107d-g1-plan.md §2, §3, jobs A2 and C (yours; Claude approved, answers in bug-1107d-a1.md: `n` travels in the message) · docs/briefs/m12/bug-1107d-a1-report.md and bug-1107d-b-report.md (landed: the slot, the pause, the host's card) · docs/briefs/m12/bug-1107c-fix-report.md (landed: the phone's card, `HostWaitKind`, Leave game) · packages/protocol/lib/src/{view,codec}.dart · packages/connection/lib/src/{server_game_host,client_controls,client_messages,host_server}.dart · packages/connection/bin/sim_view.dart · packages/game_kit/lib/src/frame_view.dart · controller_app/lib/src/providers/view.dart · controller_app/lib/src/ui/waiting_card.dart · controller_app/test/{joined_view_test,waiting_card_test}.dart · docs/protocol.md (`host_away`, §4, §10a, §11, §12)

do:
1 Protocol (A2): `player_away {player, n, s}` and `player_back {player}`, host → controller, under `view`, as the plan's §2: sent when a slot is held and when it ends (back, the grace over, `goOnWithout`, the round over), only while a view runs, and re-sent after `view_start` to a viewer that pairs while someone is away. A 0.12.0 phone ignores both (pin it with a test that an unknown `t` is dropped, not a 4003).
2 The phone (C): `HostWaitKind.playerAway`, one entry per away player: title "Player N is away", line "The game goes on if they're back in N s", at 0 "The game goes on without them…" until `player_back` or the next frame; **Leave game** as today. The host's own wait (`hostAway`) wins over a player's. The phone that was away itself never shows a card for its own id.
3 docs/protocol.md: the rows and sentences the plan names.
tests (each failing first): the plan's A2 and C lists; plus two away at once → two lines, one ends → one line; a phone that pairs mid-away gets `view_start` then `player_away`.
in the report: test counts before and after, the files changed, the card's exact text, the message JSON examples.
rules: no lib file over 400 · no change to party_host (job B's) unless a provider is missing, then say why first · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1107d-a2c-report.md · packages/protocol · packages/connection · packages/game_kit/lib/src/frame_view.dart · packages/game_kit/test · controller_app/lib · controller_app/test · docs/protocol.md
check: format analyze protocol connection host phone tv
report: docs/briefs/m12/bug-1107d-a2c-report.md
