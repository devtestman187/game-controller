# The streaming marker

The stream chain's `total` and press-to-screen disagree on the owner's iPhone by
61-139 ms, and no field in either covers decoded frame to glass
([fix8 audit](briefs/m15/fix8/f8-1-audit-report.md)). The marker is the
independent measurement: the host draws a machine-readable row of cells into
the picture, and the player reads it back out of the video element. This file is
the spec both sides follow; the host's half is
`packages/party_host/lib/src/automation/marker_code.dart` (encoder),
`marker_decoder.dart` (the reference decoder) and `src/ui/marker_strip.dart`
(the widget); the player's half is `streaming/player/marker_decode.js` (the
reader's decoder), `marker_reader.js` (sampling and the times) and
`clock_sync.js` (the page-to-host offset).

## The row

One row of cells at the top-left corner of the picture, most significant cell
first. A cell is 16 px square at a 1920 px wide picture; a picture of another
width scales every cell by `pictureWidthPx / 1920`, and the reader scales the
same way before it samples.

| Row cell | Content |
| --- | --- |
| 0 | quiet border, light |
| 1 | sync, light (1) |
| 2 | sync, dark (0) |
| 3-18 | frame counter, 16 bits, most significant first, wraps at 65536 |
| 19-50 | host clock, its low 32 bits in ms, most significant first |
| 51 | press flip: flips colour on the frame a probe press was applied in, holds until the next press |
| 52-55 | checksum, 4 bits |
| 56 | quiet border, light |

57 cells, 912 px wide at 1080p. A light cell is white (`0xFFFFFFFF`), a dark one
black (`0x00000000`) — the app's own colours, not the look's, because the
thresholds are luminance.

The checksum is the xor of the twelve nibbles of `counter << 32 | clock`, with
the press flip as bit 0 of the lowest nibble.

## Reading a cell

The reader takes the cell's centre 3x3 pixels, averages them, and classifies:
below 80 is dark (0), above 160 is light (1), and anything in between makes the
whole row unreadable — a guess is never a reading. The two levels survive
H.264 at the session's 10 Mbit/s and a blur; the reference decoder in
`marker_decoder.dart` is the same rule in Dart, tested through a 3x3 box blur,
±25 luminance of noise and quantisation to 16 levels.

A row is unreadable (never misread) when: the sync cells are not light then
dark, the border cells are not light, a cell is between the two levels, or the
checksum does not match.

## When the clock is stamped

The host reads its clock at the start of the frame's build (the tick that
follows a vsync) and draws that number in the same frame. Between the stamp and
the captured picture lie the frame's layout and raster — the host's own
`host_build` + `host_raster`, some 10-30 ms — and the compositor's capture into
the video source; the marker cannot see any of those, nor encoding, the
network, decoding or the glass. So a press→row time read from the video is
press to *painted picture*, and a row's age against the page's clock still
needs the `/clock` offset: only a press's time read inside one picture is free
of it.

## Why the app draws it

The row is a Flutter widget in the captured picture, not a GStreamer overlay:
it is in the very frame the press changed (the latency card flips on the same
provider), it is stamped on the clock `probe/press` answers in
(`gameHostProvider.nowMs`), and the session's pipeline needs no new element.
The weakness is the one above: it stamps paint start, not capture, so the
raster and the capture sit inside every marker reading.

## The player's half

`marker=1` on the page's URL (`--player-query marker=1`, or in
`SESSION_PLAYER_OPTIONS`) switches the reader on; off, nothing is read and no new
number is sent. The reader takes the strip's region — `57 × cellPx` wide at
the element's own width, its middle three rows — plus the latency card's patch
in the same read (below), one `getImageData` per frame inside
`requestVideoFrameCallback` (an animation frame on a browser without it), and
decodes it with the rule above. A frame it cannot read is counted by reason:
checksum, sync, level, border, or a canvas the browser refuses; a guess is never
a reading. The read cost ~5 ms a frame in the headless Chrome when it was
measured (the [f8-3 report](briefs/m15/fix8/f8-3-marker-player-report.md)); the
fewer rows and the one shared read below cut it, and the page now sends what its
own reads cost (`wcReadMeanMs`, `wcReadMaxMs`) beside the draw they were taken
from, which is the figure that says whether reading slows the draw.

The callback's time is on the page's clock, so the reader converts it with a
NTP-style offset: it sends the `/clock` request the reporter always sent, keeps
the last five round trips, and markers use the one with the smallest RTT (the
reporter's own numbers keep the middle sample, so an off run is unchanged);
offset = host clock − page clock, uncertainty = half the RTT, measured again
every 10 s through the run. A row's age at the callback is that converted time
less the row's stamped host clock (`marker_glass`), so it carries the offset's
uncertainty.

Every frame's `requestVideoFrameCallback` metadata is recorded raw, one fact per
field: `rvfc.presentationTime`, `rvfc.expectedDisplayTime`, `rvfc.captureTime`,
`rvfc.receiveTime`, `rvfc.processingDuration`, `rvfc.presentedFrames`,
`rvfc.width`, `rvfc.height`, `rvfc.mediaTime` and `rvfc.rtpTimestamp`, each as
min median max in the field's own unit (seconds, ms, pixels, frames, 90 kHz
ticks). A field the browser leaves out is missing from the batch, never 0: this
headless Chrome has no `captureTime`.

Decoded to display is `expectedDisplayTime − receiveTime` when the browser has
both, else `presentationTime − receiveTime`, and `markerDisplayFrom` says which
was used; `stream_display` carries it when the fields exist and keeps the old
figure otherwise. The callback's own lateness, callback time − expected display
time, is a second gauge (`markerCallbackLateMs`).

The press's own measurement comes from the flip cell: on a change between
readable frames the reader records that frame's converted host time, so
`press_to_marker` is that time less the `probe/press` host time the reporter
already fetches. It uses the same converted time as `marker_glass`, so it
carries the same offset uncertainty; the flip frame's own stamp lands a few ms
after the press, and is the difference between the two figures.

## The card and the marker on one frame (opt2c-5)

Both readers read the picture through one `FrameReadback` per picture
(`sharedReadback()` in `marker_reader.js`), called from the same `drawnFrame`
callback, with the draw's own timestamp. One `willReadFrequently` scratch
canvas takes two `drawImage`s — the strip's middle three rows and the card's
8 px patch — and then one `getImageData`; the result is cached by the frame's
stamp, so the second reader in a frame costs nothing and both figures are of the
frame that was just drawn.

The middle three rows hold the centre of every cell at any `cellPx` (the same
3x3 the decoder averages), so the strip's cells read exactly as they did from
all its rows; the card's pixel is the one the old separate 1x1 read took.

The card flips are kept with the host time of the frame that carried each, and a
press is timed against the first flip at or after it — the marker's rule — because
the 200 ms press poll usually arrives after the frame carrying the press's flip
was drawn. A flip a whole cadence (500 ms) after the press is still dropped as
the card's own, not counted as slow. A press at t whose frame is drawn at t+X
now reads the same sample from both readers; `wc_card_selftest.html` pins it.
One difference is left and pinned too: the card's own cadence flip can be the
first change after a press, so the card times that change while the marker's
flip cell still gives the press's own flip — a two-state card cannot tell them
apart, and the press-to-screen row's two columns show the gap.

What the reads cost is sent beside the draw they were taken from: `wcReadMeanMs`
and `wcReadMaxMs` (the readback's own timer) and `wcDrawMeanMs` (decode output →
drawn), all stages because a custom-player viewer's gauge slots are full, shown
in "Custom player (wc)". On the fake-canvas page test the shared read's mean is
0.04 ms and its longest 0.20 ms, against 0.09 ms for the old full-height strip
read plus a separate card read. Reading every drawn frame instead of every 8th
also makes `wcReadMeanMs` the frame's whole read, not a sample of it: a run with
reading on and off is what shows what it costs the draw. The read runs after the
frame's drawn time, so a read that slows the page shows in the next frames'
lateness and the frame rate rather than inside `wcDrawMeanMs`.

## The switch

`SESSION_MARKER=on` on the session (§ "Switches" in
[streaming/README.md](streaming/README.md)) makes the entrypoint pass
`THUMBPARTY_MARKER=1` to the app; the shell reads it into
`AutomationSettings.marker`, and `AutomationShell` mounts the strip above
everything else. Off — the default — no strip exists in the widget tree, and a
phone's build has no environment to switch it on.

The page's reader is a switch of its own, `marker=1` on the page's URL (see
[streaming/README.md](streaming/README.md)), off by default: with the row off it
reads nothing but the strip's region and counts every frame unreadable.

## Test vectors

The Dart tests (`packages/party_host/test/marker_code_test.dart`) and the
player's JS tests both use these rows: the value, then its 55 content cells
(row cells 1-55, borders aside) as a string of 0 and 1.

| Counter | Clock (ms) | Press flip | Cells |
| --- | --- | --- | --- |
| 0 | 0 | off | `1000000000000000000000000000000000000000000000000000000` |
| 1 | 1 | on | `1000000000000000010000000000000000000000000000000110001` |
| 0xABCD | 0x01234567 | off | `1010101011110011010000000100100011010001010110011100000` |
| 0xFFFF | 0xFFFFFFFF | on | `1011111111111111111111111111111111111111111111111110001` |
| 0x0001 | 0x00000002 | off | `1000000000000000010000000000000000000000000000001000011` |
| 12345 | 987654321 | on | `1000110000001110010011101011011110011010001011000110110` |
