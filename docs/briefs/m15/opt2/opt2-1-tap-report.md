# opt2-1 host tap: report

## Summary

With `SESSION_TAP=on` the session pipeline runs in the session's own Python
process (`streaming/tap/tap_runner.py`, `Gst.parse_launchv` of the same words)
and reads the encoded access units from an `appsink` behind a `tee` right after
the encoder; opt2-2's WebSocket server plugs into `TapRunner.add_frame_callback`.
The switch defaults off; a bad value warns and runs `gst-launch` as before.

New: `tap_frames.py` (pure helpers: header, Annex B split, keyframe, SPS/PPS,
codec string, size), `tap_runner.py` (frame callbacks, `info()`,
`request_key_unit()`, loop, `-e` EOS, errors to stderr), 17 tests with
`testdata/sample_h264.bin` (9,296 B) and json, `entrypoint_pipeline_test.sh`,
the switch, `tap_port` and `--print-pipeline` in `entrypoint.sh`, and the
Dockerfile's python3-gi lines with `COPY streaming/tap/`.
Tests: `tap_frames_test.py` 17 OK; `entrypoint_pipeline_test.sh` ok (off =
today's 43 words word for word, on = `python3 …/tap_runner.py --port 8788 --`
+ the tap words); `tools/check.sh format` PASS.
Numbers (tp-stream, NVENC, 1080p60, GOP 60): 60.0 fps, 300 frames in 5 s;
`avc1.F4002A` 1920x1080, SPS/PPS on every IDR, no B-frames; AUD first in every
unit; IDR 27,093–40,584 B, P min 2,520 / median 8,689 / max 36,090 B; an IDR
the next frame after a request (97 → 98, ≈17 ms); no added delay (38 → 39 µs).
Decision that matters: the brief's byte-stream caps word stalls this pipeline
at PAUSED, so the branch has no caps filter and the runner converts AVC to
Annex B (Decisions). Not done: no real capture or webrtcsink branch
(`waylanddisplaysrc` will not load in the distro), image not built as asked.

## Files changed

- `streaming/tap/tap_frames.py` (new): `pack_header`, `split_nalus`,
  `is_keyframe`, `has_sps_and_pps`, `extract_sps_pps`, `profile_string`,
  `frame_size`, plus `avc_to_annexb` for the conversion above; no GStreamer.
- `streaming/tap/tap_runner.py` (new): the in-process pipeline.
- `streaming/tap/tap_frames_test.py` (new): 17 unittest cases over the sample
  and over hand-built buffers.
- `streaming/tap/testdata/sample_h264.bin` (new, 9,296 B,
  sha256 `3478389836b605a70b4af8275ea995c7a79286b6e8c8d10efb498f2b59b0ae22`) and
  `sample_h264.json` (profile, size, the four frames' offsets and lengths).
- `streaming/tap/entrypoint_pipeline_test.sh` (new): what the entrypoint would
  run, word by word, tap off and on.
- `streaming/entrypoint.sh`: `SESSION_TAP` (default off), `tap_port` =
  `${TAP_PORT:-$((automation_port + 1))}`, `build_pipeline` split into
  `capture_words` / `webrtc_branch` / `tap_branch` / `pipeline_words` /
  `pipeline_command`, the tap branch after a `tee name=t`, the ready line's
  ` tap=on:<port>` note, the two validation warnings, and `--print-pipeline`.
- `streaming/Dockerfile`: `python3-gi gir1.2-gstreamer-1.0
  gir1.2-gst-plugins-base-1.0` in the apt group and `COPY streaming/tap/
  /usr/local/bin/tap/`.

## Tests and results

`python3 streaming/tap/tap_frames_test.py` (in the distro, as the brief asks):

- header: 24 bytes, `>BBBBIQQ`, the flags bits, the reserved byte zero;
- split: the sample's start codes, a unit without a start code, and each of the
  sample's four frames splitting into the units the json records;
- AVC → Annex B: a length prefix becomes a start code, Annex B passes through,
  a length past the buffer and a trailing partial length raise `ValueError`,
  and the sample rebuilt as AVC converts back to the exact original bytes;
- keyframes: AUD/IDR detection, a P frame is not a keyframe;
- SPS: `avc1.F4002A`, `(1920, 1080)` from 1920x1088 with cropping, and the
  `ValueError` cases.

`bash streaming/tap/entrypoint_pipeline_test.sh`: tap off prints the 43 words
the entrypoint printed before this job, word for word; tap on prints
`python3 /usr/local/bin/tap/tap_runner.py --port 8788 --` and then those words
with `tee name=t`, `t.` and the tap branch inserted right after the encoder;
`TAP_PORT=9101` is passed; `SESSION_AUDIO=separate` and `off` keep their words.

Measurement pipeline (tp-stream, `videotestsrc` 1920x1080 60 fps ! videoconvert !
`nvautogpuh264enc` with the entrypoint's properties, GOP 60, b-frames 0 ! tee;
`fakesink` as the stand-in for the webrtcsink branch; the real tap branch):

| What | Result |
| --- | --- |
| delivered rate | 300 frames / 5 s, 60.0 fps |
| `info()` | `avc1.F4002A`, 1920x1080, `sps_pps_on_every_keyframe True`, `has_reordering False` |
| B-frames | none: every buffer's DTS equals its PTS |
| SPS and PPS on each IDR | 6 of 6 keyframes (also every 60 frames on the periodic IDR) |
| AUD | first NAL of every access unit (type 9) |
| IDR sizes | 27,093 / 31,519 / 31,542 / 38,602 / 40,584 B |
| P-frame sizes | min 2,520, median 8,689, max 36,090 B |
| force-key-unit | asked at frame 97 → IDR at 98; at 251 → IDR at 252 (1 frame, ≈17 ms) |
| 200 ms limit | a second `request_key_unit()` in the same window returns False |
| tap's delay | other branch's buffer lag 38 µs mean / 70 µs max without the tap, 39 µs / 85 µs with it |

## Decisions

1. **The tap branch has no caps filter.** The brief's words
   (`h264parse ! video/x-h264,stream-format=byte-stream,alignment=au ! appsink`)
   stall this session's pipeline at PAUSED: the encoder holds one buffer, the
   webrtcsink branch never prerolls, no tap frame arrives. It reproduced with
   `fakesink` in place of webrtcsink, with `openh264enc`, with the caps before
   the tee and with the tee after a shared parser, so it is the caps filter
   (a renegotiation from AVC to byte-stream inside the branch), not the tee.
   The branch is `queue leaky=downstream max-size-buffers=2 max-size-time=0 !
   h264parse config-interval=-1 ! appsink name=tap …`, and the runner converts
   each unit to Annex B with `tap_frames.avc_to_annexb`, so PROTOCOL.md's
   Annex B, AUD-first, SPS+PPS-before-every-IDR contract still holds (the table
   above is measured after the conversion). If a later GStreamer fixes the
   stall, the caps word can go back in and the conversion can be dropped; the
   conversion passes Annex B through unchanged, so both together are harmless.
2. **`async=false` on the tap appsink.** An async sink that has not prerolled
   holds the whole pipeline at PAUSED; with `async=false` the sink never blocks
   state changes and the branch needs no preroll to start.
3. **Keyframe requests go upstream from the tee's src pad, not from the tap's
   sink pad.** From the appsink's sink pad the event dies in `h264parse`
   (`send_event` returns False) and the encoder makes no IDR; from the tee's
   src pad that feeds the branch it returns True and the next frame is an IDR
   (table above). `_key_unit_pad()` finds that pad by walking the branch back to
   the element with more than one src pad, so the branch can change without a
   name being passed in. The event is pushed from the sample callback, because
   a serialised upstream event may only go from the streaming thread
   (`request_key_unit()` only raises a flag; the next sample sends it).
4. **`SESSION_TAP` follows `SESSION_AUDIO`'s shape.** Default off; a value that
   is not on or off warns and runs the pipeline in `gst-launch` as before; a
   `TAP_PORT` that is not a number warns and takes `automation_port + 1`
   (PROTOCOL.md's port). The ready line gains ` tap=on:<port>` only when on, so
   logs of ordinary runs are unchanged.
5. **`--print-pipeline` only when the entrypoint is sourced or run with that
   argument, before `main`.** It prints exactly the command `start_logged` would
   run (the runner and the words, or `gst-launch-1.0 -e` and the words) and
   starts nothing; nothing else about a real start changes.
6. **The sample was captured at 1080p, black, bitrate 200**, to stay under the
   brief's 60 KB while keeping real access units (AUD, SPS/PPS, IDR, three P
   frames); its json records what the tests assert.
7. **`tee name=t`** stays the entrypoint's own name (the brief's words); the
   runner does not depend on it.

## Blocked

- Nothing. `python3-gi`, `GstApp` and both typelibs already work in tp-stream,
  so the tap was measured there.

## Obstacles met (for the record)

- The brief's tap branch stalls the pipeline at PAUSED (Decision 1); finding it
  took most of this job (fakesink, openh264enc, caps placement, tee placement).
- `waylanddisplaysrc` does not load in tp-stream (`undefined symbol:
  wl_client_set_max_buffer_size`), so a real capture and the `socket_name=`
  ready line could not be exercised here; the measurement uses `videotestsrc`.
- A force-key-unit event from the appsink's sink pad is refused by `h264parse`;
  from the main thread it returns False even where it is accepted, because a
  serialised event must be sent from the streaming thread (Decision 3).
- `Gst.Element.get_num_src_pads` and `Pipeline.iterator_find` are not
  introspected by this PyGObject; pads are counted from `element.pads`.
- The first harness hung on the stall; a killed run left two processes of mine
  behind, which I killed by PID.

## Self-check (docs/review-rules.md, part A, items 1-5)

1. **Every host setup:** not affected — no app, TV or phone code changed; the
   tap is host-side and off by default, and with it off the entrypoint's words
   are the same 43 as before (entrypoint_pipeline_test.sh).
2. **When kept state starts and ends:** the runner's counters and flags start
   at zero on construction; `key_request_pending` lasts until the next sample
   pushes it (or forever if frames stop, where there is nothing to ask); the
   200 ms limiter is `time.monotonic_ns` and only moves on a request; EOS, a
   stop signal or the loop ending set the pipeline to NULL and end the process
   (measured in the harness for EOS and SIGTERM).
3. **How a new state combines with the others:** the tap is a second branch,
   not a pause/hide/wait; tap on/off × audio joined/separate/off × bad switch
   values × `TAP_PORT` are covered word for word in entrypoint_pipeline_test.sh;
   the pipeline has one appsink as its only new state.
4. **Stay in the job's folder:** only the seven files listed under Files
   changed, all inside `allow:`.
5. **Stop rather than overstep:** nothing outside `allow:` was needed; the
   brief's tap branch could not be used as written, which is Decision 1, and
   the image was not built, as asked.

## Hand-over

What exists: `streaming/tap/` (helpers, runner, tests, sample) and the
`SESSION_TAP` switch. opt2-2 plugs in through `TapRunner.add_frame_callback`,
`runner.info()`, `runner.request_key_unit()` and `runner.port`; the tap port is
`automation_port + 1` on loopback, path `/tap`.

Commands that worked (inside tp-stream, after `tools/wsl-sync.sh tp-stream`):

```bash
cd /work/flash-20261113-100102-43291
python3 streaming/tap/tap_frames_test.py           # 17 tests, OK
bash streaming/tap/entrypoint_pipeline_test.sh     # ok: … tap off and on
bash -n streaming/entrypoint.sh
```

For a real run: `SESSION_TAP=on TAP_PORT=8788` in the session's environment;
the session then logs `playing, the tap server's port is 8788` on stderr.

Do not redo: the byte-stream caps filter experiment (it stalls; Decision 1),
the async appsink (stalls at PAUSED; Decision 2), or sending the keyframe
request from the tap's sink pad (Decision 3).

Open: nothing was run with a real capture or with webrtcsink in the pipeline
(`waylanddisplaysrc` is broken in tp-stream); the first real session with
`SESSION_TAP=on` should still be watched for the encoder's rate when the tap
client is slow (the leaky queue should hold it at the tap only).

## Commit message

```
Add an in-process host tap behind SESSION_TAP (opt2-1)

With SESSION_TAP=on the entrypoint runs the session pipeline in Python
(tap_runner.py) instead of gst-launch and reads the encoded access units from
an appsink behind a tee after the encoder; tap_frames.py turns them into Annex B
units and reads the profile and size the tap server's hello needs. The switch
defaults off and a bad value warns and runs gst-launch as before. The branch
drops the byte-stream caps filter, which stalls the pipeline at PAUSED here, and
converts AVC in the runner instead; keyframe requests go upstream from the tee's
src pad, which is the only way the encoder sees them.
```

## Status row

- **opt2-1 done:** the host tap behind `SESSION_TAP` (runner, helpers, sample,
  17 tests, entrypoint words test, switch, Dockerfile lines), measured at
  60 fps with `avc1.F4002A`, AUD and SPS+PPS on every IDR, an IDR one frame
  after a request and no added delay to the other branch; **open:** no run with
  a real capture or the webrtcsink branch (`waylanddisplaysrc` is broken in
  tp-stream), and opt2-2's WebSocket server still to be written.

## Delete

- `streaming/tap/testdata/sample_h264.b64`
