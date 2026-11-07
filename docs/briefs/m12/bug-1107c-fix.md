job: m12 bug 1107c fix G4 — a joined phone can always leave a game, and its waiting card tells the truth
stop: after G4.
read: docs/briefs/m12/bug-1107c-triage-report.md (yours: Claude approves Q 4 with the answers below) · docs/briefs/m12/bug-1107d-triage-report.md Q 3 and Q 4 (a), (d) · controller_app/lib/src/ui/{waiting_card,joined_view,controller_top_bar,bar_connection,controller_screen,connect_screen}.dart · controller_app/lib/src/providers/{view,connection}.dart · controller_app/lib/src/host_grace.dart · controller_app/test/{joined_view_test,controller_screen_test}.dart · controller_app/test/support/{pump_app,fakes}.dart · docs/design/m12-joined-view.md §0.3

Claude's answers to 1107c: Q1 Leave game does exactly what Stop does today (`disconnect()`, `lastHost` forgotten: a departed phone host shouldn't be retried at every app start; the pairing tokens stay) · Q2 "The host has left" at the countdown's 0, whatever its length; with no number, after `hostGraceS` · Q3 over a game the bar's dot is always a button to the Connect screen (same look, a 48 dp touch target, a tooltip "Connection"), not only while the card is up: a live joined game needs a way out too.

do:
1 `ConnectionActions` / `providers/view.dart`: an `idle` client (Stop, Leave game) ends the view and the wait — `viewActiveProvider` false, `_away`, `_dropped`, `_hasView` cleared — so the Connect screen's Stop works over a game as well.
2 `waiting_card.dart`: a **Leave game** button (`Key('leaveGame')`) that disconnects and opens the Connect screen. Two states: counting → today's title and line, Leave game a `TextButton`; at 0 (or past the grace with no number) → **The host has left**, "You can keep waiting, or leave.", Leave game a `FilledButton`. Reconnecting goes on behind it.
3 The card's two causes (1107d Q 4 d): `HostWait` gets a kind. `host_away` from the host → as above. A dropped link → title **Reconnecting to the game…**, no countdown, Leave game; after `hostGraceS` of failed reconnects it turns into "The host has left" as in 2. The phone no longer says "Waiting for the host" because it was itself asleep.
4 A finished round must not stay on screen after a reconnect (1107d Q 3): when the link comes back, the view ends unless the host sends `view_start` again (it does for a running round, `server_game_host.dart:288-307`). Pick the simplest correct way (e.g. end the view on `reconnecting`, keep the last frame drawn under the card until the link returns or the card is left) and say which; check the order of the reconnect snapshot vs the host's re-sent `view_start` with a test.
5 `controller_top_bar.dart` / `bar_connection.dart`: the compact bar's dot is a button to the Connect screen (answer Q3).
6 `docs/design/m12-joined-view.md` §0.3: the new rules (Leave game, the two kinds, "The host has left", idle ends the view), replacing rule 3's "keeps the text without a number".
tests (each failing before its item): 1107c Q 4 tests 1–4; the dot opens the Connect screen over a game; a drop shows "Reconnecting to the game…" with no "Waiting for the host"; after the grace it says "The host has left"; a reconnect with no `view_start` ends the view, one with `view_start` keeps the game; 1107d Q 4 (a)'s resume test. Change `joined_view_test.dart:345-352` to the new text; list every changed old → new.
in the report: test counts before and after, the files changed, the order you found in item 4.
rules: no lib file over 400 · no change in packages/ (if one is needed, stop and say why) · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/bug-1107c-fix-report.md · controller_app/lib · controller_app/test · docs/design/m12-joined-view.md
check: format analyze phone
report: docs/briefs/m12/bug-1107c-fix-report.md
