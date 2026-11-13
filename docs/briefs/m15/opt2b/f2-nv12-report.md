# opt2b-2 NV12: the tap session encodes 4:2:0, not 4:4:4 — report

## Summary

With `SESSION_TAP=on` the entrypoint now puts `video/x-raw,format=NV12` between
`videoconvert` and the encoder, so the tap session encodes 4:2:0. `SESSION_TAP=off`
prints the same 43 words as before, byte for byte (the pipeline test diffs them).
Root cause, proved in tp-stream: the encoder's sink takes only NV12 or Y444
(`gst-inspect-1.0 nvautogpuh264enc`), videoconvert negotiated **Y444**, and NVENC
then made High 4:4:4 Predictive — the `avc1.F4002A` of the opt2-1 report.
Measured with the session's encoder properties and the real tap branch:
`avc1.42C02A` (constrained baseline, 4:2:0) and `chroma420 True`, where the
unpinned pipeline gives `avc1.F4002A` and `chroma420 False`.

The tap now reads the chroma format from the SPS: `tap_frames.is_chroma_420`,
one stderr line `tap: stream is not 4:2:0 (<profile>)` when it is not, and
`chroma420` (true/false/null until the first SPS) in `info()` and in the hello,
as an extra field (PROTOCOL.md does not name it yet).
Tests: `tap_frames_test.py` 21 OK (4 new), `tap_server_test.py` 30 OK (2 new),
`entrypoint_pipeline_test.sh` ok, `entrypoint_audio_test.sh` ok, `tools/check.sh
format` PASS. Tests were written first and failed for the right reasons (3
`AttributeError`s, 2 hello `KeyError`s, the pipeline test's NV12 line).
Not done: no real session encode (`waylanddisplaysrc` does not load in the
distro; videotestsrc used); no `video/x-h264,profile=high` (the element has no
`profile` property, see Decisions and Questions).

## Files changed

- `streaming/entrypoint.sh`: `capture_words` prints `video/x-raw,format=NV12 !`
  right after `videoconvert !`, only when `SESSION_TAP=on`; the encoder's own
  words and the size/framerate caps are untouched.
- `streaming/tap/entrypoint_pipeline_test.sh`: new checks — tap on has the NV12
  caps linked after `videoconvert` and right before the encoder, and the words
  before the tee are the old ones once this one pair is taken out; tap off still
  equals the captured old command exactly (unchanged check).
- `streaming/tap/tap_frames.py`: `is_chroma_420(sps)`, `chroma_format_idc == 1`.
- `streaming/tap/tap_frames_test.py`: `ChromaTest`, 4 cases over three hand-made
  SPSs (bytes and what they say are in the report below).
- `streaming/tap/tap_runner.py`: `is_chroma_420` state (None until the first
  SPS), `"chroma420"` in `info()`, and the one `tap: stream is not 4:2:0 …` line.
- `streaming/tap/tap_server.py`: `_hello_text()` sends PROTOCOL.md's hello plus
  `chroma420` (extra field; the page ignores what it does not know).
- `streaming/tap/tap_server_test.py`: the fake `info()` carries `chroma420`, plus
  two tests — the hello says true for 4:2:0, and null before the SPS arrives.

## Tests and results

All run in tp-stream on the synced copy (`/work/flash-20261113-124136-51980`).

| Command | Result |
| --- | --- |
| `python3 streaming/tap/tap_frames_test.py` | `Ran 21 tests … OK` |
| `python3 streaming/tap/tap_server_test.py` | `Ran 30 tests in 2.764s … OK` |
| `bash streaming/tap/entrypoint_pipeline_test.sh` | `ok: the entrypoint pipeline, tap off and on` |
| `bash streaming/tap/entrypoint_audio_test.sh` | `ok: the entrypoint audio modes` |
| `bash -n` on `entrypoint.sh` and both shell tests; `python3 -m py_compile` on the five `.py` files | clean |
| `tools/check.sh format` | `PASS format` |

Before the change, with the new tests only: `tap_frames_test.py` 21 tests, 3
errors (`is_chroma_420` missing); `tap_server_test.py` 2 errors (`KeyError:
'chroma420'`); `entrypoint_pipeline_test.sh` `FAIL: SESSION_TAP=on does not pin
the encoder's input to NV12`.

Computed values (all three SPSs were checked against `tap_frames` itself, so the
test bytes and the parser were verified together):

| SPS (hex, from its NAL header) | What it says |
| --- | --- |
| `67f4002a919b280f0044fc4a` (hand-made: profile 244, level 42, chroma_format_idc 3, 120x68 MB, 8 cropped lines) | `avc1.F4002A`, 1920x1080, `is_chroma_420` False |
| `677a002abcd940780227e250` (hand-made: profile 122, level 42, chroma_format_idc 2) | `avc1.7A002A`, 1920x1080, `is_chroma_420` False |
| `67640028acd940780227e5c044000003000400000301e03c60c658` (x264's 1080p High SPS, the sample `streaming/player/wc_selftest.html` uses) | `avc1.640028`, 1920x1080, `is_chroma_420` True |

Real encodes in tp-stream (GStreamer 1.24.2, NVENC, `videotestsrc` 1920x1080
60 fps, the session's encoder words, read back with `tap_frames`):

| Input to the encoder | SPS profile | chroma |
| --- | --- | --- |
| no caps (as before): videoconvert chose **Y444** | `avc1.F4002A` (high-4:4:4) | not 4:2:0 |
| `video/x-raw,format=NV12` | `avc1.42C02A` (constrained-baseline) | 4:2:0 |
| `video/x-raw,format=NV12` + `video/x-h264,profile=high` after the encoder (tested, **not** added) | `avc1.64002A` (high) | 4:2:0 |

The same two cases through `tap_runner.py` with the real tap branch (`tee`,
`fakesink` for the WebRTC branch, `h264parse`, `appsink name=tap`):

```
NV12:    tap: stream is avc1.42C02A 1920x1080
         tap: stopped after {'profile': 'avc1.42C02A', 'chroma420': True, …}
no caps: tap: stream is avc1.F4002A 1920x1080
         tap: stream is not 4:2:0 (avc1.F4002A)
         tap: stopped after {'profile': 'avc1.F4002A', 'chroma420': False, …}
```

So the profile string expected after the change with only the NV12 caps is
**`avc1.42C02A`**, not `avc1.64002A`: videoconvert (now pinned) hands NVENC NV12,
and this nvcodec build's own default profile for NV12 is constrained-baseline.

## Decisions

- **Only the NV12 caps, no `video/x-h264,profile=high`.** The brief allows a
  profile setting only through the encoder's `profile` property and only if a
  test shows it is needed; the element has no such property (a pipeline error
  says `no property "profile"`), and 4:2:0 is what Safari was missing. I tested
  the caps-filter route and it gives `avc1.64002A`, but adding it is a design
  change the brief did not ask for — it is a question below.
- **`chroma420` is added in `tap_server._hello_text()`, not in
  `tap_queue.hello_message()`.** `tap_queue.py` is outside `allow:`; the server
  takes the hello it is given and adds the one field.
- **`None` until the first SPS**, like `profile`, `width` and `height`: the hello
  goes out on connect, often before a keyframe.
- **The log line is once per run**, inside the block that learns the first SPS
  (that block already runs once).
- **The fields are named `chroma420` (wire) and `is_chroma_420` (Python)**,
  keeping the Python name a question as the guidelines ask.

## Blocked

Nothing.

## Obstacles met (for the record)

- `waylanddisplaysrc` still does not load in tp-stream, so the real capture could
  not be run; `videotestsrc` with the same caps and encoder words was used.
- A first encode attempt wrote no file (`MESA-LOADER: failed to retrieve device
  information` on stderr) and the retry worked; the GPU is shared, so a retry is
  the answer rather than a change.
- One `gst-launch` with the tee shape hung until the timeout once; the identical
  pipeline ran at once afterwards. Same shared-GPU behaviour, no code involved.
- `git status` also shows six `tv_test_app/**/generated_plugin*` files modified
  and untracked `docs/briefs/m15/*/run-base` folders; this job did not touch
  them (no build was run here), so they were there before it.

## Self-check (docs/review-rules.md, part A, items 1-5)

1. **Every host setup.** Not affected: this is the Linux session pipeline, one
   encoder for every viewer; the page's decoders all get the same stream. The
   tap-off case is every build without `SESSION_TAP` and stays word-identical
   (`entrypoint_pipeline_test.sh`).
2. **When kept state starts and ends.** `is_chroma_420` starts `None`, is set
   once on the first keyframe that carries an SPS, and ends with the process;
   nothing is timed or held between runs (`tap_server_test.py`'s null-hello test).
3. **How a new state combines with the others.** Tap on + joined/separate/off
   sound: the sound's words are unchanged with the tap on
   (`entrypoint_pipeline_test.sh`, `entrypoint_audio_test.sh`); tap off is
   unchanged (data test above). Tap on + WebRTC branch: only the encoder's input
   caps change, the branch is untouched.
4. **Stay in the job's folder.** Only files from `allow:` were written.
5. **Stop rather than overstep.** PROTOCOL.md would need `chroma420` named and
   the player page could read it; neither is in `allow:`, so both are reported,
   not edited. No other file was needed.

## Questions and suggestions

1. **High or constrained-baseline?** With the NV12 caps this nvcodec build picks
   constrained-baseline (`avc1.42C02A`), which is 4:2:0 but has no CABAC. A caps
   filter `video/x-h264,profile=high` right after the encoder gives
   `avc1.64002A` and worked in tp-stream. That is a separate change; say if you
   want it in a later job.
2. **PROTOCOL.md needs the field.** The hello now carries `chroma420` as an
   extra field; `docs/briefs/m15/opt2/PROTOCOL.md` should name it (not in
   `allow:`).
3. **The page could use it.** `streaming/player` ignores `chroma420` today; a
   one-line warning when it is false would have said why Safari refused the
   stream in November (also outside `allow:`).

## Hand-over

What exists: the NV12 caps in `capture_words` behind `SESSION_TAP=on`,
`tap_frames.is_chroma_420`, the runner's one warning line and `chroma420` in
`info()` and the hello, and tests for each.

Exact commands that worked (in tp-stream, from the synced folder):

```
python3 streaming/tap/tap_frames_test.py
python3 streaming/tap/tap_server_test.py
bash streaming/tap/entrypoint_pipeline_test.sh
bash streaming/tap/entrypoint_audio_test.sh
gst-launch-1.0 -e videotestsrc num-buffers=3 ! video/x-raw,width=1920,height=1080,framerate=60/1 \
  ! videoconvert ! video/x-raw,format=NV12 ! nvautogpuh264enc bitrate=4000 \
  ! h264parse config-interval=-1 ! filesink location=/tmp/out.h264
```

Not to redo: the tests-first red runs, the SPS parsing (verified against three
SPSs), and the caps proof (`-v` shows Y444 before, NV12 after).

Open: the real session encode with a capture (Claude's check); PROTOCOL.md's
`chroma420` field; whether the page should warn on `chroma420: false`; whether
the tap session should keep High profile.

## Commit message

tap: pin the encoder to NV12 so the tap session encodes 4:2:0

With SESSION_TAP=on, videoconvert negotiated Y444 into nvautogpuh264enc and
NVENC made High 4:4:4 Predictive (avc1.F4002A), which Safari will not decode.
capture_words now puts video/x-raw,format=NV12 between videoconvert and the
encoder; tap off prints the same words as before.
tap_frames reads chroma_format_idc and is_chroma_420; tap_runner logs one
"stream is not 4:2:0" line and puts chroma420 in info(); tap_server adds it to
the hello as an extra field (PROTOCOL.md does not name it yet).
Measured in tp-stream: avc1.42C02A 4:2:0 with the caps, avc1.F4002A without;
tap_frames_test 21, tap_server_test 30, both entrypoint tests and format pass.

## Status row

- **opt2b-2 done:** with `SESSION_TAP=on` the encoder is fed NV12 and the stream
  is 4:2:0 (`avc1.42C02A` measured with the tap branch; the unpinned pipeline
  gives `avc1.F4002A`), and the tap reports `chroma420` in its log, info and
  hello; **open:** PROTOCOL.md's `chroma420` field, a real capture encode, a
  Safari check, and whether to force High profile.

## Delete

- none
