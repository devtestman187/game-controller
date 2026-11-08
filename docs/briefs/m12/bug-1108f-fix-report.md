# M12 bug 1108f — G4 report: a host sends every step at 60 Hz, timed by a step clock

Done at G4 ("stop: after it"), the gate the brief names. Which steps go out is now decided by the step
count alone — step `n` goes out once `(n × frameRateHz) ~/ simHz` passes the last sent index — so a
60 Hz host sends every one of the 60 steps a second, a 30 Hz host every second and a 20 Hz host every
third, whatever the host's clock does. A frame's `at` comes from a step clock (the anchor's host time
plus the steps since it, times a step), re-anchored to the host's estimate of a step's time when the two
differ by more than a step and after a resume, so consecutive frames are one frame interval apart.
`frameSlackMs` is gone; nothing else used it. No message, field or snapshot changed: only the host's
choice of steps and their times.

## The rules as built

- `_publishIfDue(n, wallMs)`: `index = (n * settings.frameRateHz) ~/ HostingSettings.simHz`, sent when
  `index > _lastFrameIndex`. `n` is the step just run (`_stepCount - 1`), so the round's first frame
  (`n = -1`, sent by `_publishFirstFrame`) is unchanged. Sounds still wait for the next sent frame, and
  with no viewer they are still dropped.
- `_stepTimeMs(n, wallMs)` is the step clock: `anchorMs + (n - anchorStep) * stepMs`, rounded once at the
  end. `wallMs` is `host.nowMs - accS*1000` for that step, as before. It re-anchors when
  `|wallMs - stepTime| > stepMs` (a stall past `maxCatchUpS`, a slow device) and on the first step after
  a resume (`_reanchor`, armed by the `paused` setter). Under normal wobble the clock moves on its own,
  so the frames are evenly spaced even though `host.nowMs` is not.
- `HostingSettings.simHz = 60` is new, with `_simStepS = 1 / simHz`, so the 60 lives once.
- Doc comments changed on the class, `advance`, `_publishIfDue` and the `paused` setter.

## Files changed

- `packages/game_kit/lib/src/game_session.dart` (335 → 376 lines) — `_publishIfDue` takes the step number
  and picks the send from the count; new `_stepTimeMs`; `_anchorMs`/`_anchorStep`/`_reanchor` replace
  `_frameStartMs`; `frameSlackMs` deleted; `advance` passes `_stepCount - 1`; the `paused` setter arms the
  re-anchor; class, `advance` and `_publishIfDue` docs say the new rules (m12 bug 1108f).
- `packages/game_kit/lib/src/hosting_settings.dart` (64 → 67 lines) — `simHz = 60` documented, `_simStepS`
  derived from it.
- `packages/game_kit/test/frame_timing_test.dart` (new, 190 lines) — `WobblyClock` (a `MemoryGameHost`
  whose `nowMs` is the Ticker's elapsed plus a seeded ±4 ms offset drawn afresh each callback) and the
  eight tests below.
- `docs/briefs/m12/bug-1108f-fix-report.md` — this report.

## Tests, each failing first

Run against the code before the fix (the same eight tests, same seed, same lengths; only the failure
message's wording and two constant names changed afterwards). "jumps" is how often a frame follows one
that isn't the step the frame rate counts before it, i.e. a step the host should have sent and didn't.

| Test | Before the fix | After |
| --- | --- | --- |
| 60 Hz rate, 60 Hz Ticker: every step is sent | **failed** — 186 frames sent of 240 due, 54 jumps | 240 of 240, 0 jumps |
| 60 Hz rate, 120 Hz Ticker: every step is sent | **failed** — 211 of 239, 28 jumps | 239 of 239, 0 jumps |
| 30 Hz rate, 60 Hz Ticker: every second step | **failed** — 120 of 120 but 53 jumps: the wrong steps | 120 of 120, 0 jumps |
| 30 Hz rate, 120 Hz Ticker: every second step | **failed** — 119 of 120, 19 jumps | 119 of 119, 0 jumps |
| 20 Hz rate, 60 Hz Ticker: every third step | **failed** — 80 of 80 but 31 jumps | 80 of 80, 0 jumps |
| 20 Hz rate, 120 Hz Ticker: every third step | **failed** — 80 of 80 but 25 jumps | 80 of 80, 0 jumps |
| a pause re-anchors the frame times and keeps the steps | **failed** — 46 of 61, 15 jumps | 61 of 61, 0 jumps, first frame back 0–17 ms from the host clock |
| a half-second stall re-anchors and keeps the steps | **failed** — 50 of 66, 15 jumps | 66 of 66, 0 jumps, last frame of the stall 0–17 ms from it |

Every test also checks every neighbouring pair of frames is `<1000 / frameRateHz> ± 1` ms apart
(16.67 → 16 or 17, 33.33 → 33 or 34, 50). The pause and stall tests check the re-anchored frame against
the host's clock with `_stepMs.round()` = 17 ms ("within one step", the one rounding).

The pause is 50 ms (three Ticker callbacks, so the pause itself is longer than a step: the drift rule
would re-anchor even without the resume flag — Question 2). The stall is the brief's 500 ms: the advance
runs `min(0.5, maxCatchUpS = 0.1) s` of steps, six steps, and all six go out.

The existing `session_test` and `frame_view_test` expectations pass unchanged, including the ones most at
risk: 'frames come at the frame rate' (57 steps → 57/29/19 frames at 60/30/20), 'the steps of one long
advance get evenly spaced times' (`[17, 33, 50, 67, 83, 100]`: the step clock anchored at 16.667 ms rounds
to the same list), 'a sound played twice in one advance plays once and is carried once', 'sounds from
before a viewer joined are not sent to it', 'steps run without viewers, but frames are not built', and
'a session that starts paused sends the round's first frame at once'.

## Values the expectations were computed from

- A 4 s run at a 60 Hz Ticker is 240 steps; at a 120 Hz Ticker 239 — the Ticker's elapsed is a rounded
  whole-µs `Duration`, so the last step of the run misses by microseconds. The tests take the step count
  from `session.stepCount`, not from the clock.
- Steps due: 60 Hz → every `n` (240 of 240); 30 Hz → `n = 0, 2, 4 …` (120 of 240); 20 Hz →
  `n = 0, 3, 6 …` (80 of 240). The frame intervals are `1000/60 = 16.667`, `1000/30 = 33.333`,
  `1000/20 = 50` ms.
- Why the old code dropped steps: at 60 Hz a slot is one step wide, `floor((at - start) / 16.667)` moves
  by one per step only while `at` moves by one step, and ±4 ms of clock wobble puts two steps in one
  slot 54 times in 240 (that is 22.5 %, not the owner's 4 in 10 — the owner's phone also ran a real
  Ticker and a real network; the shape of the fault is the same).
- A pause of 50 ms is three callbacks of `1000/60`; the first step back is sent at `wallMs`, i.e. less
  than one step below `host.nowMs`.
- A stall of 500 ms is capped to 0.1 s by `maxCatchUpS`; `0.1 / (1/60) = 6` steps, each sent at 60 Hz.
- Side observation: the joined phone's `frame_jitter` was already 1 ms median, so this fault showed there
  as `gaps` (1640) and `late` (1652) on 3754 drawn frames, not as jitter. With this fix the host sends every
  step, so a 60 Hz round should draw the host's steps without gaps.

## Test counts, before and after

`tools/check.sh format analyze kit host phone tv` on this machine; the "before" run was green at the start
of the job (kit 39).

| Check | Before | After |
| --- | --- | --- |
| kit (`game_kit`) | 39 | **47** (eight new frame-timing tests) |
| host (`party_host`) | 142 | 142 |
| phone (`controller_app`) | 382 | 382 |
| tv, format, analyze | PASS | PASS |

Also run as a cross-check though the brief doesn't name them (the session is shared): arena 43, puzzle 125,
both PASS.

## Checks run

- `tools/check.sh format analyze kit host phone tv` — PASS, all six (format 2 s, analyze 10 s, kit 47 in
  4 s, host 142 in 72 s, phone 382 in 38 s, tv 17 s; 143 s).
- `tools/check.sh arena puzzle` — PASS (43 and 125).
- `tools/review.sh` — `review: 0 fail, 1 note`: `game_session.dart` 376 lines (lib limit 400, aim 300;
  it was 335 before). No FAIL on any line of the diff.
- `tools/review.sh --strings` — 0 removed, 0 added (no player-facing text changed).
- `git status` still lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and
  `generated_plugins.cmake` as modified: they were listed before the job (a Flutter tool rewrite) and were
  not edited by it.

## Self-check (review rules, part A)

1. **Every host setup.** A TV or PC host sends no frame unless a phone views (`hasViewers` false clears the
   sounds and sends nothing — 'steps run without viewers, but frames are not built', 'sounds from before a
   viewer joined are not sent to it'); a phone hosting "Play on this phone" and one on "Show on this
   device" run the same `GameSession`, so they get the same frames; the joined phone is the one whose
   timing the new tests check (0 jumps, a frame every 16.67 ms); a phone one build older gets the same
   `FrameMessage` (`at` means the same thing), and `frame_view_test` passes unchanged.
2. **When kept state starts and ends.** The step clock (`_anchorMs`, `_anchorStep`, `_reanchor`) starts at
   the round's first step, re-anchors on a step's worth of drift and on the first step after a resume, and
   is plain fields that go with the session (no timer, nothing to cancel, `dispose` unchanged); with no
   viewer it keeps its place but sends nothing ('steps run without viewers…'), and with no round there is
   no session at all.
3. **How a new state combines with the others.** No new state: `_reanchor` is set only by a resume and
   consumed by the next step. Paused still steps nothing and sends nothing ('nothing steps or is sent while
   paused, and resuming does not catch up'), a round held before its first step still sends its board ('a
   session that starts paused sends the round's first frame at once'), and the pairs "pause then back" and
   "a 0.5 s stall mid-round" are the two new tests. Host away, player away, the results and leaving never
   touch `advance`.
4. **Stay in the job's folder.** Only `packages/game_kit` (two lib files, one new test file) and this
   report; the `tv_test_app/windows/flutter/generated_*` changes predate the job.
5. **Stop rather than overstep.** No file outside `allow:`; the brief and the code agree. The judgement
   calls are Questions 1–4 and were not acted on beyond the brief.

## Questions

1. **`HostingSettings.simHz` is new public surface.** The rule needs the step rate next to the frame rate,
   and `_simStepS` is now `1 / simHz`, so the 60 is stated once. If you'd rather not grow the public API,
   it can be a private const in `GameSession` instead — say which.
2. **The resume flag is not separately observable.** A pause longer than a step re-anchors through the
   drift rule anyway; a pause shorter than a step leaves the step clock at most that far off, which no
   black-box check can tell apart. The flag is in because the brief says so, and the pause test proves the
   outcome (frames within one step of the host clock after a 50 ms pause), not the branch.
3. **`game_session.dart` is 376 lines** (was 335; `review.sh` notes it, limit 400). The step clock is a
   self-contained 12-line method and three fields; if you want the 300-line aim back, the step clock could
   move to its own small class in the same job later.
4. **A display whose rate isn't a multiple of 60.** The host's estimate of a step's time then sawtooths
   within a step, so a re-anchor can pull a frame time back by up to the clock's wobble (≤ 4 ms in the
   tests); the phone's `PlayoutBuffer` ignores a frame not after its newest, so a back-jump of that size
   could, rarely, cost one frame. I ran the 60 Hz test with 72 and 90 Hz Tickers as well: no step dropped
   and every interval held, so I left the test at 60/120 as the brief says. Say if you want a guard that
   never lets `at` go backwards.
5. **What to expect on the owner's phones.** The 60 Hz round should now draw a frame per step with no
   gaps, and `late` should be left to the network; the `at` values are now stepper-perfect, so the
   `frame_jitter` median should stay ~1 ms or fall. A before/after from the same pair of phones would
   confirm it.

## Commit message

Time frames by a step clock, so 60 Hz sends every step

- Which steps go out comes from the step count alone, `(n × frameRateHz) ~/ simHz`: 60 Hz sends every
  step, 30 every second, 20 every third, whatever the host's clock does (m12 bug 1108f).
- A frame's `at` is a step clock — the anchor's host time plus the steps since, times a step — re-anchored
  when it and the host's estimate differ by more than a step, and after a resume, so consecutive frames
  are one frame interval apart; `frameSlackMs` goes.
- `HostingSettings.simHz` (60) gives the step rate one source, with `_simStepS = 1 / simHz`.
- Eight new kit tests with a ±4 ms wobbly clock at 60 and 120 Hz Tickers fail first (186 of 240 frames at
  60 Hz before, every step after) and the existing session and frame-view tests pass unchanged.

## Status row

Bug 1108f fixed at G4: a host picks the steps it sends from the step count alone (60 Hz every step, 30 every second, 20 every third) and times them with a step clock re-anchored on a stall and after a pause, `frameSlackMs` is gone, eight new kit tests fail first and pass (kit 39 → 47), all six checks green; open: the owner's two-phone check that the joined phone no longer shows gaps.

## Delete

- none

## Claude's answers

1. Keep `HostingSettings.simHz` public: the step rate belongs next to the frame rate.
2. Fine: the pause test checks the outcome.
3. Fine at 376 (limit 400); the step clock can move out when the file is next touched.
4. Added by Claude: a sent frame's `at` is never at or before the last sent one (`_lastSentAtMs`), test 'a frame is never sent at or before the last one, even when a re-anchor pulls the clock back' (fails without the guard). Kit 48.
5. Yes: the owner's next two-phone race confirms it.
