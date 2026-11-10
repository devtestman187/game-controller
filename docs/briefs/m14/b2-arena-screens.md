job: M14 b2: the Arena's screens: the waiting card with modes, maps and Robo's levels; the ready beat on the TV; the results card; the music's clock; the night's Bumper Round
pub: no
stop: after it.
read: docs/design/party-night.md sections 7, 7a, 8, 11 · the approved Arena mock-ups (party-mockups.html, docs/design/look-mockups/m14-*) · docs/briefs/m14/b1-bumper-rules-report.md, k2a-map-pieces-report.md, k2b-four-maps-report.md, c1-night-report.md (question 3: nightBumperRoundReady and _startBumperRound), x1-chaos-night-report.md · packages/party_host/lib/src (game_screen.dart, night, lobby_music.dart, text) · packages/test_game/lib/src (the Arena's view and session) · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Build section 8 and the Arena parts of section 7: the waiting card picks **Race** or **Bumper Round**, a **map** (the five, from `ArenaMapLibrary`, each with its picture) and, for a lone player in the Bumper Round, **Robo's level** (Easy/Medium/Hard; Robo's seat itself is job b3: show the choice, store it, leave one named place for b3). The TV's ready beat before a round; the results card (coins, winner or draw, the mock-up); the round music's clock as Shape Race has it. Turn on `nightBumperRoundReady`: the night's Bumper Round button opens the waiting card and the round's `RoundResult` records into the night, doubled in the last round. D-pad, A and B work on every new screen; new words go in new text files where the old ones are near their limits.

tests (each failing first): the waiting card's choices and focus; the chosen map and mode reach the game; the results card's rows and the draw; a night's Bumper Round records into the scoreboard, doubled in the last round; the Bumper button is enabled. All existing tests pass.

in the report: each screen against its frame, test counts before and after.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/b2-arena-screens-report.md · packages/party_host/lib · packages/party_host/test · packages/test_game/lib · packages/test_game/test · controller_app/lib · controller_app/test
check: format analyze arena host phone tv
report: docs/briefs/m14/b2-arena-screens-report.md
