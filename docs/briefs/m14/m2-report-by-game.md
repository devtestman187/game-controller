job: M14 m2: the stats report gets a "By game and feature" table (party nights, the Bumper Round, maps, Robo's level, the cat's Chaos level, the finish)
pub: no
stop: after it.
read: packages/metrics/lib/src (session.dart: how a round is recorded, its `tags`; report.dart, report_rounds.dart, report_table.dart) · packages/metrics/test · packages/party_host/lib/src (where rounds are recorded: session_recorder, live_stats.dart, the night, game_screen.dart, puzzle_screen.dart) · docs/PRD-v2.md "What it records" and "Derived signals in the report" · docs/design/party-night.md sections 4–7a · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Make the safest choice and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

The owner, Nov 10: after the m14.1 build, "add a 'by game and feature'" table to the report, so M14's features show up in the play data.
1. **Record** what each round was, in the round's existing summary (prefer its `tags` list, so the summary schema stays compatible; if a new field is needed, older sessions must still read): the game (Shape Race / Arena), the Arena mode (race / bumper), the map id, whether it was a party-night round (and which round of how many), the Chaos level, Robo's level when Robo played, whether a Shape Race picture was completed (the celebration). Nothing that names a person; nicknames never go in.
2. **Report**: a "By game and feature" table: one row per game and mode, then rows per map, per Robo level, per Chaos level, and party nights (nights started, nights finished, rounds per night); columns: rounds, minutes, players, average players, finished rounds, good/okay/bad ratings where rounds carry them. Same table style as the others; also in the CSV if the CSV is per round or add a second CSV only if needed.
3. Older sessions (before these tags) count under "unknown" rather than being dropped.

tests (each failing first): each tag recorded for a Bumper round with Robo on a map, a night's Shape Race round with Chaos, a solo completed picture; the table's rows and numbers from a fixed set of sessions; old sessions under "unknown". All existing tests pass.

in the report: the tags and their meaning, a sample of the new table, test counts before and after.
self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow:
allow: docs/briefs/m14/m2-report-by-game-report.md · packages/metrics · packages/party_host/lib · packages/party_host/test · packages/test_game/lib · packages/test_game/test · packages/puzzle_game/lib · packages/puzzle_game/test · packages/game_kit/lib · packages/game_kit/test
check: format analyze metrics kit arena puzzle host phone tv
report: docs/briefs/m14/m2-report-by-game-report.md
