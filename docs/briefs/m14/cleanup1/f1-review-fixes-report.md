# M14 cleanup1 f1: the review fixes — report

## Summary

All five rulings are done; no behaviour change, no new test, no new file beyond the split's new lib file.

1. **Done.** `LoopAudioEngine` and `SoLoudLoopEngine` moved out of `sound_loop.dart` into a new
   `packages/party_host/lib/src/loop_audio_engine.dart`, doc comments and bodies unchanged.
   `sound_loop.dart` now imports it and keeps `SoundLoop` alone (225 lines, from 299). The file is not
   exported from `party_host.dart` (nor was `sound_loop.dart`), so no barrel change. The protect test
   imports the new file; `sound.dart` needed no change (it only constructs `SoundLoop`).
2. **Done.** `game_screen.dart` results arm: `final result = _result;` beside the `_game` local, and the
   `ArenaResults` child is now `if (_stage == _Stage.results && result != null)`; `_result!` is gone.
   Same view when set; when null the field still shows and the card is skipped, as the brief asks.
3. **Done.** `board_hud.dart` insets the fill with `_barHeight * _barFillInsetShare`; `phone_hud.dart`'s
   `_clock` divides by `_msPerSecond`. Both files are `part of 'view.dart'`, so the two constants (in
   `phone_hud.dart:76` and `board_hud.dart:17`) are already visible in both — no constant moved.
4. **Done.** The "an effect playing alongside the loop is not protected" test and its `startEffect`
   helper are deleted; the two tests that can fail stay. Host suite 402 → 401, the one removed test.
5. **Done.** `board_cache_state_test.dart`: the `draw` closure became top-level `drawFrame(puzzle,
   snapshot, {moments, cache, nowMs})`; the helpers `box`, `pair`, `board` were already top-level and are
   unchanged. Assertions, the frame table and every expected count are untouched; the test body is now
   46 lines (61–106), from 62.

Checks: `tools/check.sh format analyze host puzzle` — format PASS, analyze PASS, puzzle PASS (403
tests), host PASS (401 tests).

## Decisions

- **New file name `loop_audio_engine.dart`.** The ruling names it; the review had suggested
  `audio_engine.dart`. I followed the brief.
- **No comment on the results arm.** REVIEW open question 2 suggests one line saying a null `_result`
  drops the card; the brief's list does not ask for it, so I left the arm as the ruling describes
  (`result != null` already reads as the guard).
- **One function, not two.** The ruling says "the `draw` closure and the board helpers"; the helpers
  (`box`, `pair`, `board`) already sat at top level, so only `draw` moved. It takes the three values it
  closed over (`puzzle`, `moments`, `cache`) as parameters — five parameters, the guideline's limit.
- **Call sites repeat `moments: moments, cache: cache`.** I did not keep a local wrapper closure; the
  calls name the cache explicitly, which is what the test is about.

## Files changed

- `packages/party_host/lib/src/loop_audio_engine.dart` — new: `LoopAudioEngine` and
  `SoLoudLoopEngine`, moved verbatim (76 lines).
- `packages/party_host/lib/src/sound_loop.dart` — the two types removed, `import
  'loop_audio_engine.dart'` added; 225 lines.
- `packages/party_host/lib/src/ui/game_screen.dart` — `_result!` replaced by a local `result` and a
  null guard on the results child; 371 lines.
- `packages/party_host/test/sound_loop_protect_test.dart` — imports the new engine file; the
  effect test and `startEffect` deleted; 84 lines.
- `packages/puzzle_game/lib/src/board_hud.dart` — `_barHeight / 4` → `_barHeight * _barFillInsetShare`.
- `packages/puzzle_game/lib/src/phone_hud.dart` — `1000` → `_msPerSecond` in `_clock`.
- `packages/puzzle_game/test/board_cache_state_test.dart` — `draw` closure → top-level `drawFrame`;
  107 lines, test body 46.

## Self-check (review-rules part A, items 1–5)

1. **Every host setup.** Not affected: a file split with no body change, a null guard that only differs
   when `_result` is null (unreachable: results are entered from `_start`/`_again` after `_result` is
   set), and two named constants. Every host type runs the same code. Test: `host` suite (401) passes;
   no host-specific test exists for these paths and the review found no behaviour to test.
2. **When kept state starts and ends.** Not affected: `SoundLoop`'s handle, fading timers and paused flag
   are unchanged (the class body moved no line); `BoardCache`'s record list is a local in the test. The
   engine adapter holds nothing (it reads `SoLoud.instance` per call, as before). Test:
   `sound_loop_protect_test.dart` (2 tests) passes.
3. **How a new state combines with the others.** Not affected: no new state; the results arm's guard is
   the same guard the `_game` local already had, and the stage machine is untouched. Test: `host` suite.
4. **Stay in the job's folder.** Yes: wrote only `packages/party_host/lib/src`,
   `packages/party_host/test`, `packages/puzzle_game/lib/src`, `packages/puzzle_game/test` and this
   report. `git status` also shows PNGs, `tv_test_app/windows/flutter/generated_plugin*` and untracked
   `docs/briefs/m14/bugs*` files; all predate this job and were left alone.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`; the brief's rulings were all
   doable as written, so no stop.

## Anything I was unsure of

- The review's `should` at `sound_loop.dart:227` describes the new file as `audio_engine.dart`; the
  ruling says `loop_audio_engine.dart`. If Claude wants the review's name, it is a one-line `git mv`.
- I did not re-run the c2 test against the pre-95da0ac tree (the run's `must`); it is outside this job.
- `game_screen.dart` is 371 lines: inside the brief's 380, past the guideline's ~300, as the review
  already recorded.

## Commit message

Apply the cleanup1 review fixes: split the engine seam, guard _result

Move LoopAudioEngine and SoLoudLoopEngine from sound_loop.dart into
loop_audio_engine.dart, so SoundLoop's file holds one public type (225
lines). Guard the results arm's _result with a local and a null check, as
_game already was. Use the library's _barFillInsetShare and _msPerSecond
instead of bare numbers in the two HUD parts. Drop the protect test that
could not fail, with its startEffect helper. Move the cache-state test's
draw closure to a top-level function, so its body is 46 lines. No
behaviour change: host 401 tests, puzzle 403.

## Status row

M14 cleanup1 f1 fixes applied: the engine seam split into `loop_audio_engine.dart`, `_result` guarded,
two bare numbers named, one unfalsifiable test and a 62-line test body removed; no behaviour change, all
suites pass. Open: B-004's trade-off and its loop check under load, and the run's `must` (the c2 test's
proof against its base tree).

## Delete

- none
