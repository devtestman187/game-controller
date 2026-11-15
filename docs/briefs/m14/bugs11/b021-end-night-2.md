job: M14 bugs11 b021-end-night-2: "End night" on Shape Race's night results card (B-021, phase 2 of 2)
pub: no
stop: after it.
read: docs/briefs/m14/bugs11/b021-end-night-1-report.md (Summary and Hand-over only; it names `PartyNight.endNow`) · packages/party_host/lib/src/ui/puzzle_screen.dart (`_next`, `_leaveForGames`) · lib/src/ui/puzzle_results_widgets.dart (`night`, `_ResultButtons`) · lib/src/text/night_text.dart · tests: puzzle_results_test, round_results_test, night_screens_test, menu_press_test, night_round_test
decide: low-usage mode: never stop for a question. Make the safest choice that fits and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner, Nov 15, 2026 (B-021): "End night button. Ignore 'shuffle.'"

1 A night's Shape Race results card shows "End night" (phase 1's text, key `endNight`) beside Next, except after the night's last round. It does what phase 1's wiring does: `endNow` with the round's result, then the reveal over `isGamePickerRoute`. Back stays as it is (it records like Next).
2 `puzzle_screen.dart` is at 380 lines: first move something out (the results wiring, the `_leaveForGames` family) into a sibling file `puzzle_screen_results.dart`, a pure move, so it ends at 380 or fewer.
3 Leave the series round's Next puzzle and Shuffle alone (owner: ignore shuffle).
tests: new file `packages/party_host/test/end_night_puzzle_test.dart`: a night's Shape Race round finished: the button shows; pressing it opens the reveal; after the last round there is none. A phone host's results are pinned: `check:` has `phone`.
in the report: `## Summary` (15 lines max).
rules: aim for 40-100 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself · never use git add -A · run only your own tests and the `read:` ones, the full check once at the end
allow: packages/party_host/lib/src/ui/puzzle_screen.dart · packages/party_host/lib/src/ui/puzzle_results_widgets.dart · packages/party_host/lib/src/ui/puzzle_screen_results.dart · packages/party_host/test/end_night_puzzle_test.dart · packages/party_host/test/puzzle_results_test.dart · packages/party_host/test/round_results_test.dart · packages/party_host/test/night_screens_test.dart · packages/party_host/test/menu_press_test.dart · docs/design/party-night.md · docs/briefs/m14/bugs11/b021-end-night-2-report.md
check: format analyze host phone
report: docs/briefs/m14/bugs11/b021-end-night-2-report.md
