job: M15 opt2b-1 (register): the wc page registers as a viewer without the marker and reports; every page error becomes visible
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2b/CONTEXT.md (whole, first) · streaming/player/player.js · wc_player.js · wc_stats.js · reporter.js · overlay.js · page_state.js · serve.py (POST paths) · marker_reader.js and canvasPicture in player.js (how the canvas is read) · wc_selftest.html · wc_stats_selftest.html · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question; safest choice, list each under "Decisions"; stop only if truly impossible ("Blocked").

Design:
1. Cause to prove with a test: with no peer connection the wc batch has no `bitrateReceivedKbps` and no `stream_decode`; `stream_display` comes only from the marker reader. So without the marker, or when the marker's canvas read fails on Safari, no viewer registers although the picture plays. Fix: the wc batch ALWAYS carries gauge `bitrateReceivedKbps` (bytes received on the /tap socket over the interval, kbit/s; add a `bytesReceived` counter to WcPlayer), stage `stream_decode` (mean decode ms per frame from stageSamples, once frames are decoded) and stage `stream_display` (decode-to-draw sample) without waiting for the marker. The first batch must not depend on marker success. Pure tests of the batch contents from fake counters in wc_stats_selftest.html / wc_selftest.html.
2. Audit everything on the wc reporting and drawing path for what throws or misbehaves on Safari or plain http (secure-context-only APIs, unguarded optional APIs, canvas getContext options such as `desynchronized`, reading a canvas after drawImage of a VideoFrame, structuredClone, performance.* variants, optional chaining on missing objects) and guard it. List what you checked.
3. New module streaming/player/error_trap.js, loaded FIRST by index.html: `window` error and unhandledrejection handlers show the message with file:line on the overlay status line AND send it to the host: use an existing allowed POST path (e.g. the /player state report with a field `error`) or add one path to serve.py's allow-list and relay it to the session log; if the host side needs more than serve.py, print it to the relay's stderr (kept by the container log) and say so. At most 5 reports per page load; the trap itself never throws. Page test: fire synthetic error and rejection events; assert overlay text and the POST body.
4. WcPlayer.start: if `VideoDecoder`, `EncodedVideoChunk` or `WebSocket` is missing, show an overlay line naming what is missing and report it the same way. Test with fakes.
wc_player.js is at 380 lines: move code out first (for example a wc_counters.js) before adding anything.

in the report: `## Summary` first (see CONTEXT.md), `## Hand-over` last.
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: as CONTEXT.md; no lib file over 380 lines; tests first
allow: streaming/player/player.js · streaming/player/wc_player.js · streaming/player/wc_counters.js · streaming/player/wc_stats.js · streaming/player/reporter.js · streaming/player/overlay.js · streaming/player/page_state.js · streaming/player/error_trap.js · streaming/player/index.html · streaming/player/serve.py · streaming/player/relay_test.py · streaming/player/wc_selftest.html · streaming/player/wc_stats_selftest.html · streaming/bench.sh · docs/briefs/m15/opt2b/f1-register-report.md · docs/briefs/m15/opt2b/f1-register
check: format
report: docs/briefs/m15/opt2b/f1-register-report.md
