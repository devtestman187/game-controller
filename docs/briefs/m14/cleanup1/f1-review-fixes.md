job: M14 cleanup1 f1: the fixes from the cleanup1 review (docs/briefs/m14/cleanup1/REVIEW.md)
pub: no
stop: after it.
tests-first: exempt only moves, renames and constants; no new behaviour, no new test file
read: docs/briefs/m14/cleanup1/REVIEW.md ("Findings" only) · then only the files and lines each finding names · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude's rulings. Do exactly these (all other findings are handled or skipped):
1. packages/party_host/lib/src/sound_loop.dart: move `LoopAudioEngine` and `SoLoudLoopEngine` into a new `packages/party_host/lib/src/loop_audio_engine.dart` (export or import it wherever they were used, including the test). No behaviour change; sound_loop.dart keeps SoundLoop alone.
2. game_screen.dart ~354: `_result!` in the results arm: guard it like `_game` (local, `SizedBox.shrink()` / skip the ArenaResults when null). Same behaviour when set.
3. board_hud.dart ~85 `_barHeight / 4` -> `_barHeight * _barFillInsetShare`; phone_hud.dart ~65 bare `1000` in `_clock` -> `_msPerSecond` (the constants exist in the same library; if they are file-private to the other file, move one shared private-to-library constant into one file both parts can see).
4. sound_loop_protect_test.dart: delete the "an effect playing alongside the loop is not protected" test and its `startEffect` helper (it cannot fail). Keep the other tests.
5. board_cache_state_test.dart: the test body is over 60 lines: move the `draw` closure and the board helpers to top-level functions in the same file. Keep the assertions and the table of frames unchanged.
No behaviour change. All existing suites pass.

in the report: start with `## Summary` (at most 30 lines, in its first 40 lines): each item done / not done, decisions. Then Self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim for under 100 turns · no lib file you touch may end over 380 lines · no function over 60 lines · write only inside the allow: paths · leave no scratch file behind · never touch tv_test_app/windows/flutter/generated_plugin* or PNG files
allow: docs/briefs/m14/cleanup1 · packages/party_host/lib/src · packages/party_host/test · packages/puzzle_game
check: format analyze host puzzle
report: docs/briefs/m14/cleanup1/f1-review-fixes-report.md
