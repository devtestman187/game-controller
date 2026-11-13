# M15 fix8 phase 2 (build): the host-side marker row, off by default

## Summary

- **The row exists and is off everywhere else.** `docs/streaming-marker.md` is the spec: 57 cells at the
  top-left (1 light border, 2 sync, 16 counter, 32 clock, 1 press flip, 4 checksum, 1 light border), 16 px a
  cell at a 1920 px picture, dark below 80 / light above 160 after a cell's 3x3-centre mean.
- **Dart half:** `marker_code.dart` (encoder, checksum, reference decoder from cell bits),
  `marker_decoder.dart` (luminance grid → cells), `marker_strip.dart` (a `CustomPaint` row in
  `AutomationShell`, above the card and the game, ignoring pointer events).
- **Switch:** session `SESSION_MARKER=on` → entrypoint passes `THUMBPARTY_MARKER=1` → `AutomationSettings.marker`
  → the shell mounts the row. Default off; a phone build reads no environment, so it can never draw it.
  `switches.txt` names it through bench's existing `--set` path, and the ready line gains ` marker=on`.
- **Tests first:** 16 new cases (`marker_code_test`, `marker_decoder_test`, `marker_strip_test`, one in
  `automation_settings_test`): the 6 spec vectors, a 500-value round trip, the wrap, a blurred + ±25-noise +
  16-level picture, a mid-grey cell, a broken checksum, the border, a row captured from the real run, no row
  with the flag off, the press flip holding until the next press.
- **One 20 s probe run with the row on** (headless Chrome viewer): ready line `… audio=joined marker=on`,
  `switches: SESSION_MARKER=on`, 1996 kbit/s received, game 20.6 ms/frame, build 0.8 + raster 6.1 ms.
- **One 20 s probe run with it off:** `switches: none`, 2031 kbit/s, game 20.5 ms/frame, build 0.6 +
  raster 5.6 ms. The row costs 0.2 ms of build and 0.5 ms of raster a frame; the frame interval is unchanged
  (20.6 against 20.5 ms).
- **The row is in the picture:** the automation screenshot of the running session
  (`docs/briefs/m15/bench-results/f8-2-marker-strip-on.png`) shows it at the top-left, and the reference
  decoder reads that captured row back as counter 4002, host 74568 ms, flip off, checksum valid — the card
  drawn in the same frame said `flip 180 · 74281 ms`, 287 ms earlier.
- **Not proven here:** the headless Chrome is not Safari, and reading the row out of the *video element* is
  phase 3. This phase proves the row is drawn into the captured picture, decodes, and costs almost nothing.

## Decisions

- **App-wide overlay, not a screen's own widget.** A probe run shows the latency card, not a game, and the row
  must be in that picture too; so it is mounted in `AutomationShell` (last child, above the card). With the
  flag off no widget exists at all. Reading the brief's "not on any other screen" as "not part of any screen's
  UI, absent unless the flag is on".
- **Rows, colours, sizes:** 57 cells, content 55 (brief's counts); a light border cell at each end so a reader
  can see the row's ends and the picture was cut at the right size; pure black/white, not the look's paper/ink,
  because the thresholds are luminance.
- **Checksum:** xor of the 12 nibbles of `counter << 32 | clock`, with the press flip as bit 0 of the lowest
  nibble. It covers everything but the sync cells, so a single wrong cell always unreads the row.
- **Decoder API:** the reference decoder takes the row's crop (`912 x 16` at 1080p) as a grid of luminance,
  cuts it into `width ~/ 57` columns and reads each cell's centre 3x3 — the rule the page will copy. A cell
  between the levels, a wrong sync or border cell, or a bad checksum is reported as a reason string, never a
  guess.
- **Stamp:** the host clock is read in the ticker callback (the start of the frame's build) and drawn in that
  frame; between it and the glass lie layout, raster and capture, which the spec states and the marker cannot
  see.
- **Frame counter:** counts the row's own frames (one per painted frame, wraps at 65536). It is the app's frame
  count while the row is up, not the game's.
- **Env name and value:** `THUMBPARTY_MARKER=1`, the same one-value convention as `THUMBPARTY_AUTOMATION`;
  `SESSION_MARKER` accepts `on`/`off` and warns (then runs off) on anything else. The entrypoint passes an
  empty value when off, so an ordinary launch's environment is exactly as it was.
- **Not exported** from `party_host.dart`: the shell that draws it is in the package; tests import the `src/`
  paths, as `frame_timing.dart` is imported today.

## What changed

- `docs/streaming-marker.md` (new): the spec both sides follow, the cell table, the thresholds, when the clock
  is stamped, why the app draws it and its weakness, the switch, and six test vectors.
- `packages/party_host/lib/src/automation/marker_code.dart` (new): constants, `encodeMarker`,
  `markerChecksum`, `decodeMarkerCells`, `MarkerReading`, `MarkerRead`.
- `packages/party_host/lib/src/automation/marker_decoder.dart` (new): `decodeMarker` from a luminance grid,
  `markerDarkBelow`/`markerLightAbove`.
- `packages/party_host/lib/src/ui/marker_strip.dart` (new): `MarkerStrip` (ticker, press-flip listener,
  `IgnorePointer`, `RepaintBoundary`) and `MarkerPainter`.
- `packages/party_host/lib/src/automation/automation_settings.dart`: `envMarker`, the `marker` field,
  `fromSources` reads it, `describe` reports it.
- `packages/party_host/lib/src/ui/automation_gate.dart`: mounts `MarkerStrip` when the launch said so.
- `packages/party_host/test/marker_code_test.dart`, `marker_decoder_test.dart`, `marker_strip_test.dart`
  (new), `automation_settings_test.dart` (+1 case).
- `streaming/entrypoint.sh`: `SESSION_MARKER` (default `off`), a warning for other values, the app's
  `THUMBPARTY_MARKER` and ` marker=on` on the ready line.
- `docs/automation.md` (a "marker row" section), `streaming/README.md` (a settings-table row),
  `docs/dev-tools.md` (one bench example).
- `docs/briefs/m15/bench-results/f8-2-marker-strip-on.png`: the screenshot of the row in the session.

## Computed test values

- Vectors (value → 55 content cells): `(0, 0, off)` → `1000…0000`; `(1, 1, on)` → `…0110001`;
  `(0xABCD, 0x01234567, off)` → `1010101011110011010000000100100011010001010110011100000`;
  `(0xFFFF, 0xFFFFFFFF, on)` → `…1110001`; `(0x0001, 0x00000002, off)` → `…1000011`;
  `(12345, 987654321, on)` → `…0110110`; the full strings are in the spec and the test.
- Checksum checks by hand: `(0x1, 0x2, off)` → nibbles `0,0,0,1,0,0,0,0,0,0,0,2` xor = 3 = `0011`, the test's
  vector; `(0xABCD, 0x01234567, off)` → xor of `A,B,C,D,0,1,2,3,4,5,6,7` = 0.
- The captured row (57 cells from the run's picture): counter 4002, host 74568 ms, flip false; the card in
  the same frame read 74281 ms at flip 180, so the two clocks agree to 287 ms.
- Run numbers: on 20.6 ms/frame, build 0.8 + raster 6.1, 1996 kbit/s; off 20.5 ms/frame, build 0.6 +
  raster 5.6, 2031 kbit/s; both 0 % slow frames, both ready in 6 s, window 32-33 s of a 20 s probe.

## The run (distro, tp-stream)

```
tools/wsl-sync.sh tp-stream                      # /work/flash-20261112-202727-27447
cd /work/flash-20261112-202727-27447 && docker build -f streaming/Dockerfile -t tp-session:latest .
bash streaming/bench.sh --probe --seconds 20 --set SESSION_MARKER=on --out /work/f82-on --keep
curl -s -H "x-automation-token: $(cat /work/f82-on/token-0)" -o /work/f82-on-strip.png \
  -w "%{http_code} %{size_download}\n" http://127.0.0.1:45783/automation/v1/screenshot   # 200 19652
ffmpeg -v error -i /work/f82-on-strip.png -vf "crop=912:16:0:0,scale=57:1:flags=area" \
  -f rawvideo -pix_fmt gray - | od -An -tu1    # the 57 cell luminances, all 0 or 255
docker rm -f thumb-party-bench0
bash streaming/bench.sh --probe --seconds 20 --out /work/f82-off
```

A `bash -lc` that assigned `tok=$(cat …)` arrived with an empty `tok` through `wsl.exe`; inlining
`$(cat /work/f82-on/token-0)` inside the `-H "…"` argument worked. No container or process is left running.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** TV/PC host: the row only when `THUMBPARTY_MARKER=1`, which `SESSION_MARKER=on` sets;
   a phone on "Play on this phone" or "Show on this device": `controller_app` reads no environment
   (`env: (_) => null`), so the row can never be drawn; a joined phone draws the game view, not host UI; an
   older build ignores the variable. Tested: `automation_settings_test` (off by default, only `1` on) and
   `marker_strip_test` (no row with the flag off).
2. **When kept state starts and ends.** The ticker starts in `initState` and is disposed with the widget; the
   counter and the flip reset with it; with the flag off there is no widget and nothing runs. Tested:
   `marker_strip_test` pumps an empty tree at the end and the framework finds no live ticker.
3. **How it combines with other states.** It is a passive overlay: `IgnorePointer`, no pause, no hiding. It
   combines with the latency card (a probe run, tested by the flip case) and with a round (the run's round
   path is unchanged); it does not touch pause, away, results or leaving.
4. **Stay in the job's folder.** Only paths in `allow:` changed. Exception, reported: `flutter pub get`
   (from `flutter test`) rewrites `tv_test_app/{linux,windows}/flutter/generated_*` with LF, which shows as
   modified with *no content diff*; I rewrote those six files back to their committed CRLF, and `git status`
   is clean again (`git diff` empty for them). `tools/check.sh` repeats the rewrite, so the runner may see them.
5. **Stop rather than overstep.** Nothing outside `allow:` was needed; no default changed (the row is off and
   every existing line, ready line included, is identical without the switch).

## Hand-over

- **Exists now:** the spec (`docs/streaming-marker.md`), the host's encoder, reference decoder and widget, the
  `SESSION_MARKER` → `THUMBPARTY_MARKER` switch, its docs, and 16 tests.
- **Commands that worked:** the block under "The run"; plus `tools/check.sh format analyze host tv` (all PASS:
  format, analyze, 442 host tests, tv).
- **Numbers phase 3 must not recompute:** the row costs 0.2 ms build + 0.5 ms raster a frame, frame interval
  unchanged (20.6 against 20.5 ms); the captured row decoded to counter 4002 / 74568 ms / flip off.
- **Do not redo:** the cell layout, the checksum rule and the vectors are settled — the JS must follow
  `docs/streaming-marker.md` exactly, including the 3x3-centre mean and the 80/160 levels.
- **Open:** the page's readback (phase 3) and whether the row survives the phone's decode; whether a phone
  host should be able to switch the row on (today it cannot); and the `tv_test_app/*/generated_*` line-ending
  rewrite that any `flutter pub get` causes on this machine.

## Commit message

feat(host): draw the bench marker row in the picture, off by default

Adds the host half of the fix8 marker: a 57-cell row in the picture's top-left
(sync cells, a 16-bit frame counter, the low 32 bits of the host clock, a press
flip and a 4-bit checksum), drawn by a CustomPaint in AutomationShell only when
the launch sets THUMBPARTY_MARKER, which SESSION_MARKER=on passes to the app.
Encoder, reference decoder and the spec share six test vectors; the row is in
the captured picture of a real session and reads back as counter 4002 at
74568 ms, at 0.2 ms build and 0.5 ms raster a frame. No switch on, no change.

## Status row

M15 fix8 f8-2 host marker done: `docs/streaming-marker.md` plus the Dart encoder, reference decoder and
`CustomPaint` row behind `SESSION_MARKER=on` (ready line `marker=on`, `switches.txt` naming it), 15 tests, one
20 s probe run with the row visible in the captured picture and reading back correctly, one without it, frame
interval unchanged (20.6 against 20.5 ms); open: the player page's readback (phase 3) and the phone deciding
whether the row survives Safari's decode.

## Delete

- none
