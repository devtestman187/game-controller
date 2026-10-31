# Thumb Party protocol

Version 1, as built in M9 (Thumb Party 0.9.0). This is the contract between a controller (the phone app) and a host (the TV app on Android TV or Windows). It's written so another host or controller (an engine kit, a PC bridge, a v3 receiver) can be built from it alone. The code that implements it is `packages/protocol` (messages, codec) and `packages/connection` (server, client); every field below can be checked there.

## 1. Discovery

The host advertises a DNS-SD service on the local network:

| Item | Value |
| --- | --- |
| Service type | `_gamectl._tcp` (iOS needs it in `NSBonjourServices`) |
| Instance name | `Thumb Party TV (<host name>)`; may get a suffix if taken |
| Port | `45780`, or any free port if that's taken (the advertised port is the truth) |
| TXT `id` | The host's stable random ID (hex) |
| TXT `v` | The protocol version, `1` |

A controller may also connect to an address the user types (`IP` or `IP:port`, port 45780 by default). The TXT `id` lets the controller know a host it has paired with before, even at a new address.

Any HTTP request to the port other than the WebSocket upgrade gets a short plain-text page, so a browser can check the host is reachable.

## 2. Transport and framing

- One WebSocket per controller: `ws://<address>:<port>/ws`. The controller connects (the host only listens). Roles (§5) are separate from this: a future display may be the side that connects out.
- Every frame is a UTF-8 text frame holding one JSON object, the **envelope**: `{"v": 1, "t": "<type>", ...fields}`.
  - `v` (integer, required): the protocol version. A peer with a different `v` closes with **4000**.
  - `t` (string, required): the message type.
  - The message's fields sit beside them. Optional fields are left out rather than sent as `null`.
- Binary frames, non-objects, a missing `v` or `t`, or a known type with a bad field close the connection with **4003**.
- **Unknown types are ignored** (no error), and so are unknown fields. This is how the protocol grows without a version change (§4).

## 3. Close codes

| Code | Meaning | Controller retries? |
| --- | --- | --- |
| 1001 | Host is shutting down | Yes |
| 4000 | Different protocol versions | No |
| 4001 | Wrong pairing code | Only with a new code |
| 4002 | Replaced: the same controller connected again | No |
| 4003 | Malformed or unexpected message | No |
| 4004 | No heartbeat for too long | Yes |
| 4005 | Didn't pair in time (5 minutes) | Only after user action |

## 4. Versioning and capabilities

The version number changes only for a breaking change. Everything else is additive, and announced with **capabilities**: `hello` and `welcome` each carry `caps`, a list of strings. A side sends a message that needs a capability only if the other side listed it. A host never sends a controller a message it didn't list.

| Capability | Adds | Since |
| --- | --- | --- |
| `metrics` | `metrics` (controller → host) and `metrics_ack` (host → controller) | M9 |
| `rating` | `rate_ask` (host → controller) and `rating` (controller → host) | M9 |
| `view` | A controller that also shows the game (phone-hosted play). Reserved | M12 |

Peers without capabilities (apps before 0.9.0) send no `caps`; treat that as an empty list. The v1 messages (§6 to §9) need no capability.

## 5. Connection flow

```
controller                                   host
    | -- hello -------------------------------> |
    | <------------------------------ welcome -- |
    | -- pair (code or token) ----------------> |
    | <-------------------------- pair_result -- |
    | <-------------------------------- player -- |   (if accepted)
    | <-- ping / pong, both ways, every second --> |
    | -- input, metrics, rating --------------> |
    | <------------- haptic, rate_ask, metrics_ack |
```

### `hello` (controller → host), first message

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `controllerId` | string | yes | Stable random ID of the controller install (not tied to a person) |
| `name` | string | yes | Label shown on the host, e.g. `iPhone 3F1C` (kept on the host, never recorded in analytics) |
| `platform` | string | yes | `ios`, `android`, `sim`, … |
| `appVersion` | string | yes | e.g. `0.9.0` |
| `role` | string | no | `controller` (default). `display` is reserved for a v3 receiver |
| `caps` | list of strings | no | Capabilities (§4) |
| `device` | object | no | Device class for analytics, below |

`device`: `kind` (`phone`, `tablet`, `foldable`, `desktop`, `sim`; required), and optional `model` (hardware model such as `iPhone15,2` or `Google Pixel 8`, never the user's own name for the device), `os` (e.g. `iOS 26.0`), `wMm` and `hMm` (physical screen size in mm, landscape: width is the long side), `haptics` (boolean).

A second `hello` on the same connection is a protocol error (4003).

### `welcome` (host → controller)

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `hostId` | string | yes | The host's stable ID (the controller saves tokens by it) |
| `hostName` | string | yes | e.g. `Android TV` |
| `appVersion` | string | yes | Host app version |
| `caps` | list of strings | no | Capabilities (§4) |

### `pair` (controller → host)

Exactly one of `code` (the 4 digits shown on the host) or `token` (from an earlier `pair_result`). Sending both or neither is a protocol error.

### `pair_result` (host → controller)

- Accepted: `{"ok": true, "token": "<32 hex>"}`. The controller saves the token for this `hostId`.
- Refused: `{"ok": false, "reason": "<reason>"}`:
  - `wrong_code`: the host then closes with 4001.
  - `too_many_attempts`: 5 wrong codes in a row; the host shows a new code and closes with 4001.
  - `unknown_token`: the host doesn't know this token (forgotten, or another install). The connection stays open for a code.

Until a controller is paired the host accepts only `hello`, `pair`, `ping` and `pong`, and ignores input.

### `player` (host → controller)

`{"n": 1}`: the controller's player number (from 1), sent after pairing and whenever it changes. Colours by number (ARGB): 1 `0xFF5AAAFF`, 2 `0xFFFFA040`, 3 `0xFFD27CFF`, 4 `0xFF4DE0C0`, 5 `0xFFFF6F91`, 6 `0xFFE8E86A`, then repeating. A number stays reserved for a minute after its controller drops, so a short Wi-Fi drop doesn't swap players. Players on the host itself (a keyboard) take numbers too.

## 6. Heartbeats and latency

- Both sides send `ping` every second: `{"id": <int>, "sentAt": <int>}`, with `sentAt` on the sender's own monotonic clock in ms.
- The receiver answers at once with `pong`: `{"id", "sentAt"}` echoed, plus `at` (optional, the answerer's clock in ms when it answered).
- Each side measures the round trip on its own clock. Silence (no message of any kind) for **4 seconds** means the connection is gone (4004).
- **One-way input delay.** The host estimates the offset between the two clocks from the pong with the shortest round trip in the last 20 s: `offset = at - (sentAt + received) / 2`. An `input` carrying `ts` (the phone's clock when sent) then took `received - (ts - offset)` ms. Half that best round trip is the error bound.
- **Stages** (named so later hosts can add their own): `sent_to_received` (the estimate above) and `received_to_drawn` (from arrival to the first frame built with the input, measured by the game). Phone hosting adds `snapshot_received` and `frame_drawn_joined` in M12.

## 7. Input (controller → host)

`input` carries the whole state on every change, never events, so a lost release can't leave a button stuck.

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `seq` | int | yes | Grows with every state on a connection. The host drops anything not newer |
| `buttons` | list of strings | yes | Held buttons: `a`, `b`, `x`, `y`, `start`, `select`, `lb`, `rb`. Unknown names are ignored |
| `dx`, `dy` | int | yes | D-pad, each -1, 0 or 1 (`dy` -1 is up) |
| `ax`, `ay` | number | no, as a pair | Gyro tilt, -1 to 1 (gyro mode only) |
| `lx`, `ly`, `rx`, `ry` | number | no, as pairs | Left and right sticks inside the unit circle (stick mode only) |
| `ts` | int | no | The phone's clock in ms when sent (§6) |

Analog values are rounded to 3 decimals. Rules: the controller sends its full state again after every (re)pairing; it releases everything when the app leaves the foreground; the host treats a dropped connection as all released. Stick and tilt movement is capped at about 60 states a second; buttons and the D-pad go at once.

### Standard gamepad mapping (P4)

Hosts present every controller as one Xbox-style gamepad, whatever the mode, so games and bridges read every player the same way (`GamepadState` in `packages/connection`):

| Gamepad | D-pad mode | Gyro mode | Stick mode |
| --- | --- | --- | --- |
| A, B, X, Y, LB, RB, Select (View), Start (Menu) | `buttons` | `buttons` | `buttons` |
| D-pad up/down/left/right | `dy`, `dx` | none | `dy`, `dx` |
| Left stick | centered | `ax`, `ay` | `lx`, `ly` |
| Right stick | centered | centered | `rx`, `ry` |
| Extra: raw tilt | none | `ax`, `ay` | none |

Stick y is -1 up, as on the wire. A keyboard on the host (S2) maps its keys onto the same gamepad.

## 8. Haptics (host → controller)

`haptic`: `{"event": "<name>", "intensity": <0..1>, "ms": <20..3000>}`. Events: `hit` (100 ms natural length), `success` (450), `error` (300), `rumble` (a steady buzz for `ms`). `intensity` scales the pattern and `ms` stretches it in time. A controller ignores event names it doesn't know. The phone applies its own settings (off, per-event strength) on top.

## 9. Metrics (capability `metrics`)

### `metrics` (controller → host)

The touch metrics of one **mode segment**: a stretch of time in one input mode with one set of settings. Each batch holds the segment's totals so far, so the newest batch is the whole truth and a repeated or lost batch does no harm.

| Field | Type | Meaning |
| --- | --- | --- |
| `seg` | string | Segment ID, unique per install (random prefix + counter) |
| `i` | int | Batch number within the segment; the host keeps the highest |
| `mode` | string | `dpad`, `gyro` or `sticks` |
| `ms` | int | How long the segment has lasted |
| `end` | bool | True on the segment's last batch (mode or settings change, recording stops) |
| `data` | object | The counters, below |

Timing: about every 10 s, on every mode or settings change, and at disconnect. The controller keeps every batch not yet acknowledged (the newest per segment, up to 64 segments) and sends them again after each reconnect. Batches stay under about 4 KB.

`data` (defined in `packages/metrics`, `SegmentRecorder`): `v` (1), `start` (ms since the phone began recording, for "switched within the first minute"), `touches`, and optional maps of counts: `presses`, `pressMs` (total held time), `pressMaxMs` (by control: button names, `dpad`, `ls`, `rs`), `empty` (taps on no control, by cell `"column,row"` of a 6 by 3 grid over the controller area), `near` (empty taps within 8 mm of a control, by the nearest control), `slide` (a finger that started on a control slid off it), `rapid` (4 or more taps within 6 mm in 1 s, by control or `empty`), `multi` (how many controls were held when a new one was pressed), `haptics` (events received, by name), `settings` (the settings in effect: numbers and booleans), `sticks` (`ls`/`rs`: `touchMs`, `deadMs`, `fullMs`, `reversals`) and `gyro` (`touchMs`, `deadMs`, `fullMs`, `reversals`, `recal`). Only counts: never a touch trace, never text. The host drops anything else (`sanitizeSegmentData`).

### `metrics_ack` (host → controller)

`{"seg", "i"}`: that batch arrived. Once the last batch of an ended segment is acknowledged, the controller forgets the segment.

## 10. Rating (capability `rating`)

- `rate_ask` (host → controller): `{"id": "<string>", "game": "arena"}`. The host decides when: after a game, first after the third, then at most once every 5 games and 3 minutes per player.
- `rating` (controller → host): `{"id": <echoed>, "face": "good" | "okay" | "bad", "tags": [...]}`. No `face` means skipped (also after 20 s). Tags: `buttons_too_small`, `laggy`, `hard_to_steer`, `rotation_hard`; others may come from newer apps. An unknown face counts as skipped.

## 11. Message direction summary

| Type | Direction | Needs |
| --- | --- | --- |
| `hello`, `pair`, `input` | controller → host | |
| `welcome`, `pair_result`, `player`, `haptic` | host → controller | |
| `ping`, `pong` | both | |
| `metrics`, `rating` | controller → host | host listed `metrics` / `rating` |
| `metrics_ack`, `rate_ask` | host → controller | controller listed `metrics` / `rating` |

A host that receives a host-only message (or the reverse) closes with 4003; a controller ignores it.

## 12. Timing summary

| What | Value |
| --- | --- |
| Heartbeat | every 1 s, both ways |
| Dropped after | 4 s of silence |
| Unpaired connection closes after | 5 minutes |
| Wrong codes before a new code | 5 |
| Reconnect backoff (controller) | 0.25, 0.5, 1, 2, then every 3 s, forever, with the token |
| Analog input | at most about 60 states a second |
| Metrics batches | about every 10 s, plus mode changes and disconnect |
| Player number kept for | 1 minute after a drop |

The game host interface (`GameHost` in `packages/connection`, PRD v2 P3) is the in-process side of this: games get players, gamepads, haptics, rating prompts, latency and analytics records from it, and never touch the protocol directly.
