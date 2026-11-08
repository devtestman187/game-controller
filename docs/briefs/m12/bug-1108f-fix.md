job: m12 bug 1108f — the joined phone's game is choppy: the host drops about 4 in 10 frames at 60 frames a second
stop: after it.
read: packages/game_kit/lib/src/game_session.dart (`advance`, `_publishIfDue`, `_frame`, `paused`) · packages/game_kit/lib/src/hosting_settings.dart · packages/game_kit/lib/src/frame_view.dart (how `atMs` is used: jitter, the playout buffer) · packages/game_kit/test/session_test.dart · docs/review-rules.md

Owner's words (build 5, Nov 8): "Yes the game on the joined phone looked choppy." The joined phone's Diagnostics for a 80 s race: 3754 frames drawn, 1652 late, 1640 gaps (a step jump over 1.5 strides), jitter median 1 ms. The host drew at 120 Hz with no drops.

Claude's diagnosis: `_publishIfDue` picks which steps go out by wall-clock slot: `index = floor((atMs - startMs + slack) / intervalMs)`, with `atMs = host.nowMs - accS*1000` read at the advance. At 60 frames a second the slot is exactly one step wide, and `host.nowMs` at the Ticker's callback wobbles a few ms around the Ticker's own elapsed time, so two steps in a row often land in the same slot and the second is dropped: a late frame with a skipped step on the viewer. Tests use a clock that never wobbles, so they pass.

Claude's rules:
1. Which steps are sent depends on the step count only, never the clock: step `n` (0-based) is sent when `(n * frameRateHz) ~/ simHz` is past the last sent index (simHz 60). So 60 sends every step, 30 every 2nd, 20 every 3rd, and any rate in range spreads evenly. The round's first frame (-1) is unchanged. Sounds still collect until the next sent frame; no viewer still clears them.
2. A frame's `atMs` is a step clock: the anchor's host time plus the steps since the anchor times the step's ms (rounded to int at the end only). Anchor at the first step to `host.nowMs - accS*1000` as today. Re-anchor to that wall estimate when the step clock and it differ by more than one step (a stall past `maxCatchUpS`, a pause, a slow device), and after a resume. Under normal wobble, consecutive sent frames' `atMs` differ by exactly the frame interval (±1 ms rounding).
3. `frameSlackMs` goes if nothing else needs it. Doc comments on `advance`, `_publishIfDue` and the class say the new rules.

tests (each failing first, for the bug's reason): a fake host clock that wobbles (seeded random ±4 ms around the Ticker's elapsed) with Ticker callbacks at 60 Hz, and again at 120 Hz: at 60 frames a second every step is sent, n consecutive with no gap; at 30 every 2nd step; at 20 every 3rd; consecutive `atMs` differ by the interval ±1 ms. A pause, and a 0.5 s stall, re-anchor `atMs` to the host clock (within one step) and keep the step pattern. The existing session and frame view tests pass unchanged, or say in the report which expectation changed and why.
in the report: the before and after frame counts from the wobble test (sent, gaps) at 60/30/20; test counts before and after; the files changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it (a TV host sends no frames unless a phone views; say so).
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1108f-fix-report.md · packages/game_kit
check: format analyze kit host phone tv
report: docs/briefs/m12/bug-1108f-fix-report.md
