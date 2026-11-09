job: M13 10b: play the round music, and speed it up as the clock runs out (owner, Nov 9, 2026: "Yes I want music during rounds ... As the timer gets closer to running out the music's tempo should speed up.")
pub: no
stop: after it.
read: docs/briefs/m13/s15-round-music.md, section "Playing it" (rules 1–7: your design, unchanged) · docs/briefs/m13/s15-round-music-report.md (the piece) · assets/audio/round.ogg, round_hurry.ogg, round_final.ogg (done: Claude rendered them; don't touch tools/audio or the oggs) · docs/design/look-and-sound.md section 8 · packages/party_host/lib/src/sound.dart, sound_wish.dart, sound_settings.dart, ui/lobby_music.dart, ui/lobby_music_widgets.dart, ui/round_palette_hold.dart, ui/pause_menu.dart, providers.dart · the round screens (PuzzleScreen, GameScreen) · assets/lib/asset_manifest.dart, assets/CREDITS.md · packages/party_host/test (lobby_music_test, countdown_test, sound_keys_test, the fake sound player in lib/testing.dart) · docs/review-rules.md · docs/coding-guidelines.md

What's done: the three loops are rendered and committed (s15 stopped before the playback because its sandbox couldn't run `dart run` or ffmpeg; you don't need either). Each is 16 bars of the same F major piece: `round` 31.997 s at 120 BPM, `round_hurry` 27.823 s at 138, `round_final` 24.613 s at 156.

Your job is s15's "Playing it", rules 1–7, with its tests, as written there. Notes from Claude:
- "Go" is when the round's phase becomes `RoundPhase.playing` (`roundPhaseProvider`, published by `Pausable` after the 3-2-1 beat; a round with no beat, the TV's, is playing at once). Paused, the host away, a phone the round waits for and the results are `RoundPhase.none` there: use that rather than a new signal where you can. The results end the round: fade out (300 ms), don't pause.
- The time left: Shape Race's clock and its `warningS` (puzzle settings). The Arena has no clock: it stays on `round`.
- `ui/pause_menu.dart` was just fixed (commit df2eec9): a round lets go of its 3-2-1 countdown when the beat runs out, so Play again's new countdown isn't stopped by the old screen. Keep that, and its test in countdown_test.dart.
- The switch between tempos keeps the place (the same share of the loop) and cross-fades over 120 ms. If `SoundPlayer` needs new calls for it (seek, fade, pause), add them to the interface and the fake player, with the fake recording them for the tests.
- Play again replaces the round's screen in one frame: the round music may restart from the top there (a new round), but must not stop and start the lobby music.
- Name the controller and files as you see fit; keep the lobby music's existing tests passing unchanged.

tests (each failing first): as s15 lists under "tests", leaving out the renderer and the ogg lengths (done), plus:
- Play again: the new round's music starts at its "go", after its own 3-2-1, and the 3-2-1 still plays (countdown_test's Play again test passes).
- The three keys are in `SoundKey` and CREDITS, and `sound_keys_test` lists them.

in the report: test counts before and after; the files changed; what a player hears from the lobby to the results, Play again included; the self-check.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · the puzzle tests rewrite docs/design/m12-mirror-*.png: restore them with `git checkout -- docs/design/m12-mirror-*.png` before you finish.
allow: docs/briefs/m13/s15b-round-music-play-report.md · docs/design/look-and-sound.md · assets/lib · assets/CREDITS.md · assets/test · packages/party_host · packages/puzzle_game · packages/test_game · tv_test_app/lib · tv_test_app/test · controller_app/lib · controller_app/test
check: format analyze look puzzle arena host phone tv kit
report: docs/briefs/m13/s15b-round-music-play-report.md
