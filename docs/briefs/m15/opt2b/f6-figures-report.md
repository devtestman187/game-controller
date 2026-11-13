# M15 opt2b-6 (figures) — report

## Summary

The `player=wc` page now fills the host's "Streaming quality" row: `fps` (`deliveredFps` = frames
drawn over the interval, one decimal), `recv`, `decoded`, `dropped`, `freezes`/`freezeMs`,
`first frame ms` and the `resolution` fact come from the player's own counters; `wcDropped` (the wc
table) is untouched. Root cause: **proved** — with no peer connection the reporter had no
`inbound-rtp` `video` entry to read, so `viewerCounters`, the `deliveredFps` gauge and the
resolution fact stayed empty; the reporter check now passes all of them with `video: null`.

- `wc_counters.js`: `emptyCounters()` gains the draw figures; new `freezeGapMs` (150 ms) and
  `noteDrawnAt` — the first draw's `firstFrameMs` from `start()`, each gap over 150 ms a freeze.
- `wc_player.js`: `start()` records `startedAtMs`; `_drew` calls `noteDrawnAt` and keeps the drawn
  `frameWidthPx`/`frameHeightPx` for the resolution fact.
- `wc_stats.js`: `batch()` measures one interval and returns `video: wcVideoEntry(counters, fps)`,
  a plain object shaped like a WebRTC `inbound-rtp` video entry; `combinedSeries` passes it on.
- `reporter.js`: `const video = current.video ?? extras?.video ?? null` — `viewerCounters`, the
  fps gauge, the resolution fact and `firstFrameMs` (`video.firstFrameMs ?? …`) then work as they
  do with a track. With a peer connection nothing changes (`marker_selftest.html` 60/60).
- Still cannot show: `sent kbps`/`sent`, `loss %`, `rtt ms`, `jitter ms`, `late`, `relay`, `codec`
  and `jbtarget` — no outbound track, receiver or frame callback on this page (`late` is 0).
- Tests: `wc_stats_selftest.html` 29/29, `wc_selftest.html` 30/30, `marker_selftest.html` 60/60,
  `jbtarget_selftest.html` 24/24, `secure_selftest.html` 8/8, `wc_sound_selftest.html` 13/13,
  `tools/check.sh format` PASS; the new check failed first (`got [null,null,null,…]`).
- Not done: no Dart change (no name changed), no screenshot (no visual change). Obstacles: none.

## Decisions (why)

1. The video-entry route, not a second counter list: the reporter's own `viewerCounters`,
   `deliveredFps` gauge and resolution fact already read those names, so one object keeps the
   host, the Dart report and the page on one definition and the reporter grew by no line (380).
2. `framesDropped` is `received − decoded`, which is what `viewerCounters` computes (never
   negative), not `received − drawn`: it is the same rule the WebRTC row uses and the "decoded"
   column stays truthful. The player's own drop counters stay on the wc table as `wcDropped`
   (`dropsQueue + dropsGap`); the two differ only by frames in flight (≤ 2, `maxQueueDepth`).
3. `framesPerSecond` in the entry is the interval's drawn rate, not a track's reading: the brief's
   one-decimal figure. Null when no frame was drawn in the interval, so the gauge is omitted
   instead of being sent as 0.
4. `firstFrameMs` rides on the entry (a field a WebRTC track has not), and the reporter prefers it
   to its own: the reporter's is page time since load, the brief asks for the time from `start()`.
   A real track has no such field, so its row is unchanged.
5. The freeze gap is one named constant (`freezeGapMs` = 150) in `wc_counters.js`, next to the
   counters the player keeps, so the rule is testable without a socket, decoder or canvas.
6. `startedAtMs`, `lastDrawnAtMs` and the draw figures live in the counters object the player
   already owns (it holds `lastFrame` the same way): no second state to reset or dispose.
7. No entry until a frame arrived (`framesReceived > 0`): a page that received nothing sends no
   counters, so the row keeps dashes rather than reading as zeros.
8. The two selftest pages stay at their 500-line test cap (500 and 499) by compacting existing
   declarations, not by dropping or loosening a check; the brief's 380 lines is kept for the four
   lib files (max 380, reporter exactly).

## Tests and values

`wc_stats_selftest.html` (29 checks) — new:
- Freeze rule, fake clock, start 1000 ms, draws at 1250, 1350, 1501, 1901: gaps **100, 151, 400**
  → `freezeCount` **2** (151 and 400 are over 150; 100 is not), `freezeMs` **551** (151 + 400),
  `firstFrameMs` **250** (the first frame is not a freeze).
- Reporter batch, no connection, no marker: counters received **182**, decoded **180**, drawn
  **179**, freezeCount **2**, freezeMs **551**, firstFrameMs **250**, 1920×1080, over a **3000 ms**
  interval. `deliveredFps` = round(179 × 1000 × 10 / 3000) / 10 = round(596.67)/10 = **59.7**;
  `framesDropped` = 182 − 180 = **2**; `freezeMs` = round(0.551 × 1000) = **551**; `resolution`
  fact **1920x1080**; rate still **100 kbit/s** (37 500 × 8 / 3); stages still
  `stream_decode 23`, `stream_display 4`.
- `combinedSeries(null)()` → `{stages: [], gauges: [], facts: [], video: null}`.
- Extended check keeps the count: `same([... video: null])` and the compacted `countersOf`.

`wc_selftest.html` (30 checks) — the existing "a drawn frame sizes the canvas…" check now also
reads `firstFrameMs` **25** (start at 0, draw at 25 ms), `frameWidthPx` **1920**,
`frameHeightPx` **1080**; that value can only come through `noteDrawnAt`, so the player's call is
covered.

Runs (in `tp-stream`, synced with `tools/wsl-sync.sh tp-stream`):
- Before the code: `timeout 180 bash streaming/bench.sh --selftest` →
  `wc_selftest.html` `SELFTEST FAIL 1/30`, "expected [25,1920,1080,…], got
  [null,null,null,…]" (the counters do not exist yet), wc_stats page not reached. After the code:
  60/60, 24/24, **30/30**, **29/29**, 8/8, 13/13.
- `tools/check.sh format` → `PASS format (3s)`, all checks passed.

## Self-check (review-rules part A)

1. Every host setup: a viewer page only; hosts, "Play on this phone", "Show on this device" and
   joined phones never load it. One build older: an older host ignores the new counters' names it
   already knows (`framesReceived` etc. are the WebRTC page's) — nothing new on the wire
   (`marker_selftest.html` 60/60, `wc_stats_selftest.html` 29/29).
2. When kept state starts and ends: `startedAtMs` is set once in `start()`; `firstFrameMs`,
   `lastDrawnAtMs`, `freezeCount`, `freezeMs`, `frameWidthPx/HeightPx` start at 0/null with the
   player and are never reset (`wc_stats_selftest.html`, freeze check); `WcStats`'s
   `_batchAtMs`/`_drawnBefore`/`_bytesBefore` move only inside `batch()`, so an idle interval
   sends no fps and no rate (reporter check: `null` before the first bytes).
3. Combining with other states: nothing pauses, hides or blocks; a batch is still skipped while a
   page has a connection but no decoded frame (`_report` unchanged), and the marker's, sound's and
   jitter target's figures keep their own names, a repeated name is not added twice
   (`wc_stats_selftest.html`, `marker_selftest.html`).
4. Stay in the job's folder: writes only to the six `streaming/player/` files in `allow:` and this
   report.
5. Stop rather than overstep: nothing blocked. Left alone: `framesSent`/`lossPct`/`rtt`/`jitter`/
   `relay`/`codec`/`jbtarget` (no data on this page) and the Dart names, which already fit.

## Hand-over

What exists: `noteDrawnAt`/`freezeGapMs` in `wc_counters.js`; `startedAtMs`, the draw figures and
`frameWidthPx/HeightPx` in `wc_player.js`; `wcVideoEntry` and the `video` key of `combinedSeries`
in `wc_stats.js`; one line in `reporter.js` that prefers `extras.video`; a freeze check and an
extended reporter check in `wc_stats_selftest.html`; the draw check in `wc_selftest.html`.

Commands that worked:
- `tools/wsl-sync.sh tp-stream`, then in `tp-stream`, in `/work/flash-20261113-135205-57023`:
  `timeout 180 bash streaming/bench.sh --selftest`.
- `tools/check.sh format` on Windows.

Don't redo: no second counter list for the quality row — `wcVideoEntry` feeds the reporter's own
`viewerCounters`; don't reset the counters on reconnect (a run's totals stay totals); don't put
the freeze rule anywhere but `noteDrawnAt`. `wc_stats_selftest.html` is at 500 lines and
`wc_selftest.html` at 499: split before adding another check.
Open problems: none known. The quality row's `late` reads 0 on this page (a total of no
measurement); if that should read `-`, `framesLate` needs a "not measured" path in
`viewerCounters` (outside this brief).

## Commit message

Player page: player=wc fills the quality row from its own counters

The wc batch now carries the figures the host's "Streaming quality" row shows but had no source
for without a peer connection: `deliveredFps` (frames drawn over the interval, one decimal) and
the counters `framesReceived`/`framesDecoded`/`framesDropped`, `freezes`/`freezeMs`,
`firstFrameMs`, plus the `resolution` fact. `wc_counters.js` gains `noteDrawnAt`, which times the
first draw from `start()` and counts each gap over 150 ms (`freezeGapMs`) as a freeze with its
length. `wc_stats.js` builds those counters as a plain `inbound-rtp` video entry and
`combinedSeries` hands it on, so the reporter's own `viewerCounters`, fps gauge and resolution
fact read them with one added line and the WebRTC page is unchanged.

## Status row

M15 opt2b-6 done: the wc page reports delivered fps, received/decoded/dropped frames, freezes and
first-frame time in "Streaming quality" — open: `late` reads 0 on this page; sent, loss, rtt,
jitter, relay and codec still have no source without a peer connection.

## Delete

- none
