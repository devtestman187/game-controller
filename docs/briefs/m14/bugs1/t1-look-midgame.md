job: M14 bug t1: switching between the sunny and the night look in the middle of a game takes effect at once (owner's device test, Nov 12, 2026)
pub: no
stop: after it.
read: docs/coding-guidelines.md · docs/review-rules.md part A · docs/design/look-and-sound.md · packages/party_host/lib/src/look_providers.dart, look_settings.dart, ui/look_and_sound_section.dart and the settings screen that hosts it · packages/toy_look/lib (look_choice.dart, toy_look.dart, toy_colors.dart, toy_background.dart) · how each game screen gets its look: party_host ui/game_screen.dart, ui/puzzle_screen.dart, packages/puzzle_game/lib/src/puzzle_painter.dart, piece_colors.dart, cat_paint.dart, and the Arena's painters in packages/test_game/lib · the joined phone's views in controller_app
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

The owner's report, in their words: "Switching to sunny or night mode mid-game doesn't work. If this is intentional, the option to do so shouldn't appear in the settings mid-game or there needs to be an indication to the user that the changes will take place when they leave the game."

Claude's decision: it is a bug; the look changes **at once**, wherever the setting is changed.
1. Find why a game in progress keeps the old look (a look read once when the game or its painters were made, a cached picture, a provider read once instead of watched, a painter whose shouldRepaint ignores the look) and fix it at the cause, for Shape Race (board, pieces, tray, cat, celebration, mirror view), every Arena mode including the Bumper Round, the results screens, the party night's screens, and the host's overlay controller on a phone host.
2. The game's state must not change: no restart, no lost pieces, time, coins or points when the look changes.
3. A joined phone follows its own look setting as today; if it is meant to follow the host's, keep that behaviour and make it live too. Say which it is in the report.
4. If, and only if, one screen truly cannot change live, do not leave it silently stale: show one line under the setting, "Changes when this round ends.", only while that is the case, and say in the report which screen and why.

tests (each failing first): for Shape Race and for the Arena, a widget test that starts a round, changes the look setting and finds the new look's colours on the next frame with the round's state untouched; shouldRepaint answers true when only the look changed. All existing suites pass.

in the report: start with `## Summary` (at most 20 lines): the cause, what a player now sees, the files changed, decisions, anything not done, and what the owner should try on a device (one line each). Then Self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this) · every text a player sees goes through the text files, never a literal in a widget · write only inside this job's folder · leave no scratch file behind in the repository
allow: docs/briefs/m14/bugs1/t1-look-midgame-report.md · packages/party_host · packages/toy_look · packages/puzzle_game · packages/test_game · controller_app/lib · controller_app/test · tv_test_app/test
check: format analyze host phone puzzle arena tv
report: docs/briefs/m14/bugs1/t1-look-midgame-report.md
