# M15 opt2b-1 (register) — report

## Summary

The `player=wc` page now registers as a viewer without the marker: its reporter batch always
carries `bitrateReceivedKbps` (bytes received on `/tap` over the interval), `stream_decode` (mean
decode ms per frame) and `stream_display` (decode-to-draw), computed from the player's own
counters. Root cause: **proved** by a pure test — the reporter's own batch had no `bitrate` and no
decode stage without a peer connection, so `wait_viewer`/`has_receive_data` stayed empty while the
picture played.

- `wc_counters.js` (new, 114): the counters, canvas drawing and stage samples moved out of
  `wc_player.js` (which was at 380) before anything was added.
- `wc_stats.js`: `wcHostNames` = `bitrateReceivedKbps` / `stream_decode` / `stream_display`;
  `batch()` emits them; `combinedSeries` merges stages, gauges and facts with `[]` defaults.
- `reporter.js`: extras' stages/gauges are added, a name already present is not duplicated.
- `error_trap.js` (new, 119) + `index.html` loading it first: `error` and
  `unhandledrejection` print `page error: <message> (<file>:<line>)` on the overlay and POST
  `/page/error`; at most 5 per load; the trap itself never throws.
- `wc_player.js` / `player.js`: `bytesReceived`, missing `WebSocket`/`VideoDecoder`/
  `EncodedVideoChunk` named on the overlay and reported the same way.
- `serve.py` / `relay_test.py`: `/page/error` on the allow-list, relayed as
  `relay: page error: <sessionId> <site> <message>` to the relay's stderr (session log keeps it);
  no host-side code needed.
- Tests: `wc_selftest.html` 30/30, `wc_stats_selftest.html` 16/16, `marker_selftest.html` 60/60,
  `jbtarget_selftest.html` 24/24, `relay_test.py` 38 checks; `dart format` 795 files, 0 changed.
- Not done: none. Obstacles: `tools/check.sh format` needed an approval, so its command ran directly.

## Decisions (why)

1. New `wc_counters.js` first: `wc_player.js` was at the 380-line cap, so the frame stages, the
   canvas and `emptyCounters()` moved out before the new code went in.
2. The three host names live in one exported object (`wcHostNames`) so the page and the tests read
   the same literals; a rename can't drift.
3. `bitrateReceivedKbps` is computed between two batches from `bytesReceived` and page time, and is
   **omitted** when the interval had no new bytes (or no elapsed time) — a 0 there would read as a
   dead socket, and the reporter already drops a null gauge. During play bytes always arrive, so the
   first batch carries it.
4. The reporter's own stage/gauge wins: an extra whose name is already present is skipped, so the
   peer-connection figures are never overwritten by the wc ones (they only fill what is missing).
5. One new POST path, `/page/error`, rather than a field on `/player`: the relay logs one line per
   field, and the host side then needs nothing beyond the log it already keeps.
6. The trap writes the overlay's `status` text and the document title only: it adds no pause, timer
   or socket, so a page error can't change what the player does.
7. `_isSupported` returns true when `VideoDecoder.isConfigSupported` is not a function (Safari
   builds without it): the decoder then reports a real decode error instead of a TypeError.

## Audit of the wc reporting/drawing path (item 2)

Checked and guarded:
- `canvas.getContext("2d", { desynchronized: true })` — wrapped in try/catch; a throw or a null
  answer falls back to `getContext("2d")`; both null → "the page has no 2D canvas" (a message, not a
  TypeError). Tested with a canvas that throws and one that returns null.
- Reading the canvas after `drawImage` of a `VideoFrame` (`getImageData`) — not on the wc
  reporting path any more: `stream_display` comes from the frame's own timestamps.
- `VideoDecoder.isConfigSupported` missing → see decision 7. `decode()`/`flush()` failures were
  already caught by the player's own error path.
- Socket data that is not binary: `_receive` counts it with `bytesOf` (string length or
  `byteLength`) and answers "the TV sent a message this page cannot read" instead of throwing.
- `performance.now()` — the only clock; present in plain http; injected into `WcStats` so tests
  need no timers. No `performance.memory`, `PerformanceObserver`, `timeOrigin` or `Date.now`.
- `structuredClone` — not used anywhere in `streaming/player/*.js` (grep). Objects are spread.
- Optional chaining on missing objects (`extras?.stages ?? []`, `event.error?.stack`,
  `pair?.currentRoundTripTime`) — every chain ends in a `null`/`[]` default and non-finite gauges are
  dropped, so a missing object costs a gauge, not the batch.
- secure-context-only APIs — the page uses no `crypto.*`, `navigator.clipboard`,
  `serviceWorker`, `Notification`, `localStorage`, `WebTransport`, `createImageBitmap` or
  `OffscreenCanvas` (grep); the only `navigator` use is `userAgent` in the report string.
- `requestVideoFrameCallback` — only used when `typeof … === "function"` (existing guard).
- Already guarded, so no change (and outside `allow:`): `marker_reader.js` and `latency_probe.js`
  both check for a null context and catch the crop/read, with a plain reason.

## Tests and values

`wc_stats_selftest.html` (16 checks) — samples `[receive, decodeOutput, drawn]`:
frame 8 `[0, 12, 14]`, 9 `[100, 116, 120]`, 10 `[200, null, null]` (unfinished), 11 `[300, 340, 350]`.
recv→decode `12, 16, 40` → median **16**; decode→draw `2, 4, 10` → median **4**;
`stream_decode` = mean(12, 16, 40) = 22.67 → **23**; `stream_display` = **4**.
Rate: 37500 bytes over 3000 ms → 37500·8 / 3 = **100 kbit/s**; the batch before it had no new
bytes → gauge omitted (`[null, 100]`).
Overlay line: `wc recv-dec 16 ms dec-draw 4 ms drop 3 backlog 3 age 60 ms keys 3 q 4 cfg hw dec ok`.
`combinedSeries(null)()` → `{stages: [], gauges: [], facts: []}`. Reporter-level check: a batch
with no peer connection and no marker holds the three host names.

`wc_selftest.html` (30 checks) — `bytesReceived` 77 + 37 + 16 = **130** (array buffer, view, string).
Missing classes give one overlay line and one report:
`this browser cannot play the video: no WebSocket`, `… no VideoDecoder, EncodedVideoChunk`.
Error trap: `page error: boom is not defined (wc_player.js:12)`, body
`{sessionId:"s1", message:"boom is not defined", site:"wc_player.js:12"}`; rejection
`page error: the socket is gone (wc_player.js:120)`; five reports then silence, and no throw with
the status line, the title and the send all throwing.

Runs (in `tp-stream`, files synced with `tools/wsl-sync.sh tp-stream`):
- `timeout 120 bash streaming/bench.sh --selftest` → 60/60, 24/24, **30/30**, **16/16**.
- `python3 -m py_compile serve.py relay_test.py`, `bash -n bench.sh`,
  `timeout 180 python3 streaming/player/relay_test.py` → `relay test: 38 checks passed`.
- Live relay: `serve.py --port 8792 …` + `curl -X POST …/page/error` → `{"ok": true}`, stderr
  `relay: page error: s1 wc_player.js:12 boom`.
- Real page over plain http in `chrome-headless-shell` (`index.html?player=wc`):
  `<div id="status">page error: Uncaught TypeError: GstWebRTCAPI is not a constructor
  (player.js:340)</div>` — the trap works end to end (and shows the non-wc path still throws when
  the lib is missing; see Hand-over).
- Tests first: before implementing, both pages stayed at `SELFTEST RUNNING` (no `error_trap.js`, no
  `wcHostNames`) — they failed for the right reason, then passed.

## Self-check (review-rules part A)

1. Every host setup: a viewer page, not a host; hosts, "Play on this phone", "Show on this device"
   and joined phones never load it. An older host 404s `/page/error`; `sendPageError` warns on a
   non-OK answer and the overlay line still shows (`wc_selftest.html`, `relay_test.py`).
2. When kept state starts and ends: `bytesReceived` starts at 0 per player and is never reset;
   `WcStats._batchAtMs`/`_bytesBefore` move only inside `batch()`, so the rate is the interval since
   the last batch and an idle socket yields no gauge; `FrameStages` keeps 256 samples and stops
   being written on `stop()` (`wc_stats_selftest.html`, `wc_selftest.html`).
3. Combining with other states: the trap only writes the overlay's status text and the title, adds
   no pause or timer, and the player's next status overwrites it; the marker failing now only loses
   the marker's own figures (tested: batch with no marker holds the three names).
4. Stay in the job's folder: writes only to `streaming/player/` files in `allow:` and this report's
   folder; `git status` shows only those (the `tv_test_app/*/generated_*` edits and the untracked
   `run-base` folders were there before this job and were not touched).
5. Stop rather than overstep: nothing blocked. Left alone: `marker_reader.js`/`latency_probe.js`
   canvas reads (outside `allow:`, already guarded) and the non-wc path's missing-lib throw below.

## Hand-over

What exists: `wc_counters.js` (counters, canvas, stage samples), `wc_stats.js` batch with
`wcHostNames`, `error_trap.js` installed first by `index.html`, `WcPlayer` missing-class check and
`bytesReceived`, `serve.py` `/page/error` → stderr, tests in `wc_selftest.html` (500 lines, at the
cap) and `wc_stats_selftest.html`.

Commands that worked:
- `tools/wsl-sync.sh tp-stream`, then in `tp-stream`:
  `timeout 120 bash streaming/bench.sh --selftest`; `timeout 180 python3 streaming/player/relay_test.py`;
  `python3 -m py_compile streaming/player/*.py`.
- Page in a browser: `python3 -m http.server 8794 --bind 127.0.0.1` in `streaming/player`, then
  `/opt/chrome-headless-shell/chrome-headless-shell-linux64/chrome-headless-shell --no-sandbox
  --disable-gpu --dump-dom "http://127.0.0.1:8794/index.html?player=wc"`.
- `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets`.

Don't redo: the marker does not need to make `stream_display` — the wc figures carry it. Don't add
a second error path: `/page/error` is the one. `wc_selftest.html` is at 500 lines: split it before
adding a check.
Open problems: `player.js:340` (`new GstWebRTCAPI`) throws when `lib/` is absent — only visible on a
page without the built lib (the entrypoint writes it), outside `allow:` and outside the wc path.

## Commit message

Player page: player=wc registers as a viewer and reports page errors

The `?player=wc` batch now always carries `bitrateReceivedKbps` (bytes on the `/tap` socket over the
interval) plus `stream_decode` and `stream_display` from the player's own frame timings, so a viewer
registers without the marker and on Safari where the canvas read fails. `wc_player.js` gets a
`bytesReceived` counter and, moved out first into `wc_counters.js` to stay under 380 lines, its
canvas and stage samples; a canvas that refuses the `desynchronized` context now falls back to the
plain one and a missing context is a message, not a throw. The new `error_trap.js`, loaded first,
shows `error` and `unhandledrejection` messages with file:line on the overlay and POSTs
`/page/error`, which `serve.py` relays to the session log (at most 5 per load, never throwing); a
browser with no `WebSocket`, `VideoDecoder` or `EncodedVideoChunk` is told so the same way.

## Status row

M15 opt2b-1 done: `player=wc` registers without the marker (wc figures, page error trap, missing
classes) — open: the non-wc path's `GstWebRTCAPI` throw on a page without `lib/`.

## Delete

- none
