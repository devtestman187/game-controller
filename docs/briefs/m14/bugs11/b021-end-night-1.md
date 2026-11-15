job: M14 bugs11 b021-end-night-1: "End night" on the Bumper Round's night results card (B-021, phase 1 of 2)
pub: no
stop: after it. The Shape Race card is phase 2.
read: docs/design/party-night.md (sections 4 and 8, N5-N7) · packages/party_host/lib/src/night/party_night.dart · night_state.dart (`record`, `isOver`, `awarded`) · lib/src/ui/arena_results.dart (`_ResultsBody`, the night's `next` button) · lib/src/ui/game_screen.dart (`_next`, `ArenaResults(`) · lib/src/text/night_text.dart · tests: arena_night_test, arena_results_test, menu_press_test, night_reveal_test, night_round_test
decide: low-usage mode: never stop for a question. Make the safest choice that fits and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner, Nov 15, 2026 (B-021): "End night button. Ignore 'shuffle.'"

1 Core: `PartyNight.endNow(RoundResult result)` records the round just played, then marks the night over (fewer rounds than planned) and decides its awards exactly as the last round does, so `isOver` is true and the reveal, then the final scores, follow. The night keeps what it has: rounds played, points, awards from those rounds.
2 Arena card: in a night, `_ResultsBody` shows "End night" (text in night_text.dart, key `endNight`) beside Next. It calls a new `onEndNight` that `game_screen.dart` wires like `_next`: `endNow`, then push `NightRevealScreen` over `isGamePickerRoute`. After the night's last round only Next shows (it already ends the night).
3 `game_screen.dart` is 373 lines: if the wiring pushes it over 380, move `_debugKeys` (lines 30-40) into `game_debug_overlay.dart`.
4 Focus: Next keeps the first focus; a D-pad Right press reaches End night (menu_press_test pins the walk: fix its expectations).
tests: new file `packages/party_host/test/end_night_arena_test.dart`: a 3-round night, one round played: the button shows; pressing it opens the reveal, then the final scores; the last round has no button; the played round's points are in the standings. A phone host's card is pinned, so `check:` has `phone`.
in the report: `## Summary` (15 lines max), `## Hand-over` (the exact core API for phase 2).
rules: aim for 40-100 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself · never use git add -A · run only your own tests and the `read:` ones, the full check once at the end
allow: packages/party_host/lib/src/night/party_night.dart · packages/party_host/lib/src/night/night_state.dart · packages/party_host/lib/src/ui/arena_results.dart · packages/party_host/lib/src/ui/game_screen.dart · packages/party_host/lib/src/ui/game_debug_overlay.dart · packages/party_host/lib/src/text/night_text.dart · packages/party_host/test/end_night_arena_test.dart · packages/party_host/test/arena_night_test.dart · packages/party_host/test/arena_results_test.dart · packages/party_host/test/menu_press_test.dart · docs/design/party-night.md · docs/briefs/m14/bugs11/b021-end-night-1-report.md
check: format analyze host phone
report: docs/briefs/m14/bugs11/b021-end-night-1-report.md
