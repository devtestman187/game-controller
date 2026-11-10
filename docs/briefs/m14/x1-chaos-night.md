job: M14 x1: the party night meets the Chaos setting (connect c1's NightChaos seam to a2's PuzzleSettings.chaos)
pub: no
stop: after it.
read: packages/party_host/lib/src/night/party_night.dart (NightChaos and its comment) · docs/briefs/m14/c1-night-report.md (question 2 and Claude's review) · docs/briefs/m14/a2-cat-report.md · packages/puzzle_game/lib/src/settings.dart (chaos) · packages/party_host/lib/src/puzzle_settings_provider.dart · packages/party_host/lib/src/ui/night_start_screen.dart · packages/party_host/test/night_round_test.dart, night_screens_test.dart · docs/design/party-night.md sections 4, 5 · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude's design:
1. `NightChaos.catVisitsTonight` reads the host's saved Chaos setting: the start card's line "The cat visits the side that's ahead." shows only when it isn't off.
2. `NightChaos.settingsForRound` gives the night's last round Chaos off (G3: never in a night's last round); other rounds keep the host's setting.
3. Make `NightChaos` take what it reads (a ref or the settings) instead of static answers; keep it one small, named place.

tests (each failing first): the start card's cat line hidden with Chaos off and shown with A little; a night's round 1 keeps the host's Chaos, the last round plays with off; outside a night the round's settings are the host's own. All existing tests pass.

in the report: what changed, the tests, test counts before and after.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/x1-chaos-night-report.md · packages/party_host/lib/src/night · packages/party_host/lib/src/ui/night_start_screen.dart · packages/party_host/lib/src/ui/puzzle_screen.dart · packages/party_host/test/night_round_test.dart · packages/party_host/test/night_screens_test.dart · packages/party_host/test/party_night_test.dart · packages/party_host/test/support/night_harness.dart
check: format analyze host puzzle
report: docs/briefs/m14/x1-chaos-night-report.md
