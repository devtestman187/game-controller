# The streaming marker

The stream chain's `total` and press-to-screen disagree on the owner's iPhone by
61-139 ms, and no field in either covers decoded frame to glass
([fix8 audit](briefs/m15/fix8/f8-1-audit-report.md)). The marker is the
independent measurement: the host draws a machine-readable row of cells into
the picture, and the player reads it back out of the video element. This file is
the spec both sides follow; the host's half is
`packages/party_host/lib/src/automation/marker_code.dart` (encoder),
`marker_decoder.dart` (the reference decoder) and `src/ui/marker_strip.dart`
(the widget); the player's half is the next phase.

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

## The switch

`SESSION_MARKER=on` on the session (§ "Switches" in
[streaming/README.md](streaming/README.md)) makes the entrypoint pass
`THUMBPARTY_MARKER=1` to the app; the shell reads it into
`AutomationSettings.marker`, and `AutomationShell` mounts the strip above
everything else. Off — the default — no strip exists in the widget tree, and a
phone's build has no environment to switch it on.

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
