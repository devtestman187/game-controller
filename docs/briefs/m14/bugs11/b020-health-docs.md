job: M14 bugs11 b020-health-docs: close the run review's code-health findings
pub: no
stop: after it. Docs only.
read: docs/code-health.md (lines 90-115) · docs/briefs/m14/bugs11/REVIEW.md (Findings) · packages/party_host/lib/src/ui/game_screen.dart (confirm `wc -l`)
decide: low-usage mode: never stop for a question. Make the safest choice that fits and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
tests-first: exempt docs only, no behaviour

Edit docs/code-health.md only:
1 Under "M14 bugs6 leftovers" delete the `party_host (solo skip)` bullet (about line 102: the empty-box solo Bumper start) and the `game_screen.dart (late-joining phone)` bullet (about line 109: `_alone`); both describe code f11c4b1 deleted. In the `party_host (screens)` bullet change `game_screen.dart 379/380` to `373/380 (before bugs11's next change)`.
2 Add a section "### M14 bugs11 leftovers (run review of Nov 15, 2026)" with these coulds, one bullet each, wording shortened, with file:line: (a) `solo_arena_card_test.dart:52` "opens on Surprise me" is proved only by the absent `chosenMap-pinball` key, not the map the round played; also assert `arenaSnapshot(tester).mapId` is not `pinball` after `roundStarted`. (b) `solo_arena_card_test.dart:17` `openNightBumperCard` serves test 2 only and repeats test 1's setup; parameterise it or inline it (the file is rewritten by b020-solo-both: do it with its next change). (c) `night_start_screen.dart:74` comment says "as Shape Race's join screen does for two"; say "for two or more". (d) the next-map proposal (`b020-next-map-report.md`, a report only, not built): carry into its follow-up brief the sizes 373 / 381 / 370 (not 379 / 387 / 376), `menu_press_test.dart:61-64`'s Right press moving off Change mode when the button goes second, a step for `docs/design/party-night.md:107` (the results' button line), how `_ResultsBody`'s callbacks are carried (it has nine parameters, the proposal's tenth) and `:68`'s Wrap belonging to `_ResultsBody`; and the run report's `game_screen.dart` base was 379, not 380.
3 Do not touch any other file.
in the report: `## Summary` (at most 15 lines), then `## Hand-over`.
rules: aim for 20-40 turns · write only inside allow: · stage nothing yourself · never use git add -A
allow: docs/code-health.md · docs/briefs/m14/bugs11/b020-health-docs-report.md
check: format
report: docs/briefs/m14/bugs11/b020-health-docs-report.md
