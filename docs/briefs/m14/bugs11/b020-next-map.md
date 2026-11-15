# b020-next-map — proposal for B-020 (report only)

job: M14 bugs11 b020-next-map. Proposal only: change no Dart, no test, no design file; the only file written is the report.
pub: no
stop: after the report.
read: docs/design/party-night.md (N6, section 7b, section 8) · packages/party_host/lib/src/ui/game_screen.dart (_again, _changeMode, _next, _leave) · arena_results.dart · arena_waiting_card.dart · arena_map_choice.dart (Surprise me, lastMapId) · packages/party_host/lib/src/arena_settings_provider.dart · docs/briefs/m14/bugs5/pr-map-pick-report.md (the same question for Shape Race)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why.

Owner row B-020: "Single player arena does not show map selection or game type (bumper or arena) anymore ... Single player should allow the player to continue to the next map without needing to go to the stage selection." (The first part is fixed by job b020-solo-card: the waiting card shows again.)
Propose how one player gets from a finished Bumper/Arena round to the next map without the game picker. Cover: (a) outside a night: today the results offer Play again (same map), Change mode (back to the card) and Back (game picker); (b) in a one-player night: the results' one button is Next (to the scoreboard), so say whether a map step fits there; (c) which button, its words, where it sits on the results card (the card's mock-up is owner-approved: a button added goes back to the owner), what "next" means (Surprise me from the night's/last-played unused maps, or the library's order), how lastMapId and the night's used set are updated, and the effect on game_screen.dart (379 lines, cap 380: say what to split). Give two candidates with a pick and its risk, and the computed values (maps in the library, buttons before and after).
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines); end with `## Hand-over`. No code claims you did not check in the files.
tests-first: exempt proposal only, no code
rules: aim for 40-80 turns · write only inside allow: · stage nothing yourself · never use git add -A
allow: docs/briefs/m14/bugs11/b020-next-map-report.md
check: format
report: docs/briefs/m14/bugs11/b020-next-map-report.md
