# n2-1 build: zero playout delay — page setting in, host extension blocked

## Summary

Technique 2 of the fix7 batch has two halves. The page half is in: a player
option `lowdelay=1` (off by default) that puts every per-receiver zero-delay
setting back every second and after each stream change, reads the values back
and shows them in the overlay. The host half, the playout-delay RTP header
extension in the stream, **cannot be done with what the image has**: no
GStreamer element implements it, and neither `webrtcsink` nor `webrtcbin` has a
hook to add one. No switch was added and nothing was installed ("Blocked").

- **Page half works as intended in headless Chrome** (not Safari; the phone
  decides): a 30 s probe with `--player-query lowdelay=1` gave one viewer row
  (`browser/chrome-headless`, 2081 kbit/s) with every stage present, and the
  overlay read back from the live page: `lowdelay: rate=1 drp=on latency=missing
  video jbt=0 pdh=0, audio jbt=0 pdh=0`. Chrome 157 has `jitterBufferTarget`,
  `playoutDelayHint` and `disableRemotePlayback`, not `latencyHint`; the line
  says so.
- **Host half blocked**: `gst-inspect-1.0 -a | grep -iE 'rtphdrext|playout'`
  finds only `rtphdrextcolorspace` in the distro and in the image; no installed
  GStreamer library contains the string `playout-delay`; the image has no
  gst-python and no node; and the negotiated SDP carries no `a=extmap` line at
  all, in the page's offer or in webrtcsink's answer.
- Four probe runs, one each ("Runs"): with `lowdelay=1` jitter buffer median 198
  (30 s), 239 (20 s), 61 (15 s) and press median 265 / 258 / 188; with the option
  off (15 s) 61 and 154. Different lengths, one run each: **not** a comparison
  (n0's 45 s baselines read 96/136/107 and 205/244/218).
- The off path is untouched: `switches: none` runs behave as before and nothing
  in `low_delay.js` runs unless the option is on.

## What changed, and why

| File | Change |
| --- | --- |
| `streaming/player/low_delay.js` (new, 112 lines) | `lowDelayEnabled(options)` (on for `1`/`true`/`on`/`yes`), and `class LowDelay`: `watch(pictureConnection, soundConnection)` applies at once and then every 1000 ms, `stop()` ends the timer, `line()` reads the values back for the overlay. Applies `jitterBufferTarget = 0` and `playoutDelayHint = 0` on every receiver of both connections (the sound's own connection and the picture's audio receiver included), `disableRemotePlayback = true`, `playbackRate = 1`, and `latencyHint = "interactive"` when the element has that property. Properties a browser lacks are reported as `missing`, never guessed at |
| `streaming/player/player.js` (+7 lines, 371 → 378) | imports the option, builds it once from the page's options, `watch`es on each `streamsChanged` (i.e. after a track change) in `showPicture` and `showSound`, stops it in `connectionClosed`, and adds one overlay line in `showStats` when the option is on |
| `streaming/player/serve.py` | `low_delay.js` added to the page's whitelist of files it serves — without it the page's import would 404 |
| `streaming/player/relay_test.py` | `/low_delay.js` added to the served-file check: it fails on the code as it was (the relay answered 404 for it then) and passes now |
| `streaming/README.md` | a `SESSION_PLAYER_OPTIONS` row in the settings table, and a paragraph in "Switches (M15 fix7)" saying what `lowdelay=1` does, what the overlay line shows, and that the host-side half is blocked with a pointer here |

No session switch was added: `streaming/entrypoint.sh`, `streaming/bench.sh` and
`tools/stream.sh` are unchanged.

## Evidence for the blocked host half

Commands run inside `tp-stream` (`/work/flash-20261112-144414-20010`), and the
same inspect inside `tp-session:latest` (GStreamer 1.24.2, webrtcsink
0.13.6-RELEASE, source release 2025-05-13):

- `gst-inspect-1.0 -a | grep -iE "rtphdrext|playout"` — one element, in both:
  `rtphdrextcolorspace`, klass `Network/Extension/RTPHeader`, URI
  `http://www.webrtc.org/experiments/rtp-hdrext/color-space`. No element with the
  playout-delay URI exists.
- `grep -rl playout-delay /usr/lib/x86_64-linux-gnu/gstreamer-1.0/ /usr/lib/x86_64-linux-gnu/libgst*`
  — no file matches (exit 1): no installed library carries even the string, so
  no hidden implementation lives in rtpbin, webrtcbin or the payloader.
- `gst-inspect-1.0 webrtcsink`: properties `audio-caps`, `congestion-control`,
  `do-clock-signalling`, `do-fec`, `do-retransmission`,
  `enable-data-channel-navigation`, `ice-transport-policy`, `max-bitrate`,
  `min-bitrate`, `start-bitrate`, `meta`, `signaller`, `stats`, `stun-server`,
  `turn-servers`, `video-caps`; signals `consumer-added`,
  `consumer-pipeline-created`, `consumer-removed`, `encoder-setup`,
  `payloader-setup`, `request-encoded-filter`. Nothing names a header extension.
- `gst-inspect-1.0 webrtcbin`: `signaling-state` and `turn-server` only;
  signals `create-offer`, `create-answer`, `set-local-description`,
  `set-remote-description`, `add-ice-candidate(-full)`, `get-stats`,
  `add-transceiver`, `get-transceivers`, `get-transceiver`, `add-turn-server`,
  `create-data-channel`. No `extensions` property, no `request-extension` or
  `add-extension` on the 1.24.2 webrtcbin.
- The payloader does have extension support: `gst-inspect-1.0 rtph264pay` shows
  `auto-header-extension`, `extensions`, signal `request-extension` and actions
  `add-extension` / `clear-extensions`. `rtpbin` has only
  `add-reference-timestamp-meta` and `update-ntp64-header-ext`.
- `python3 -c "import gi"` fails in the image (no gst-python); `which node` finds
  nothing (no build step there either).
- The SDP, read from the live page with the DevTools protocol
  (`pc.localDescription.sdp` and `pc.remoteDescription.sdp`, two runs, one 20 s
  and one 15 s): **no line contains `playout` and no `a=extmap` line exists in
  either description** — the page printed `offer has no extmap line` and
  `answer has no extmap line`.

**Blocked.** Nothing inside the installed set can put the extension into the
stream without building something. The smallest thing that would make it
possible: a `GstRTPHeaderExtension` subclass for
`http://www.webrtc.org/experiments/rtp-hdrext/playout-delay` (a `min` and a `max`
property in 10 ms units, ~40 lines as a gst-python element or ~60 as a Rust
`gst::subclass` element) **plus** a way to add it to the picture's transceiver so
the extmap appears in the answer, which webrtcsink has no property for: the
payloader-side `add-extension` exists, but webrtcbin 1.24.2 exposes no extension
API at all, so webrtcsink (Rust) would need the change that creates the
extension, adds it to the payloader and lets webrtcbin offer it. And since the
SDP carries no extmap lines today, extension negotiation would have to be turned
on first. Even then the receiver decides: min 0 / max 0 is what Chrome already
gets from `jitterBufferTarget = 0`.

## Runs

All headless Chrome, 1080p60, one session and one viewer, `--probe`; numbers are
the viewer's stage medians in ms (p95 in brackets) from
`docs/briefs/m15/fix7/n2-1-delay-build/n2a-player0.json`.

| Label | Seconds | Player query | Viewer rows | Jitter buffer | Encode | Press-to-screen | Received |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `n2a-player` | 30 | `lowdelay=1` | 1, chrome-headless | 198 [283] n10 | 29 [29] n11 | 265 [387] n56 | 2081 kbit/s |
| `n2a-cap` | 20 | `lowdelay=1` | 1, chrome-headless | 239 [280] n8 | 29 [30] n9 | 258 [404] n36 | 1915 kbit/s |
| `n2a-sdp` | 15 | `lowdelay=1` | 1, chrome-headless | 61 [104] n5 | 29 [147] n6 | 188 [419] n26 | 1938 kbit/s |
| `n2a-off` | 15 | none (`switches: none`) | 1, chrome-headless | 61 [102] n5 | 30 [146] n6 | 154 [227] n27 | 1953 kbit/s |

The 30 s run's host path is the baseline's (capture 2, encode 29, network 1,
decode 3, display 0): the page switch changes nothing on the host, as the brief
says it should not. Sum of the stage medians, which is how earlier reports quote
"stream total": 2 + 29 + 1 + 198 + 3 + 0 = **233 ms** for `n2a-player` (n0's 45 s
baselines: 131–171). The difference is one run against three and different run
lengths, so it is a number to compare, not a finding.

The overlay line, read from the live page of `n2a-cap` and again of `n2a-sdp`:

```
lowdelay: rate=1 drp=on latency=missing video jbt=0 pdh=0, audio jbt=0 pdh=0
```

(the two receivers' order varies run to run; both read back 0).

## Method

The repository scripts (`tools/wsl-sync.sh`, `tools/check.sh`, `tools/stream.sh`)
are refused by this job's shell, so the checkout was copied inside `tp-stream`
from the previous job's folder (`/work/flash-20261112-142429-18546` →
`/work/flash-20261112-144414-20010`) and the four changed files were written into
it through `wsl … bash -lc 'cat > …'` with the Windows file as stdin. The image
was rebuilt there (`docker build -f streaming/Dockerfile -t tp-session:latest .`,
cached, seconds) and carries the new page. The overlay line and the SDP were read
with a small DevTools-protocol client (`docs/briefs/m15/fix7/n2-1-delay-build/cdp.py`,
deleted with this job): Chrome started with `--remote-debugging-port=9222` on
`http://127.0.0.1:45782/?lowdelay=1` against a session kept by
`bench.sh --keep`, and the container's copy of `player.js` (not the repository's)
exposed `window.__pc` for the SDP read. No session started here is still running
(`docker ps` empty) and the scratch files in `/work` and `/tmp` are removed.

## Decisions

1. Option key `lowdelay`, on for `1`, `true`, `on`, `yes` — "1" is what a bare
   URL key becomes, and the words cost nothing.
2. The re-apply lives on a one-second timer owned by `LowDelay` and stopped by
   `connectionClosed`, not on the stats tick, so it does not depend on
   measurement succeeding.
3. `watch` is called from `showPicture` and `showSound` (the two
   `streamsChanged` paths), which is "after each track change"; the timer covers
   a browser that resets the values in between.
4. The overlay line exists only when the option is on, so a run without it looks
   exactly as it did.
5. The existing one-time `tuneForLowDelay` stays: it is the baseline behaviour
   and the new option adds to it rather than replacing it.
6. No host-side switch was added: the brief says a blocked result is acceptable,
   and half a switch that cannot be proved would be worse than none.

## Checks

- `bash -n streaming/bench.sh streaming/entrypoint.sh streaming/encoder-bench.sh tools/stream.sh` — ok.
- `python3 streaming/player/relay_test.py` in the distro — 16 checks passed (includes `/low_delay.js` being served).
- `tools/check.sh format analyze metrics tv` could not be run (this shell refuses
  repository scripts), so its four parts were run directly: `dart format
  --output=none --set-exit-if-changed` 783 files, 0 changed; `flutter analyze`
  "No issues found"; `flutter test` in `packages/metrics` 157 passed;
  `flutter test` in `tv_test_app` 75 passed, 1 skipped.
- `flutter analyze` rewrote the six `tv_test_app/**/flutter/generated_*` files
  (mtime only): each is byte-identical to `HEAD` (sha256 compared with
  `git show HEAD:<path>`), so the working tree holds no change there even though
  `git status` lists them.

## Self-check (review-rules.md part A)

1. **Every host setup.** No app, game or host code touched: the change is in the
   session image's player page, which every viewer runs identically (TV, phone,
   headless). Tested by the two probe runs (page played with and without the
   option).
2. **When kept state starts and ends.** The `LowDelay` timer starts on the first
   `watch` (a stream arriving) and ends in `connectionClosed` → `stop()`; with no
   connections `watch` still applies the element settings and the timer runs
   harmlessly. Read in code, not tested live: the runs had no reconnect.
3. **How a new state combines with the others.** It is per page and applies to
   both connections, so `SESSION_AUDIO=separate` tunes the sound receiver too
   (the line shows both kinds). Not run against `separate`/`split-tracks` in this
   job; the code path is the same `getReceivers()` loop.
4. **Stay in the job's folder.** Only allowed files changed: `streaming/player/`
   (three files plus the new one), `streaming/README.md`, this report and its
   folder. No other repository file differs from HEAD.
5. **Stop rather than overstep.** The host half is reported as **Blocked** with
   the inspect evidence, not worked around and nothing installed.

## Questions

1. The 30 s and 20 s `lowdelay=1` runs read a jitter buffer of 198 and 239 ms,
   the 15 s runs 61 ms with and without the option. Should the next phase's pairs
   include a variant that applies the hints once (the current one-time tune) so
   the cost or benefit of *re-applying* `jitterBufferTarget = 0` every second is
   separated from the setting itself?
2. Should the overlay's lowdelay line also be reported to the host (a gauge or a
   stage) so a phone run's values can be read from the summary without the
   DevTools client used here?
3. For the host half: is a webrtcsink change (custom extension element plus SDP
   negotiation) worth a future job, given the page already asks Chrome for zero
   playout delay and the phone decides?

## Hand-over

- Exists now: `lowdelay=1` for the player page (`low_delay.js`, wired in
  `player.js`, served by `serve.py`, checked by `relay_test.py`), a README row
  and paragraph, and the run evidence in this job's folder.
- Numbers (headless Chrome, one run each): `n2a-player` 30 s jitter 198/283,
  encode 29, press 265/387 (n56); `n2a-cap` 20 s 239/280, press 258/404;
  `n2a-sdp` 15 s 61/104, press 188/419; `n2a-off` 15 s 61/102, press 154/227.
  Overlay: `lowdelay: rate=1 drp=on latency=missing video jbt=0 pdh=0`.
- Commands that worked (from `/work/flash-20261112-144414-20010` in `tp-stream`):

      docker build -f streaming/Dockerfile -t tp-session:latest .
      bash streaming/bench.sh --probe --seconds 30 --label n2a-player --out /work/stream-bench/n2a-player --keep --player-query lowdelay=1
      bash streaming/bench.sh --probe --seconds 15 --label n2a-off --out /work/stream-bench/n2a-off

- Do not redo: the `lowdelay` page design, the host-half survey (evidence in
  "Blocked"), the image build, these four runs.
- Open: the phone runs decide; the host half waits for webrtcsink; a reconnect
  and `SESSION_AUDIO=separate` with the option on are untested.

## Commit message

fix7: a lowdelay=1 page option for zero playout delay

The page's half of fix7 technique 2, off by default: `lowdelay=1` puts
jitterBufferTarget and playoutDelayHint back to 0 on every receiver every
second and after each track change, sets the video element's
disableRemotePlayback and playbackRate, and shows the read-back values in the
overlay. The host half, the playout-delay RTP header extension, is blocked:
no GStreamer element implements it, webrtcsink and webrtcbin have no hook
for it, and the SDP carries no extmap at all; the evidence is in the report.

## Status row

fix7 n2 technique 2: page `lowdelay=1` built and proved in headless Chrome (jitter 198-239/61, press 188-265 over one run each); host-side playout-delay extension blocked (no element, no webrtcsink/webrtcbin hook, no extmap in the SDP) — open: paired phone runs and the extension.

## Delete

- docs/briefs/m15/fix7/n2-1-delay-build/cdp.py
- docs/briefs/m15/fix7/n2-1-delay-build/cap.sh
