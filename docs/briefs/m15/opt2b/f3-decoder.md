job: M15 opt2b-3 (decoder): a decoder error closes, rebuilds, asks for a keyframe and carries on; errors are counted and reported
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2b/CONTEXT.md (whole, first) · docs/briefs/m15/opt2b/f1-register-report.md (Summary, Hand-over) · streaming/player/wc_player.js · wc_counters.js (if f1 made it) · wc_annexb.js · wc_stats.js · player.js (wcEvent, wcDrawn) · overlay.js · wc_selftest.html · packages/metrics/lib/src/report_stream_wc.dart and its test · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question; safest choice, list each under "Decisions"; stop only if truly impossible ("Blocked").

Design:
1. Tests first (fake VideoDecoder): an error callback with a DOMException-like error (name, message) closes the decoder, creates a NEW decoder, waits for the next keyframe (delta frames dropped meanwhile, one key request per 500 ms), reconfigures and decodes; a decoder that errors again within the same keyframe cycle does not loop faster than one rebuild per 500 ms; after 5 rebuilds in 10 s the player keeps trying but at most once per second and shows the message. `decoder.configure` throwing and `isConfigSupported` rejecting count as errors the same way.
2. On error the page shows "decoder error, restarting" (not "stopped"); once a frame is drawn after a rebuild (or the first frame at all) the message is cleared (the page's status line returns to normal). A drawn frame clears a stale decoder message at any time.
3. Counters: decoderErrors, decoderRebuilds, lastDecoderError (text `name: message`, cut to 60 chars, only characters the host's fact rule allows: letters, digits, space , . _ ( ) + -; see factPattern in wc_stats.js). Send them as counters/gauges (`wcDecoderErrors`, `wcDecoderRebuilds`) and the error text as a second fact `wcerr` (24 chars max after the host's rule; put the name first, e.g. `EncodingError`; keep it short) in the batch.
4. Dart report: `report_stream_wc.dart` shows decoder errors, rebuilds and the error text in the "Custom player (wc)" table (add rows; test first).
5. Likely Safari cause to handle: Safari rejects or fails on a codec string that does not match the SPS. Check `codecString(sps)` against the SPS bytes (profile_idc, constraint flags, level_idc) and avcC description. If isConfigSupported says no for `avc1.F4...` (4:4:4, profile_idc 244/110/122/44), do NOT try to decode: show "the host sends 4:4:4; Safari cannot decode it" on the overlay, send the fact, request nothing in a loop. Otherwise try the configs in order: given string with hardware hint, without hint. Also: never feed a delta frame first; the first decode after configure is a keyframe (assert in a test). Record the configured codec string in the fact (cfg word) as today.
6. Keep wc_player.js at most 380 lines (move the decoder handling into a new wc_decoder.js if needed).

in the report: `## Summary` first (see CONTEXT.md), `## Hand-over` last.
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: as CONTEXT.md; tests first. Dart: `dart format` clean; run the metrics package test for the files you touch with `dart test packages/metrics/test/report_stream_wc_test.dart` (or flutter test if that is what the package uses).
allow: streaming/player/wc_player.js · streaming/player/wc_decoder.js · streaming/player/wc_counters.js · streaming/player/wc_annexb.js · streaming/player/wc_stats.js · streaming/player/player.js · streaming/player/overlay.js · streaming/player/wc_selftest.html · streaming/player/wc_stats_selftest.html · packages/metrics/lib/src/report_stream_wc.dart · packages/metrics/test/report_stream_wc_test.dart · docs/briefs/m15/opt2b/f3-decoder-report.md · docs/briefs/m15/opt2b/f3-decoder
check: format
report: docs/briefs/m15/opt2b/f3-decoder-report.md
