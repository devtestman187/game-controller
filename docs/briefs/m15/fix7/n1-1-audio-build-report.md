# M15 fix7 n1 phase 1 — `SESSION_AUDIO` (build)

## Summary

- `SESSION_AUDIO` is added to `streaming/entrypoint.sh`: `joined` (the default, and the switch
  off: the pipeline is the old command line exactly), `off` (no `pulsesrc`/`opusenc` branch at
  all), `separate` (the sound goes into a second `webrtcsink` named `ws-audio`, with its own
  producer, peer connection and stream id; the picture's sink stays `ws` for the sampler).
- Step 1: webrtcsink 0.13.6 does not choose a stream id itself. webrtcbin names the producer's
  stream `userNNN@host-XXXX` and labels every track of that producer with the same id, in the old
  `a=ssrc:<ssrc> msid:<id> <track>` form (there is no `a=msid:` line). So in `joined` the picture
  and the sound share one MediaStream id, which is what lets Chrome lip-sync them — and hold the
  picture back for the sound's larger buffer. The pad property `msid` would set the id, but only
  from code: gst-launch cannot set pad properties, so candidate (i) was not available.
- Step 2: candidate (ii). Two producers in `separate` (`TP-Picture`, `TP-Sound`), the ready wait
  needs both, the page picks them by `meta.name` (not `producers[0]`), plays the sound on its own
  element, keeps one viewer row, and a lost sound session is rebuilt alone.
- Step 3: the existing numbers work in all three modes; one 30 s probe run per mode (summaries in
  `docs/briefs/m15/fix7/n1-1-audio-build/`). Each run: one viewer row `v1` (browser,
  chrome-headless) with 11 stage rows, jitter buffer / press-to-screen / pipelineMs present, the
  ready line naming the mode, no sound button. `separate` also shows two producers in the
  signalling log (`TP-Picture`, `TP-Sound`) and two different stream ids in the page's own state.
- The headless Chromium viewer is not Safari. These runs say the switch works and what it does to
  the host and to Chrome; the phone decides whether it helps. That comparison is the next phase.

## Step 1 — how webrtcsink 0.13.6 labels its streams

- In one consumer's SDP (read from the signalling log of the `joined` run) the video and the audio
  of one producer carry the same id:
  `a=ssrc:… msid:user2330734092@host-2633bd04 webrtctransceiver0` (video0) and
  `a=ssrc:… msid:user2330734092@host-2633bd04 webrtctransceiver1` (audio1). Chrome groups the
  tracks by that id, so the page gets one MediaStream with both.
- The id is per producer, not per track: the page's `remoteDescription` names one id for
  `joined` (`"msids": ["user2732388036@host-b9cff387"]`, `"audio": "joined"`).
- The plugin forwards a pad property `msid` on `video_%u`/`audio_%u` to webrtcbin, so the id can be
  chosen from code; it is not a gst-launch property (a pad property needs `element.pad::prop=…`,
  which gst-launch does not parse). There is no signal for it either.
- `streaming/player/player.js` used to take `session.streams[0]` and split the elements only when
  `SESSION_SPLIT_TRACKS` was on. It now takes the picture's stream and, when the sound has its own
  connection, the sound producer's stream as well (`streams.js`, `playback.js`).

## Decisions

- (ii) a second webrtcsink rather than (i) a pad `msid`: gst-launch cannot set pad properties, and
  the switch has to stay a pipeline setting the image can pass.
- Producer metas `TP-Picture` / `TP-Sound`, written `meta=TP-Picture,name=TP-Picture` because
  gst-launch wants a structure name before the fields (`meta=name=TP-Picture` is refused).
- The picture's sink is still `ws` and the sound's is `ws-audio`, which neither matches `ws` nor
  starts with `webrtcsink`, so `stream_sampler.dart`'s stage lookup is unchanged (checked by the
  existing sampler tests, and the 11 stage rows are the same in all three modes).
- The ready wait counts lines whose announcement says `roles:["producer"]`, because the server
  prints "registered as a producer" for a player's `listener` announcement too.
- One viewer row: only the picture's connection is reported to the host. The sound connection's
  own jitter buffer goes to the host as a new gauge `audioJitterMs` on that row, which the report
  shows in the "Streaming sound" table and the CSV (`audio_jitter_ms`).
- The overlay shows the sound's own bitrate and jitter when it has its own stream, and "sound none"
  for `off`.
- `video-caps`/`audio-caps` are not passed to the picture's sink, so `joined` is the old
  gst-launch line word for word; the audio sink is the only new element.
- Bitrate maths is untouched in all modes, so the next phase compares the audio alone.
- The page reads both SDP spellings of a stream id (`a=msid:` and `a=ssrc:… msid:`) because
  webrtcbin writes the old one.
- `reporter.js` was already 480 lines (over the 380-line limit) before this job; since the sound
  gauge needs it, the press/flip probe moved to `streaming/player/latency_probe.js` (161 lines)
  and the reporter is 370. The probe's behaviour is unchanged (press-to-screen still has 52–57
  samples per 30 s run).

## What changed

- `streaming/entrypoint.sh`: the `SESSION_AUDIO` setting and its doc comment, `sound_branch()`
  (one gst-launch token per line), the metas, `producer_lines`/`producer_notes`,
  `wait_for_producers` (1 producer, 2 for `separate`), `ready:` line carries `audio=<mode>` and
  `pipeline registered:` names the producers; an unknown value warns and falls back to `joined`.
- `streaming/player/player.js` (371): picture and sound streams, the sound's own element, the
  overlay's sound numbers, `audioJitterMs` through the reporter, msids in the page state.
- `streaming/player/streams.js` (new, 181): one consumer session per producer, chosen by meta,
  each reconnecting on its own; a lost sound never closes the picture's session.
- `streaming/player/playback.js` (new, 108): the video and audio elements, `pictureOf`/`soundOf`.
- `streaming/player/page_state.js` (new, 60): `/player` state reporting and `msidsOf`.
- `streaming/player/latency_probe.js` (new, 161): the press/flip probe, moved out of the reporter.
- `streaming/player/reporter.js`: `setSoundGauges` (the sound connection's gauges), probe split.
- `streaming/player/stats.js`: `audioJitterBufferMs` in a sample.
- `streaming/player/serve.py`, `relay_test.py`: the four new page files are served and checked.
- `streaming/README.md`: one settings row for `SESSION_AUDIO`, off by default, "the phone decides".
- `packages/metrics/lib/src/report_stream.dart` (380) and `report_stream_csv.dart`: the sound's own
  jitter in the "Streaming sound" table (last column `jitter ms`) and in the CSV.
- `packages/metrics/test/report_stream_test.dart`: the sound table's rows have the new column.
- `packages/metrics/test/report_stream_sound_connection_test.dart` (new): a viewer whose sound has
  its own connection is one row; the sound table shows that connection's mean jitter (`40.0` from
  20/40/60). Both fail on the report code as it was (5 cells, no jitter column).
- `docs/briefs/m15/fix7/n1-1-audio-build/{n1a-joined0,n1a-off0,n1a-separate0}.json`: the summaries
  of the three runs the numbers below come from.

## Runs (30 s probe, one per mode)

Command (same for each, `--set SESSION_AUDIO=off|separate` for the other two):

    bash streaming/bench.sh --probe --seconds 30 --label n1a-joined \
      --out /work/stream-bench/n1a-joined --keep

    docker exec thumb-party-n1a-joined0 curl -s http://127.0.0.1:45782/player

| mode | ready line (tail) | viewer row | jitter buffer | total | press | pipelineMs | enc fps |
| --- | --- | --- | --- | --- | --- | --- | --- |
| joined | `… 60f gop audio=joined` | 1 × `v1` browser chrome-headless, 11 stages | 265 | 300 | 228 (57) | 34.01 | 57.78 |
| off | `… 60f gop audio=off` | 1 × `v1`, 11 stages | 16 | 25 | 116 (55) | 7.58 | 57.98 |
| separate | `… 60f gop audio=separate` | 1 × `v1`, 11 stages | 14 | 50 | 137 (52) | 43.61 | 56.75 |

- The page's own state after each run:
  `{"state": "playing", "reconnects": 0, "msids": ["user2732388036@host-b9cff387"], "audio": "joined"}`,
  `{… "msids": ["user1545897270@host-3c16ab02"], "audio": "none"}` (off),
  `{… "msids": ["user2469211948@host-efd4ac16"], "audio": "own", "soundMsids": ["user3119526065@host-51058730"]}`
  (separate: two peer connections, two stream ids, no id in common).
- `pipeline registered:` in `separate`:
  `TP-Picture (73ff4d75-70d7-42bd-a8a4-13ca1388488e);TP-Sound (e320e57b-a655-4b0e-b429-f2015f2be825)`;
  the signalling log's own announcements say `roles:["producer"], meta:{"name":"TP-Sound"}`.
- `separate`'s host gauges also carry `audioJitterMs` mean 61.35 (the sound connection's buffer);
  the other two modes do not have the gauge, which is what the sound table's `-` means.
- These runs are for working-ness only. The joined jitter buffer read 265 ms here and 127–174 ms in
  earlier runs of the same command line, so a single 30 s run is noisy; the comparison is n1-2.

## Self-check (docs/review-rules.md part A, items 1–5)

1. Every host setup: it is a session-image pipeline switch, not app code; the page is the same for
   every viewer, and the TV/phone hosts keep the old pipeline unless the image sets the switch. The
   Linux session host was run in all three modes; nothing app-side changed.
2. Kept state: the sound's session starts when a `TP-Sound` producer appears, ends on its own
   `closed`/`error` (rebuilt after 1 s without touching the picture), and both end when the picture
   closes or the page stops; with no producer nothing polls (`streams.js`).
3. New state combinations: `separate` + a late sound (the picture plays first, the sound element is
   filled when its stream arrives), `separate` + a lost sound (only the sound reconnects),
   `off` + no audio track (no sound button, overlay "sound none"), reconnect of the picture
   (both sessions start clean).
4. Stay in the job's folder: only files in `allow:` were written; the summaries are in the job's
   folder.
5. Stop rather than overstep: no file outside `allow:` was touched. `reporter.js` was over the
   380-line limit before the job; splitting it (probe moved out) was the way to keep the rule, and
   it is written up under Decisions instead of being left over the limit.

## Hand-over

- Exists now: `SESSION_AUDIO=joined|off|separate` in the session image; `separate` gives the sound
  its own producer, peer connection and stream id; the player follows what arrives; the sound
  connection's buffer lands on the viewer row as `audioJitterMs`.
- Commands that worked (from the synced folder in `tp-stream`, image rebuilt after every change):

      tools/wsl-sync.sh tp-stream
      cd /work/flash-20261112-132841-15521 && docker build -f streaming/Dockerfile -t tp-session:latest .
      bash streaming/bench.sh --probe --seconds 30 --label n1a-separate \
        --out /work/stream-bench/n1a-separate --keep --set SESSION_AUDIO=separate
      docker exec thumb-party-n1a-separate0 curl -s http://127.0.0.1:45782/player
      python3 streaming/player/relay_test.py

- Numbers: jitter buffer 265 / 16 / 14 ms, press 228 / 116 / 137 ms, pipelineMs 34.01 / 7.58 /
  43.61 for joined / off / separate (final runs); separate's sound connection held 61.35 ms.
- Do not redo: the two-producer design, the meta names, the meta-based choice, the one-row rule,
  the probe split; n1-2 runs 45 s probes, three runs each. Open problem: the joined jitter buffer
  swings 127–265 ms across runs, and pipelineMs moves with it (7.58 without sound, 34–44 with it).

## Commit message

Add SESSION_AUDIO: sound joined, off, or on its own stream

`SESSION_AUDIO=joined` (default) keeps the pipeline as it was; `off` drops the sound branch;
`separate` records the sound into a second webrtcsink (`ws-audio`, meta `TP-Sound`) beside the
picture's `ws` (meta `TP-Picture`), so the sound has its own producer, peer connection and stream
id and Chrome has no shared stream id to hold the picture back for. The ready wait needs both
producers, the page picks them by meta and plays the sound on its own element, a lost sound is
rebuilt alone, and only the picture's connection is reported, so a viewer stays one row. The sound
connection's jitter buffer is recorded as `audioJitterMs` and shown in the sound table and CSV.

## Status row

M15 fix7 n1 phase 1: `SESSION_AUDIO=joined|off|separate` builds and runs in all three modes (one
viewer row, existing metrics, two producers and two stream ids in `separate`); open: the n1-2
comparison on the phone, and a multi-run median for the noisy jitter buffer.

## Delete

- none
