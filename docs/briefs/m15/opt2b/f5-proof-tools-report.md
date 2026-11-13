# opt2b-5: proof tools — report

## Summary

Built the two proof tools the batch needed. `streaming/bench.sh` has
`--viewer-host ADDR` (the headless Chrome loads `http://ADDR:<player port>/` instead of
127.0.0.1) and `--viewer-insecure-ok` (adds `--unsafely-treat-insecure-origin-as-secure`
for that origin, the stand-in for Safari's VideoDecoder on plain http). Both default off, so
a run without them is byte for byte today's. The run logs which page and origin it used;
`--viewer-insecure-ok` alone and `--viewer-host` with `--viewer external` are refused (2),
a non-IPv4 address is a failure (1). The session containers need no publish change: they
run with `--network host`, so the player port already answers on every interface — proved,
not assumed (the LAN run below reached the page over eth0). New page test
`streaming/player/secure_selftest.html` (8 checks, added to `run_page_selftest`): it
replaces `crypto.subtle`, `crypto.randomUUID`, `navigator.clipboard`, `mediaDevices`,
`serviceWorker`, `storage` and `Notification` with getters that record and throw, then
drives WcPlayer through start, keyframe+draw, decoder error+reconnect, stats/counters and
stop, and fails if any getter was read; a last check reads every `wc_*.js` source and fails
on `randomUUID`, `crypto.subtle`, `clipboard`, `mediaDevices`, `serviceWorker`.

Tests: `bash streaming/bench.sh --selftest` in tp-stream gives PASS 60/60, 24/24, 30/30,
16/16 and the new 8/8. Tests first: with `globalThis.crypto.randomUUID()` added to the
distro's copy of `wc_player.js` the page gave `SELFTEST FAIL 6/8`, naming the touch
(`start() ...: threw randomUUID is not on this page`) and the source scan
(`wc_player.js: randomUUID`); the copy was restored and the repository's file was never
edited. The same page passes 8/8 loaded over `http://192.168.1.124:<port>/` with and
without the flag, so the guards work on a real plain-http LAN origin.

Root cause of the batch's problem (proved): a plain-http LAN page in Chrome has no
`VideoDecoder`; the custom player must never need the other six secure-context APIs, which
is what the new test now pins down.

Not proved with the wc page itself: `--player-query "marker=1&player=wc"` never reaches
`playing` in the headless Chrome with today's image, on loopback exactly as on the LAN
(`state: "streaming"` after 60 s), so the wc path cannot yet be the realistic LAN proof.
The WebRTC path on the same switches plays and measures: 8621 kbit/s received against the
10000 ceiling, 1 viewer browser/chrome-headless. Suspected, not proved: the tap's
avc1.F4002A (High 4:4:4) profile, the opt2-1 finding, which this image still sends.

Turns: about 38. Obstacles: Chrome's `--dump-dom` dumps before an async page finishes (see
Decisions 3); `/work/stream-bench/{lanproof,loopproof,lanwebrtc}` are left in the distro,
no scratch file in the repository.

## Decisions

1. `--viewer-insecure-ok` without `--viewer-host` is refused (exit 2): the loopback page is
   a secure origin already, so the switch there would be read and do nothing (the
   `--viewer-cpus` precedent).
2. `--viewer-host` with `--viewer external` is refused (exit 2): only the Chrome this
   script starts can be pointed at an address; a person's device opens what `print_viewer_url`
   prints. (Suggestion in Questions 2.)
3. The new page loads its modules with static imports and reads the sources with a
   synchronous XHR. The first version used `await import()` and `fetch()`, which finished
   after Chrome's `--dump-dom` (the runner read `SELFTEST RUNNING`; with
   `--virtual-time-budget=5000` it read PASS 9/9). A page test must be done before load.
   The cost is that module-load-time is not guarded dynamically; the source scan covers a
   name used at load.
4. `wc_decoder.js` does not exist, so the page does not import it (statically importing a
   missing module would break the page); the source scan still looks for it and treats a
   missing one as no failure, as the brief allows.
5. The guards block on the object and then on its prototype, and a member that cannot be
   blocked fails a check, so the page can never pass by blocking nothing.
6. No docker publish change: `start_session` already runs `--network host`, and the LAN run
   below loaded the page at 192.168.1.124:45782 through the session's own relay.
7. The two new switches are documented in the header comment, in `usage` and in
   `streaming/README.md` next to `--viewer external`.

## Tests and values

- `bash -n streaming/bench.sh`: 0.
- `bash streaming/bench.sh --selftest` (tp-stream): marker 60/60, jbtarget 24/24, wc 30/30,
  wc_stats 16/16, secure 8/8.
- Failure proof: distro copy of `wc_player.js` with `globalThis.crypto.randomUUID();` as the
  first line of `start()`: `SELFTEST FAIL 6/8`, with
  `start() opens the tap socket without a secure-context API: threw randomUUID is not on this page`,
  `the stats ... use none: expected [[],...], got [["randomUUID"],...]` and
  `no custom-player source names a secure-context API: expected [], got ["wc_player.js: randomUUID"]`.
  Restored; `grep -c randomUUID wc_player.js` = 0 afterwards.
- Same page over `http://192.168.1.124:45984/secure_selftest.html` (python3 on 0.0.0.0):
  PASS 8/8 without the flag, PASS 8/8 with `--unsafely-treat-insecure-origin-as-secure=...`.
- Argument checks (exit code, measured with python3 `subprocess.run`): `--viewer-insecure-ok`
  → 2, `--viewer-host 999.1.1` → 1, `--viewer-host 192.168.1.124 --viewer external` → 2,
  `--viewer-host 192.168.1.124 --seconds 1` → 1 (`--seconds is 5 or more`, unchanged).
- LAN proof, WebRTC path (worked):
  `bash streaming/bench.sh --label lanwebrtc --seconds 20 --player-query marker=1 --viewer-host 192.168.1.124 --viewer-insecure-ok`
  → log `lanwebrtc0: viewer opens http://192.168.1.124:45782 (plain http, origin treated as secure)`,
  `1 viewer(s) browser/chrome-headless, 8621 kbit/s received against the 10000 kbit/s ceiling`.
- wc path, LAN (started, log line right, then failed):
  `bash streaming/bench.sh --label lanproof --seconds 30 --player-query "marker=1&player=wc" --viewer-host 192.168.1.124 --viewer-insecure-ok`
  and the same on loopback (`--label loopproof`, without the two switches, log
  `loopback, a secure origin already`): both `session 0 never played: ... "state": "streaming"`.
- `tools/check.sh format`: PASS.

## Self-check (docs/review-rules.md part A, items 1-5)

1. Every host setup: not affected — a shell script inside the distro and a page test; no
   Flutter host, no phone flow. The change is off by default, so a TV or PC host, "Play on
   this phone", "Show on this device" and a joined phone behave as before. Test: `--selftest`.
2. Kept state starts and ends: the new page's guards live for the page, which ends after the
   result line; the secure-origin flag lives only on one Chrome command line; nothing is
   kept outside `<out>`. Test: `stop() leaves nothing running and uses none`.
3. How a new state combines: the two switches only combine with `--viewer chrome`; alone and
   with `--viewer external` they are refused, so no other pair changes. Test: the four
   exit-code runs above.
4. Stay in the job's folder: only `streaming/bench.sh`, `streaming/README.md`,
   `streaming/player/secure_selftest.html` (new) and this report changed.
5. Stop rather than overstep: nothing outside `allow:` was needed; the wc path's failure is
   reported, not worked around.

## Questions

1. Should the wc page never reaching `playing` in headless Chrome (same on loopback) be its
   own job? If the tap is still 4:4:4, the headless wc proof cannot exist; if it is something
   else, the page's state machine needs a diagnostic line.
2. Is refusing `--viewer-host` with `--viewer external` right? The alternative is to let it
   replace the address `print_viewer_url` prints.
3. Should the source scan's list grow with `Notification` and `getRandomValues`? The brief
   names five substrings and the page blocks all seven APIs dynamically, so it is left as
   written; `crypto.getRandomValues` works on plain http and would be a false hit.

## Hand-over

What exists: `--viewer-host ADDR` and `--viewer-insecure-ok` on `streaming/bench.sh` (header,
usage, README, `check_viewer_host`, `viewer_url`, `secure_origin_flag`, `viewer_origin_text`,
`start_viewer`), and `streaming/player/secure_selftest.html` in `run_page_selftest`.

Commands that worked inside tp-stream (sync with `tools/wsl-sync.sh tp-stream`, work in
`/work/flash-20261113-125758-53608`):

```
timeout 150 bash streaming/bench.sh --selftest
timeout 420 bash streaming/bench.sh --label lanwebrtc --seconds 20 --player-query marker=1 \
  --viewer-host 192.168.1.124 --viewer-insecure-ok        # LAN page, WebRTC path, measured
timeout 420 bash streaming/bench.sh --label lanproof --seconds 30 \
  --player-query "marker=1&player=wc" --viewer-host 192.168.1.124 --viewer-insecure-ok
```

Don't redo: the page's async version (it reads as RUNNING); the publish question (`--network
host` already answers on the LAN). Open: the wc path not playing in headless Chrome, which is
what the realistic Safari-style proof needs.

## Commit message

bench: prove the player on a plain-http LAN address

`--viewer-host ADDR` has the headless Chrome load the page on a LAN address
instead of 127.0.0.1, and `--viewer-insecure-ok` gives that origin Chrome's
secure-origin switch, the stand-in for Safari's VideoDecoder on plain http.
Both default off, and the run logs which page and origin it used; the session
needs no publish change (`--network host`). New page test
`secure_selftest.html` blocks the seven secure-context APIs with recording
throw-getters, drives WcPlayer start, frame, error and stats paths, and scans
every `wc_*.js` source for their names.

## Status row

opt2b-5 done: `--viewer-host`/`--viewer-insecure-ok` proved on the LAN (WebRTC path) and
`secure_selftest.html` in `--selftest` (8/8); open: the wc page never reaches `playing` in
headless Chrome with today's image, on loopback too.

## Delete

- none
