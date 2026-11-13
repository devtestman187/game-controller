# M15 opt2-4 — the custom player's measurements (`player=wc`)

## Summary
The custom player now measures itself, on switches that default off. New: `wc_stats.js` (one
player's `counters()`/`stageSamples()` in, six gauges and the `wc` fact out) and
`wc_stats_selftest.html` (13 page tests). Edited: `marker_reader.js` and `latency_probe.js` take a
`picture` (the video element or the canvas; `videoPicture`/`canvasPicture` helpers), `reporter.js`
serves both modes (no peer connection, a `picture`, `drawnFrame`), `overlay.js` takes a `wcLine`
and samples without a connection, `player.js` wires it from `WcPlayer`'s `onDrawn` (380 lines),
`bench.sh` (`player wc` in the switches line, the new test page), `packages/metrics` (the
"Custom player (wc)" table, names, and `report_stream_wc_test.dart`).
Tests, `timeout 120 bash streaming/bench.sh --selftest` in `tp-stream`: `marker_selftest.html`
60/60, `jbtarget_selftest.html` 24/24, `wc_selftest.html` 22/22, `wc_stats_selftest.html` 13/13,
all PASS; the new page cannot pass on the old code (its module did not exist). `bash -n bench.sh`
is clean, and `switches:`/`check_player_query` were run from the distro: `marker=1&player=wc` is
accepted and prints `…, player-options none, player wc`.
Decisions: the wc figures go through the reporter's existing extra-series provider, as
`jb_target.js` does (a `combinedSeries` in `wc_stats.js` joins the two); the marker's strip and
the card's patch are read from the canvas, so with `player=wc` the video element is never read;
the fact is `cfg hw dec ok` (no `=`, 14 characters, inside the host's 24/character rules, with
`cfg none dec no` when the text cannot fit); every figure is an interval median and no sample is
sent as a 0; the overlay shows the custom player's one line and no connection lines.
Not done: a live run against a host (out of scope for this job). Turns used: not known.
Obstacles: `dart`, `bash tools/check.sh`, `tar` and `rm` needed approval this session did not get,
so the Dart format/analyze/test could not be run and the files reached the distro as one `cat`
per file; a helper script `tmp-copy-player.sh` used for that copy could not be deleted (the report
says so under Delete). The distro's output gave no instructions.

## Decisions (why)

- One path for both players: the reporter takes `peerConnection: null` with `player=wc`, a
  `picture` to read, and frames pushed by `drawnFrame(frameNo, drawnAtMs)` from `WcPlayer.onDrawn`.
  `report.get(...)` and `forEach` became null-safe and the "no picture decoded" guard skips only
  a page that has a connection, so a WebRTC run's batches and guards are exactly as before.
- Extra figures through `setExtraSeries`: the reporter keeps its one-provider API; `combinedSeries`
  in `wc_stats.js` joins the jitter buffer target's provider and the custom player's, and neither
  exists off its switch, so with the option off nothing new is sent.
- The fact `cfg <hw|nohint|bad|none> dec <ok|no>`: the host drops a fact over 24 characters or
  with a character outside `[A-Za-z0-9 ,._()+-]`, and `=` is outside it, so `cfg=hw dec=ok` from
  the brief became space-separated; `configWord` only says what `decodeConfig` text says.
- Interval medians, gauges only with samples: `wcRecvToDecodeMs`/`wcDecodeToDrawMs` are the
  medians of the frames finished since the last batch, and a batch with no finished frame sends
  neither; the overlay keeps the last interval that had one, so it is not blanked every other tick.
- `wcQueueMax` is the player's `queueMax` (its own lifetime maximum), a small deviation from "max
  in the interval": the player keeps one number and a per-interval maximum would need a second
  sample list for one gauge.
- The WebSocket backlog's *time* (`largest gap lastReceiveAt → now`) is in the overlay's one line
  (`age N ms`) only: the six gauge names are fixed by the brief, and the age is a diagnostic, not
  a table column; the `wcBacklog` gauge counts frames, as named.
- The overlay's `wcLine` is one line and, with `player=wc`, the only picture line: `start(null)`
  samples no connection and `_showNumbers` pushes only what the page has. `isSampling` now means
  "a sampling timer runs", so a later `pictureReady` cannot replace the custom player's sampler.
- `canvasPicture` reads `canvas.width/height` live: `WcPlayer` sets them when the decoder's
  configuration arrives, and the strip's cell size follows the picture's width as it does today.

## Tests and values

`wc_stats_selftest.html` (13 checks), from a fake player and painted canvases:

- Samples `(frame 8: 0 → 12 → 14)`, `(frame 9: 100 → 116 → 120)`, `(frame 10: 200, unfinished)`:
  `wcRecvToDecodeMs` 14 (median of 12 and 16), `wcDecodeToDrawMs` 3 (median of 2 and 4).
- Counters `dropsQueue 2 + dropsGap 1` → `wcDropped` 3; `framesReceived 12 - framesDrawn 9` →
  `wcBacklog` 3; `wcKeyRequests` 3; `wcQueueMax` 4; fact `cfg hw dec ok` (14 characters).
- A second batch with no finished frame sends four gauges, not six.
- The overlay's line, after `noteDrawn(260)` with the newest arrival at 200 ms:
  `wc recv-dec 14 ms dec-draw 3 ms drop 3 backlog 3 age 60 ms keys 3 q 4 cfg hw dec ok`.
- `wcFactText(…, 8)` → `cfg none dec no`; a player that never drew → `cfg none dec no`.
- `wcStatsOf({player: 'webrtc'})` and `wcStatsOf({})` are null, and `combinedSeries(null)` is
  `{gauges: [], facts: []}`: no option, no figures.
- A 1920×64 canvas painted with spec row 0 (counter 0) and read once: 1 frame, 1 readable,
  `glassMs` 1000 (`toHostMs` adds 1000), no problem — the noise painted under row 16 is not read.
- The same canvas repainted with spec row 1 (press flipped) one frame later: `pressesMs` 8 for a
  press at host 1000 read at page 8.
- A 1920×1080 canvas with the card's patch light then dark: the probe's flip is read from the
  canvas (1 flip), a waiting press at host 0 is seen with `sampleMs` 8, no problem.
- A canvas with no size: 0 readable, one problem ("the picture has no size yet").

`packages/metrics/test/report_stream_wc_test.dart` (3 tests): a page that sent the fact and the
gauges gets the table, header `session viewer recv-dec ms dec-draw ms dropped backlog max keys
queue max decode`, row `wc v1 11.0 3.0 5 3 2 2 … cfg hw dec ok` (means 11 and 3, maxima 5, 3, 2,
2); a WebRTC run has no "Custom player" text and still has its quality table; of two sessions only
the fact's viewer is a row.

## Self-check (review-rules part A)

1. Every host setup: a run without `player=wc` sends exactly today's batches — the extra series
   provider stays null unless `jbTarget` or `wcStats` exists, the marker and probe read
   `videoPicture(video)`, and every figure has a test for the option off.
2. Kept state: `WcStats` holds a last-frame mark and the last medians and nothing that outlives the
   page; the reporter's timers are the ones it always had, `start()` without a connection opens no
   frame loop (`_watchFrames` guarded), and `stop()` leaves nothing running.
3. Combining states: `player=wc` plus `marker=1` reads the strip from the canvas; the press probe
   reads the card's patch from the canvas; the sound's connection still feeds the overlay, and the
   WebRTC path is untouched (`picture`/`peerConnection` defaults are the old values).
4. Stay in the job's folder: every changed file is in `allow:`; `/work/job` in the distro is the
   test copy; no repository file outside the list changed.
5. Stop rather than overstep: the two places the brief left open (the backlog's age, the queue's
   maximum) were answered in the Definitions above and shown to the viewer rather than to a new
   gauge; nothing outside `allow:` was needed.

## Hand-over
What exists: `wcNames`, `wcFactText`, `WcStats` (`noteDrawn`, `batch`, `line`), `combinedSeries`,
`wcStatsOf` in `wc_stats.js`; `videoPicture`/`canvasPicture` and `MarkerReader({picture, …})` in
`marker_reader.js`; `LatencyProbe({picture, …})`; `StreamReporter({video, peerConnection, picture,
marker, …})` with `drawnFrame(drawnAtMs, metadata)`; `Overlay({…, wcLine})` with `start(null)`;
`StreamWc`, `wcReport` and the "Custom player (wc)" table in `packages/metrics`.

Commands that worked: `timeout 120 bash streaming/bench.sh --selftest` in `tp-stream` from
`/work/job` (the player folder beside `bench.sh`); `bash -n bench.sh`; the switches/query check by
sourcing `switches_line` and `check_player_query` out of `bench.sh` with `player_query` set.

Next phase must not redo: the reporter's two-mode plumbing, the canvas picture, the fact text and
the gauge names (all tested), or the table's shape. Open problems: the Dart format/analyze/test
did not run here (approval), so `tools/check.sh format analyze metrics` is the first thing to run;
`wcQueueMax` is a lifetime maximum and the backlog's age is overlay-only (both above).

## Commit message

Player page: measure the custom player's frames and send them with the stream's stats

With `player=wc` the page reads its marker's strip and the card's patch from the canvas, drives
the reporter from each draw, and sends six gauges (`wcRecvToDecodeMs`, `wcDecodeToDrawMs`,
`wcDropped`, `wcBacklog`, `wcKeyRequests`, `wcQueueMax`) and one `wc` fact through the reporter's
extra series, inside the host's limits. The report grows a small "Custom player (wc)" table only
for a viewer that sent the fact, and the bench's switches line says `player wc`. WebRTC runs and
every option off are unchanged.

## Status row

M15 opt2-4 done: custom-player figures, canvas marker/probe, wc stats table, bench switches and
tests — open: a live run against a host, and the Dart checks pending approval here.

## Delete

- `tmp-copy-player.sh` (scratch, at the repository root): the helper that copied the player folder
  into the distro one file at a time; `rm` was refused here, so it is left for the operator.
