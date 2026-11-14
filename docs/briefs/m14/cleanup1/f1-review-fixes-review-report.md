# M14 cleanup1 f1-review-fixes — review

## Summary

Verdict: **clean** (no must, no should). Counts: must 0 · should 0 · could 3.
All five rulings are in the tree, each done as written: the seam moved verbatim (`sound_loop.dart` 298 → 225, `loop_audio_engine.dart` 76), the results arm guards a local `result`, the two bare numbers are the library's constants (`_barFillInsetShare` 0.25 = 1/4 exactly, `_msPerSecond` 1000), the unfalsifiable protect test and `startEffect` are gone, and the cache test's `draw` closure is a top-level `drawFrame` (body 62 → 46 lines, 61–106). No behaviour change; no file over 380 lines; no new test, as the brief allows.
The three findings that matter most:
1. Self-check A1 names the wrong entry point to the results (`f1-review-fixes-report.md:59`).
2. The commit carries a 64,952-line generated run patch the report's file list omits.
3. The moved doc links `[SoundLoop]`, which is no longer in that file's library.

## Findings

- **could** docs/briefs/m14/cleanup1/f1-review-fixes-report.md:59 self-check A1 says the results are entered from `_start`/`_again` with `_result` set, but the only `_Stage.results` assignment is `_finished` (`game_screen.dart:250-251`) while `_start`/`_again` clear `_result` (`game_screen.dart:203`, `:228`) → name `_finished` as the one way in, which is what makes the null arm unreachable.
- **could** docs/briefs/m14/cleanup1/run-f1-review-fixes.patch:1 the commit adds this 64,952-line generated patch of the whole run and the report's "Files changed" does not list it → list it there, or leave it untracked like the other `run-*.patch` files so a reviewer's `git diff` shows only the job.
- **could** packages/party_host/lib/src/loop_audio_engine.dart:3 the moved `LoopAudioEngine` doc links `[SoundLoop]`, which is not in this file's library any more (the analyzer's `comment_references` is off, so nothing reports it) → say "the loop" or drop the brackets, as the reference resolves nowhere.

## Decisions to confirm

- New file name `loop_audio_engine.dart` although the review's `should` at `sound_loop.dart:227` says `audio_engine.dart`; the brief's ruling wins and the report states the trade — confirm the name.
- The shared inset constant lives in `phone_hud.dart:76` and is used by `board_hud.dart:85`; legal because both are `part of 'view.dart'`, and REVIEW open question 6 accepts it, but a reader of `board_hud.dart` alone cannot find it.
- `drawFrame` has 5 parameters (the guideline limit) and every call repeats `moments:`/`cache:`; the report lists both, so no hidden decision there.
- The results arm drops `ArenaResults` silently when `_result` is null (unreachable) and no comment says so; REVIEW open question 2 suggested one line and the brief did not ask for it — safe either way.

## Could not check

- The suite totals (host 401, puzzle 403) and `tools/check.sh` itself: no runner log is on disk for this job, so only the two changed test files were run here (both pass, see checks).
- Whether the worker or the harness (flash.sh's `$log.patch` fallback) put `run-f1-review-fixes.patch` into the commit; only that it is in cc9164a and unlisted.
- Whether the new doc link is reported by a full dartdoc build; `dart analyze`'s lint set has no `comment_references`.

Checks run here: `dart format --output=none --set-exit-if-changed` on the seven changed Dart files → 0 changed (page_width 120 from each package's `analysis_options.yaml`); `flutter test test/sound_loop_protect_test.dart` in party_host → 2/2 pass; `flutter test test/board_cache_state_test.dart` in puzzle_game → 1/1 pass; no line over 120 columns in the changed files; the moved block in `loop_audio_engine.dart` matches the deleted block in `sound_loop.dart` line for line.

## Commit message

Review f1-review-fixes: no must, three coulds

The five rulings are in the tree as written: the engine seam moved verbatim
(sound_loop.dart 298 -> 225, loop_audio_engine.dart 76), the results arm
guards a local result, two bare numbers are the library's constants, the
protect test that could not fail is gone, and the cache test's draw closure
is a top-level drawFrame (body 62 -> 46 lines). No behaviour change, and the
two changed test files pass here. Nits only: self-check A1 names _start and
_again as the way into the results where only _finished is, the commit adds
an unlisted 64,952-line run patch, and the moved class doc links SoundLoop,
which is not in the new file's library.

## Status row

M14 cleanup1 f1 fixes reviewed: all five rulings applied as written with no behaviour change (no must, three coulds: self-check A1 wording, an unlisted 65k-line run patch, a stale doc link); open: c2's test proof (the run review's one must) and B-004's loop check under load.

## Delete

- none
