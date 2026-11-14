## Summary

Job M14 cleanup1 c3: a real test of the music loop's protected voice (B-004).

- Done: `SoundLoop` now takes an optional `LoopAudioEngine` (default
  `const SoLoudLoopEngine()`, which reads `SoLoud.instance` at each call). Every
  engine use in `sound_loop.dart` goes through it; production code passes
  nothing and behaves exactly as before, B-004's `setProtectVoice` included.
- Done: new `packages/party_host/test/sound_loop_protect_test.dart` (3 tests)
  with a hand-written fake engine (`implements LoopAudioEngine`) and a fake
  `AudioSource` (`implements AudioSource`, `noSuchMethod`). It checks that
  `play` protects the voice it starts, that a tempo change protects the new
  voice (and starts it at the kept share), and that an effect voice is not
  protected.
- Done: shown failing on the old code. With the `setProtectVoice` line removed,
  all 3 tests failed (`Actual: []`); with it restored they pass.
- Done: `tools/check.sh format analyze host` passes (`format` PASS, `analyze`
  PASS, `host` PASS, 402 tests).
- Not done: nothing; no `sound.dart` change was needed, since the engine default
  keeps `_loop` construction as it was.

### Decisions

- Injected a small interface rather than `SoLoud? engine`: a fake of the whole
  `SoLoud` class is brittle (its API is large), while the loop uses 10 calls.
- Kept the seam in `sound_loop.dart` (298 lines): `sound.dart` is already 309
  lines and does not need to know about it.
- `SoLoudLoopEngine` reads `SoLoud.instance` inside each call, not once: the
  engine can start, restart and stop while a loop object lives (M14 g3).
- The fake's "effect" test seeds a voice the loop did not start; because
  `SoundLoop` has no effect path, that assertion is documentation of the rule
  rather than a branch it can get wrong.

## What changed

- `packages/party_host/lib/src/sound_loop.dart`: added `LoopAudioEngine` (10
  calls the loop makes, named as flutter_soloud names them) and
  `SoLoudLoopEngine` (its adapter, lazy `SoLoud.instance` getter); `SoundLoop`
  takes `LoopAudioEngine? engine` and its private helpers use `_engine`.
  No other change; the `setProtectVoice(handle, true)` call is untouched.
- `packages/party_host/test/sound_loop_protect_test.dart`: new test file.

## Test values

- Fake `getLength` is 30 s; the tempo change calls `play(..., at: 0.5)`, so the
  fake sees `seek(newVoice, 15 000 ms)`; asserted.
- Voice handles are `SoundHandle(1)` (first loop) and `SoundHandle(2)` (second
  loop, after the tempo change); the fake returns them in call order and
  `protected` is asserted as `[(1, true), (2, true)]`.
- The music volume passed to `play` is 0.8 (not asserted); the fade is 200 ms
  (not asserted).
- Old-code run (line removed): test 1 `Expected [(1, true)] Actual []`; test 2
  `Expected [(1, true), (2, true)] Actual []`; test 3 `Expected [2] Actual []`.
  Restored, all 3 pass.

## Self-check (review-rules.md part A)

1. Every host setup: not affected — the loop is host-side only and the default
   engine is `SoLoud.instance` on every host; no UI or platform branch. Shown by
   `sound_loop_protect_test.dart` plus the host suite (402 tests) passing.
2. Kept state: unchanged — no new state; voices, the fade timers and `_paused`
   end exactly as before (`reset`/`dispose` cancel the same timers). Shown by
   the existing `round_music`, `sound_restart` and `sound_wish` tests in the
   host suite; the new file adds no timers.
3. New state with the others: none added — the pause/stop/cross-fade paths are
   untouched and only the call target changed. Shown by the same host tests.
4. Folder: only `packages/party_host/lib/src/sound_loop.dart`,
   `packages/party_host/test/sound_loop_protect_test.dart` and this report.
5. Stop rather than overstep: not needed — no rule contradicted the code.

## Questions and suggestions

- None blocking. Suggestion only: the brief asked "not for effects"; the test
  records that a voice the loop did not start is never protected, but the loop
  has no effect path, so a future effect-capable engine seam would need a
  stronger assertion.

## Commit message

Add a test seam to SoundLoop and prove its voice is protected

`SoundLoop` takes an optional `LoopAudioEngine` (default: the app's
`SoLoud.instance`, read at each call), and every engine call goes through it.
The new `sound_loop_protect_test.dart` uses a hand-written fake to assert
`play` calls `setProtectVoice(handle, true)` on the voice it starts and on the
tempo change's new voice, and not on an effect's. With the call removed, all
three tests fail; with it, they pass. Production code passes no engine and
behaves as before (B-004's protection is not changed).

## Status row

M14 cleanup1 c3: B-004's loop protection now has a test that fails without it (seam `LoopAudioEngine` in `SoundLoop`); open: owner's decision on keeping B-004's trade-off, and a device check of the loop under load.

## Delete

- packages/party_host/test/zz_probe_test.dart
