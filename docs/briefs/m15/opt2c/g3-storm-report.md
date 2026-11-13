# M15 opt2c-3 (storm): one spaced keyframe request on both sides, and the page's catch-up

## Summary

- **Host key rule.** `streaming/tap/tap_queue.py` gains `KeyRequestGate` (one
  ask outstanding until a keyframe or 2.5 s, at least 1.5 s between two asks,
  `KEY_OUTSTANDING_TIMEOUT_S`/`KEY_MIN_SPACING_S`); `ClientQueue` asks through
  it, clears it on a keyframe queued for the client, and counts
  `keyreq_suppressed` beside `keyreq` (`stats()` and `totals()`).
  `_clear_to_keyframe` asks nothing while the client already waits.
- **Encoder side.** `tap_runner.request_key_unit` uses the same gate until a
  keyframe leaves the encoder (cleared in `_on_new_sample`); the 200 ms constant
  is gone. `tap_server._message` now sends a client's `{"type":"key"}` through
  that client's queue, so both rules apply. `TapServer` takes a `clock=`.
- **Page.** `keyRequestMinMs` 500 -> 1500, a `KeyRequests` gate in
  `wc_counters.js` (one outstanding, 2.5 s or a keyframe message), counters
  `keyRequestsSuppressed` and `skippedDraws`; `_handleFrame` drops only over
  `hardQueueFrames` 40, and `_drew` draws only when the decoder queue is 0,
  closing older frames. `wc_stats.js` sends `wcSkippedDraws` when a host gauge
  slot is free and counts skipped frames out of `backlog`.
- **Encoder cap.** With `SESSION_TAP=on` and `SESSION_VBV_KBITS` 0 the encoder
  gets `vbv-buffer-size` = `video_kbps × 3 / frame_rate` (235 kbit at the
  default video 4716 and 60 fps) with `strict-gop=true`; `SESSION_TAP_VBV_KBITS`
  overrides. Tap off prints exactly the words it did (the existing off-word test
  still passes).
- **Measured (tp-stream, 180 frames of videotestsrc).** IDRs 61.9/24.5/24.3 KB
  without the cap and 28.2/21.6/23.3 KB with it (mean 36.9 -> 24.4 KB, file
  1995 -> 1753 KB); the element accepts the words. No intra-refresh or
  gradual-decoder-refresh property exists (`gst-inspect-1.0 nvautogpuh264enc`
  has no line matching "refresh").
- **Tests:** `tap_queue_test.py` 12 OK (new), `tap_runner_test.py` 6 OK (new),
  `tap_server_test.py` 33 OK (was 32), `tap_diag_test.py` 20 OK, the page's
  eight self-tests PASS (`wc_keys_selftest.html` 6/6 new, `wc_selftest.html`
  30/30 with its queue-depth check rewritten to the catch-up rule),
  `py_compile` and `bash -n` OK, `tools/check.sh format` PASS.
- **Obstacle:** `streaming/tap/entrypoint_pipeline_test.sh` now has one failing
  check ("word 17 changed with the tap on: 'vbv-buffer-size=235'"), because the
  tap session's encoder words changed by design; that file is outside `allow:`
  and needs one line (see Obstacles).
- **Turns:** about 45.

## Files changed

- `streaming/tap/tap_queue.py` (236): `KEY_OUTSTANDING_TIMEOUT_S`,
  `KEY_MIN_SPACING_S`, `KeyRequestGate` (`allows()`, `note_keyframe()`),
  `ClientQueue`'s clock, gate, `keyreq_suppressed`, `_ask_for_key`, the keyframe
  clear in `offer`, `_clear_to_keyframe` asking only when it was not waiting,
  `keyreq_suppressed` in `stats()` and `totals()`.
- `streaming/tap/tap_queue_test.py` (new, 141): the gate alone and one client's
  asks, with a fake clock.
- `streaming/tap/tap_runner.py` (367): `request_key_unit` through the gate,
  `clock=` keyword, `_key_gate.note_keyframe()` when an IDR is seen,
  `KEY_UNIT_MIN_INTERVAL_US` and `last_key_request_us` removed.
- `streaming/tap/tap_runner_test.py` (new, 172): a fake pipeline/sink/sample,
  the rule's spacing, expiry and the keyframe that ends a wait, and the event
  going out with the next frame.
- `streaming/tap/tap_server.py` (380): `TapServer(..., clock=)`, `_Client`
  passes it, `_message` acts on the client's queue instead of `_request_key`.
- `streaming/tap/tap_server_test.py` (469): `FakeClock`, two key-message tests
  advance it past the wait, one new test that a message inside the window is
  counted and sends nothing.
- `streaming/player/wc_counters.js` (183): `KeyRequests` (the page's gate,
  `keyRequestMinMs`/`keyOutstandingTimeoutMs`), counters `keyRequestsSuppressed`
  and `skippedDraws`.
- `streaming/player/wc_player.js` (376): `hardQueueFrames` 40 replaces
  `maxQueueDepth` 2, the gate replaces the two timestamp fields, `_drew` draws
  only the newest frame and counts the rest as skipped.
- `streaming/player/wc_stats.js` (371): `wcSkippedDraws`, `maxViewerGauges` 16,
  `backlogOf()` (received less drawn less skipped) in `batch()` and `line()`.
- `streaming/player/wc_selftest.html` (502): the decoder-3-frames-behind check
  now expects the delta decoded and no keyframe asked.
- `streaming/player/wc_keys_selftest.html` (new, 227): the six page checks
  below, fake socket/decoder/clock.
- `streaming/bench.sh` (1086): `wc_keys_selftest.html` in `run_page_selftest`.
- `streaming/entrypoint.sh` (772): header note, `SESSION_TAP_VBV_KBITS`,
  `tap_vbv_frames` 3, the computed value after `video_kbps`, and the tap's
  `vbv-buffer-size`/`strict-gop` pair in `capture_words`.
- `streaming/README.md` (646): the `SESSION_TAP_VBV_KBITS` row with the measured
  IDRs, and the key rule under the diagnostics lines.
- `tools/stream.sh` (781): `cmd_selftest` runs `tap_queue_test.py` and
  `tap_runner_test.py`.
- `docs/briefs/m15/opt2/PROTOCOL.md`: the key rule (one outstanding, 2.5 s,
  1.5 s spacing, both sides).

## Test values

- Gate: first ask true; +1.4 s false; +2.4 s false, +2.5 s true; a keyframe at
  ask+0 frees at ask+1.5 s and not at +1.4 s.
- Client queue: connect ask 1; a second ask 1.4 s later -> `keyreq` 1,
  `keyreq_suppressed` 1; a keyframe queued 0.2 s after an ask -> next ask at
  1.6 s goes (2); 2.4 s -> held, 2.6 s -> goes; an overflow after a keyframe
  asks once and a `drop_to_keyframe` 0.1 s later is held back (1, 1, 1); two
  `drop_to_keyframe` calls ask once and hold once.
- Runner: request, +1.4 s refused, +2.4 s refused, +2.5 s taken; an IDR sample
  after a request frees it (taken at +1.5 s), a delta sample does not; the
  taken request pushes one upstream event with the next frame.
- Page: 20 gap deltas over 1 s -> 1 message sent, `keyRequests` 1,
  `keyRequestsSuppressed` 19, `dropsGap` 20; keyframe at 1.0 s -> the gap at
  1.0 s is held and the one at 1.5 s goes (1, 2, 1); no keyframe -> held at
  2.4 s, goes at 2.6 s (1, 2); 25 deltas after a 400 ms gap with the decoder 5
  behind -> 26 chunks (key + 25), 1 draw, 24 skipped, 0 drops, 0 asks; queue 41
  -> the key only (1 chunk), `dropsQueue` 2, 1 ask, 1 held; two decoder errors
  -> 1 ask, 2 held, 2 errors.
- Encoder words with the tap on: `vbv-buffer-size=235 strict-gop=true` after
  `gop-size=60`; tap off: identical to the words the existing test pins
  (`entrypoint_pipeline_test.sh`'s off comparison still passes).

## Decisions (low-usage mode)

- **No recovery from the last keyframe (item 4):** serving a late client from
  the most recent IDR plus the deltas after it is a burst of up to a second of
  old video, itself a backlog, and the natural IDR is at most 1 s away.
- **One gate class, two callers:** `tap_queue.KeyRequestGate` holds the rule for
  the client queue and the runner, so the host has one implementation of it.
- **The page's gate lives in `wc_counters.js`:** `wc_player.js` would have passed
  the 380-line limit; the file is the player's own bookkeeping.
- **`TapServer` takes a clock:** the client rule needs a clock and a socket test
  cannot move real time; the keyword defaults to `time.monotonic` and the file
  stays at 380 lines.
- **`backlog` now subtracts `skippedDraws`:** with the catch-up, received-less-
  drawn would stay at the burst's size for the rest of the run; what is on the
  canvas plus what a newer frame overtook is the picture's real lag.
  `skippedDraws` is absent from the counters a batch is built from in
  `wc_stats_selftest.html` (not in `allow:`), so its expectations still hold.
- **`wcSkippedDraws` is a gauge only on a free slot:** the batch's own gauges
  plus diag (5) plus sound (1) are 15 today, so it goes; one more figure would
  not.
- **The overlay line is unchanged:** `wc_stats_selftest.html` pins `line()` and
  is not in `allow:`, so `skippedDraws` is a counter and a gauge, not a word
  there.
- **`_clear_to_keyframe` counts a held-back ask:** a client that already waits
  has already asked; it is `keyreq_suppressed`, not silence, so the line
  accounts for every drop.
- **`wc_selftest.html`'s queue-depth check is rewritten:** the brief replaces
  that rule (queue depth is no longer a reason to drop), so its old expectation
  would pin the bug.
- **`wc_decoder.js` unchanged:** it asks only through the player's
  `onNeedsKey`, so it already goes through the one page rule.

## Obstacles

- `streaming/tap/entrypoint_pipeline_test.sh` fails one check: its tap-on block
  requires the words before the tee to be the off words plus the NV12 caps only,
  and the encoder now carries the tap's `vbv-buffer-size=235 strict-gop=true`.
  It needs those two lines allowed among the inserted words (a second `inserted`
  span beside `nv12_at`). It is not in `allow:`, so it was left failing rather
  than edited; the off-word comparison in it, which is what the brief asks to
  prove, passes.
- The new Python test files were not run against the tree before the change:
  the tests and the implementation landed together, so their first run was on
  the new code (`tap_queue_test` 12/12; `tap_runner_test` 6/6 after one wrong
  expectation of mine was fixed). They cannot pass on the old tree:
  `KeyRequestGate` and the `clock=` keywords do not exist there.
- Inside `wsl -d tp-stream ... bash -lc '...'` a shell variable such as `$t`
  written in this job's command is expanded by the outer shell and arrives
  empty; commands here spell every path out. Nothing in the repository is
  affected.

## Self-check (review-rules.md part A)

1. **Every host setup.** Not affected: Linux session image and one browser page;
   no app or Dart change. `tap_server_test.py` (loopback clients),
   `bench.sh --selftest` (all eight pages).
2. **When kept state starts and ends.** A gate's wait starts at the ask and ends
   at a keyframe or 2.5 s; the spacing runs 1.5 s from each ask; with nothing
   flowing no ask happens (only an event asks). `stop()`/`close()` end the
   page's timers as before. `KeyRequestGateTest`, `ClientQueueKeyTest`,
   `KeyUnitRuleTest`, the six `wc_keys` checks.
3. **How it combines.** No pause/hide state on this path. A page reconnect sets
   `_needKey` and the host asks at connect while its request may be outstanding,
   so the page's own ask waits at most 2.5 s: `wc_selftest.html`'s reconnect
   checks and `wc_keys`'s expiry check.
4. **Stay in the job's folder.** `git status` shows only `allow:` paths; the
   `tv_test_app` generated files and `run-base` folders were there before.
5. **Stop rather than overstep.** One file is needed outside `allow:`
   (`entrypoint_pipeline_test.sh`, above); reported, not edited.

## Hand-over

- Host rule: `tap_queue.KEY_OUTSTANDING_TIMEOUT_S` 2.5 s,
  `KEY_MIN_SPACING_S` 1.5 s, `KeyRequestGate(clock)`; `ClientQueue.stats()` has
  `keyreq` (asks that went) and `keyreq_suppressed`.
- `{"type":"key"}` -> `ClientQueue.request_keyframe()` -> gate -> the runner's
  `request_key_unit()` -> gate -> `_push_key_unit_event` with the next frame.
  A keyframe queued for a client clears its gate; an IDR from the encoder
  clears the runner's.
- Page: `KeyRequests` in `wc_counters.js`, `keyRequestMinMs` 1500,
  `keyOutstandingTimeoutMs` 2500, `hardQueueFrames` 40 in `wc_player.js`;
  counters `keyRequestsSuppressed`, `skippedDraws`; gauge `wcSkippedDraws`
  (slot permitting); `backlog` = received - drawn - skipped.
- `kreq` in `tapdiag:` still counts asks that went out only; the `tap:` stats
  line is unchanged.
- New tests: `python3 streaming/tap/tap_queue_test.py`,
  `python3 streaming/tap/tap_runner_test.py` (both added to
  `tools/stream.sh selftest`); page test `wc_keys_selftest.html` (in
  `bench.sh --selftest`).
- Encoder: `SESSION_TAP_VBV_KBITS` (0 = `video_kbps × 3 / frame_rate`), applied
  only with `SESSION_TAP=on` and `SESSION_VBV_KBITS` 0. Verified in tp-stream:
  `gst-launch-1.0 -e videotestsrc num-buffers=180 ! video/x-raw,width=1920,
  height=1080,framerate=60/1 ! videoconvert ! video/x-raw,format=NV12 !
  nvautogpuh264enc bitrate=4716 rate-control=cbr gop-size=60 b-frames=0
  zero-reorder-delay=true preset=p1 tune=ultra-low-latency rc-lookahead=0
  [vbv-buffer-size=235 strict-gop=true] ! h264parse config-interval=-1 !
  filesink location=/tmp/x.h264`; AUs split on the AUD, IDR bytes summed.
- Not redo: the measured IDRs, the gate rules, the page checks.
- Open: `entrypoint_pipeline_test.sh`'s tap-on block; a phone run to see the
  storm counters drop; whether `SESSION_TAP_VBV_KBITS` should default on for
  the WebRTC branch too.

## Commit message

M15 opt2c: one spaced keyframe request on the host and on the page

The tap queue and the runner share one rule (KeyRequestGate): a keyframe
request is outstanding until a keyframe answers it or 2.5 s pass, and two
asks are 1.5 s apart; a client's {"type":"key"} goes through its queue's rule
and then the encoder's, and keyreq_suppressed counts what was held back.
The page asks at most once per 1.5 s with one request outstanding, decodes a
burst after a stall instead of dropping to a keyframe, and draws only its
newest frame (skippedDraws); only a queue over 40 falls back to drop + ask.
With SESSION_TAP on, the encoder gets a three-frame VBV buffer
(SESSION_TAP_VBV_KBITS): the biggest IDR measured 61.9 -> 28.2 KB.

## Status row

M15 opt2c-3 storm: the host's and the page's spaced one-outstanding keyframe rule, the page's catch-up, and the tap encoder's VBV cap are done and green (12+6 new Python tests, 33 server, 20 diag, 8 page self-tests, format PASS); open: one line in `entrypoint_pipeline_test.sh` for the tap-on encoder words, a phone run, and whether the VBV cap should apply without the tap.

## Delete

- none
