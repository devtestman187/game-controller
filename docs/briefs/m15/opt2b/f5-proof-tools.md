job: M15 opt2b-5 (proof tools): bench can load the page over plain http on a LAN address; a page test fails when the wc path touches a secure-context-only API
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2b/CONTEXT.md (whole, first) · streaming/bench.sh (usage, the Chrome start near line 383, relay_url/player_of, run_page_selftest, option parsing) · streaming/player/wc_selftest.html (style) · streaming/player/index.html · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question; safest choice, list each under "Decisions"; stop only if truly impossible ("Blocked").

Design:
1. bench.sh gets `--viewer-host ADDR` (default empty = today's 127.0.0.1, behaviour unchanged): with `--viewer chrome` the headless Chrome opens `http://ADDR:<player port>/...` instead of 127.0.0.1, and adds `--unsafely-treat-insecure-origin-as-secure=http://ADDR:<port>` ONLY when `--viewer-insecure-ok` is also given (Chrome lacks VideoDecoder on plain http otherwise; the flag is the stand-in for Safari, which offers it). The bench log says which was used. Check that the session's player port is reachable on ADDR (the containers publish on all interfaces or on 127.0.0.1 only? read the docker run arguments in the script; if it publishes only on 127.0.0.1, add the minimal publish change only when --viewer-host is given and say so). Without a real LAN address in the distro the proof uses the distro's eth0 address; the script validates that ADDR is an IPv4 address (digits and dots).
2. Usage text and README line (streaming/README.md is allowed) for both options. `bash -n` passes.
3. New page test streaming/player/secure_selftest.html (same "SELFTEST PASS n/m" style, added to run_page_selftest): loads the wc modules (wc_player.js, wc_annexb.js, wc_stats.js, wc_counters.js/wc_decoder.js if they exist, error_trap.js if it exists), and runs WcPlayer with fakes while the page deletes/blocks (via Object.defineProperty getters that throw and record) crypto.subtle, crypto.randomUUID, navigator.clipboard, navigator.mediaDevices, Notification, navigator.serviceWorker, navigator.storage; the test fails if any getter was touched on start, frame, error and stats paths. Also a static case: fetch the source text of every wc_*.js and fail on the substrings `randomUUID`, `crypto.subtle`, `clipboard`, `mediaDevices`, `serviceWorker`. Tests first: prove it fails by adding one such call temporarily and removing it (say so in the report; leave none behind).
4. Run `timeout 120 bash streaming/bench.sh --selftest` in the distro: every page test PASS.

in the report: `## Summary` first (see CONTEXT.md), `## Hand-over` last (include the exact bench command lines for the realistic proof).
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: as CONTEXT.md; tests first; bench.sh must stay at most 380 lines per touched function rule: bench.sh is already long (965 lines): that is accepted for this file only, keep your additions in functions under 60 lines.
allow: streaming/bench.sh · streaming/README.md · streaming/player/secure_selftest.html · docs/briefs/m15/opt2b/f5-proof-tools-report.md · docs/briefs/m15/opt2b/f5-proof-tools
check: format
report: docs/briefs/m15/opt2b/f5-proof-tools-report.md
