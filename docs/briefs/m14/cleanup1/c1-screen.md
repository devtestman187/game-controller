job: M14 cleanup1 c1: type and guard the game screen's stage body
pub: no
stop: after it.
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
tests-first: exempt a pure typing and null-guard clean-up of a path the screen cannot reach with no game
read: packages/party_host/lib/src/ui/game_screen.dart (the `_stageBody` function and where `_field()` used to be, `git log -p -S_field -- packages/party_host/lib/src/ui/game_screen.dart` shows the old guard) · docs/coding-guidelines.md

Do exactly these:
1. `_stageBody(Object? night)` takes `PartyNight?` (the type `partyNightProvider` holds, from ../night/party_night.dart) instead of `Object?`.
2. `_stageBody` passes `_game!` to GameField unguarded. Restore the old `_field()`'s null guard: when `_game` is null in the playing/results stages, return `const SizedBox.shrink()` (use a local `final game = _game; if (game == null) ...`), no `!`.
Behaviour must not change otherwise. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines, in its first 40 lines): each item done / not done, decisions. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 100 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · every text a player sees goes through the text files · write only inside this job's folder and the allow: paths · leave no scratch file behind in the repository · never touch tv_test_app/windows/flutter/generated_plugin* or PNG files
allow: docs/briefs/m14/cleanup1 · packages/party_host/lib/src/ui/game_screen.dart · packages/party_host/test
check: format analyze host
report: docs/briefs/m14/cleanup1/c1-screen-report.md
