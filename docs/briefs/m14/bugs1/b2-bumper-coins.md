job: M14 bug b2: during a Bumper Round every player sees how many coins they have (owner's device test, Nov 12, 2026)
pub: no
stop: after it.
read: docs/coding-guidelines.md · docs/review-rules.md part A · docs/design/party-night.md section 7 (the Bumper Round's coin rules and scoring) · docs/briefs/m14/bugs1/b1-bumper-start-report.md (Summary only) · the Arena's game and its drawing in packages/test_game/lib · where the Arena's status strip is built (search for the texts in packages/party_host/lib/src/text/arena_text.dart) · the joined phone's Arena view in controller_app
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

The owner's report, in their words: "During a bumper game, players should see how many coins they have." In the screenshot (a phone hosting, mid-round) the strip along the top reads "Round 1  16.6 s  Best –  ● P1 Phone 6D8B  Wins 0  Hits 8  Dashes 0  ● Dash ready (A)" and a second line for Robo with the same fields; coins lie on the map but no count is shown anywhere.

Claude's design:
1. **In a Bumper Round the strip shows coins first.** Per player: the colour dot, the name, the game's own coin picture (not an emoji) with the count, then "Dash ready". Wins, Hits and Dashes leave the strip during a Bumper Round (they stay in the results and the stats); the time shown is the time left in the round. Other Arena modes keep their strip as it is.
2. **The count is also on the player.** A small coin count sits beside each player's character on the map (above the head, readable at phone size in the sunny and the night look), and pops briefly when it changes (up on a pick-up, down on a drop). A gold coin in the last 15 s counts as its real worth.
3. **A joined phone** shows its own player's coin count in its Arena view (in its existing status area).
4. Counts come from the round's existing state and snapshot; keep the snapshot within its 2048-byte budget. With four players the strip must fit a phone's width on one or two lines without clipping: shorten names with an ellipsis before dropping the count.

tests (each failing first): the strip's content for a Bumper Round with two and four players; the count follows pick-up, drop and gold coins; other modes' strip unchanged; the joined phone's count; the snapshot budget. All existing suites pass.

in the report: start with `## Summary` (at most 20 lines): what a player now sees, the files changed, decisions, anything not done, and what the owner should try on a device (one line each). Then Self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this) · every text a player sees goes through the text files, never a literal in a widget · write only inside this job's folder · leave no scratch file behind in the repository
allow: docs/briefs/m14/bugs1/b2-bumper-coins-report.md · packages/test_game · packages/party_host/lib/src/ui · packages/party_host/lib/src/text · packages/party_host/test · controller_app/lib · controller_app/test · packages/protocol
check: format analyze arena host phone tv protocol
report: docs/briefs/m14/bugs1/b2-bumper-coins-report.md
