# Thumb Party protocol

Version 1, as built in M9 and extended in M10, M11 and M12 (Thumb Party 0.12.0). This is the contract between a controller (the phone app) and a host (the TV app on Android TV or Windows, or the phone app hosting a game since M12). It's written so another host or controller (an engine kit, a PC bridge, a v3 receiver) can be built from it alone. The code that implements it is `packages/protocol` (messages, codec) and `packages/connection` (server, client); every field below can be checked there.

## 1. Discovery

The host advertises a DNS-SD service on the local network:

| Item | Value |
| --- | --- |
| Service type | `_gamectl._tcp` (iOS needs it in `NSBonjourServices`) |
| Instance name | `Thumb Party TV (<host name>)` for the TV app, `Thumb Party on <phone name>` for a phone host (M12); may get a suffix if taken |
| Port | `45780`, or any free port if that's taken (the advertised port is the truth) |
| TXT `id` | The host's stable random ID (hex) |
| TXT `v` | The protocol version, `1` |
| TXT `kind` | M12: `tv`, `pc`, `phone` or `tablet`. Left out by older hosts |

A phone's host list shows a phone or tablet as such from `kind`; a host without it shows as a TV, which is what every host looked like before M12.

A controller may also connect to an address the user types (`IP` or `IP:port`, port 45780 by default). The TXT `id` lets the controller know a host it has paired with before, even at a new address.

Any HTTP request to the port other than the WebSocket upgrade gets a short plain-text page, so a browser can check the host is reachable.

## 2. Transport and framing

- **On the network**: one WebSocket per controller, `ws://<address>:<port>/ws`. The controller connects (the host only listens). Roles (§5) are separate from this: a future display may be the side that connects out.
- **Inside one process** (M12): the host phone's own player reaches the host over a local channel, which carries the same messages in the same order. It has no network address, and the host marks it `local`. Pairing, tokens, heartbeats and close codes are the same on both: the own player pairs with the host's current code like a phone on the Wi-Fi.
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
| `layout` | `layout` (host → controller): the game's labels, hidden buttons and modes | M10 |
| `status` | `status` (host → controller): the phone's status panel | M10 |
| `view` | `view_start`, `frame`, `view_end`, `host_away`, `host_back`, `player_away` and `player_back` (host → controller): the game itself, for a controller that shows it (§10a) | M12 |

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
| `appVersion` | string | yes | e.g. `0.10.0` |
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

`{"n": 1}`: the controller's player number (from 1), sent after pairing and whenever it changes. Colours by number (ARGB): 1 `0xFF2E9BF0`, 2 `0xFFFF8A1F`, 3 `0xFFA66CFF`, 4 `0xFF14C8A0`, 5 `0xFFFF5C8A`, 6 `0xFFF2C200`, then repeating. A number stays reserved for a minute after its controller drops, so a short Wi-Fi drop doesn't swap players. Players on the host itself (a keyboard, or the host phone's own player) take numbers too.

## 6. Heartbeats and latency

- Both sides send `ping` every second: `{"id": <int>, "sentAt": <int>}`, with `sentAt` on the sender's own monotonic clock in ms.
- The receiver answers at once with `pong`: `{"id", "sentAt"}` echoed, plus `at` (optional, the answerer's clock in ms when it answered).
- Each side measures the round trip on its own clock. Silence (no message of any kind) for **4 seconds** means the connection is gone (4004).
- **One-way input delay.** The host estimates the offset between the two clocks from the pong with the shortest round trip in the last 20 s: `offset = at - (sentAt + received) / 2`. An `input` carrying `ts` (the phone's clock when sent) then took `received - (ts - offset)` ms. Half that best round trip is the error bound.
- **Stages** (named so later hosts can add their own): `sent_to_received` (the estimate above) and `received_to_drawn` (from arrival to the first frame built with the input, measured by the game). A phone that shows the game adds `touch_to_frame` and `frame_jitter` (§10a), sent in its metrics batches (§9).

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

`haptic`: `{"event": "<name>", "intensity": <0..1>, "ms": <20..3000>}`. Events: `hit` (100 ms natural length), `success` (450), `error` (300), `rumble` (a steady buzz for `ms`), and since M10 `snap` (160, a piece locks in place), `wrong` (260, a piece dropped in the wrong place), `dropReady` (40, a carried piece is close enough to drop), `tick` (30) and `help` (320, M11: a teammate is carrying a big piece alone and needs you). `intensity` scales the pattern and `ms` stretches it in time. A controller ignores event names it doesn't know (apps before 0.10.0 ignore the M10 events), so these need no capability. The phone applies its own settings (off, per-event strength) on top.

Game sounds are not part of the protocol: a game plays them by event name through the game host (PRD v2 S5), and the TV plays its own copy.

## 8a. Game-defined controls (capability `layout`)

`layout` (host → controller), per player, whenever a game starts or stops using its own controls:

```json
{"type": "layout", "modes": ["dpad", "gyro", "sticks"], "default": "dpad",
 "labels": {"a": "Pick up", "x": "Rotate ⟳", "y": "Rotate ⟲"},
 "hidden": ["b", "lb", "rb", "select", "start"]}
```

| Field | Meaning |
| --- | --- |
| `modes` | The modes the player may use. Empty: all. The player still picks among them |
| `default` | Optional. The mode the phone switches to if its current one isn't allowed |
| `labels` | A short label per button (cut to 12 characters). The phone draws it inside the button, under the letter, or instead of the Start/Select/LB/RB text |
| `hidden` | Buttons the game doesn't use. The phone shows a faint outline (face buttons) or nothing, and sends no presses for them |

An empty layout (`{"modes": [], "labels": {}, "hidden": []}`) puts the phone back to its usual buttons, and the phone also goes back to them when it disconnects. A switch the game forces isn't saved as the player's mode; after the game the phone returns to the player's own. Unknown modes and buttons are ignored. The host remembers each player's layout and sends it again after a reconnect.

## 8b. Status panel (capability `status`)

`status` (host → controller), per player:

```json
{"type": "status", "text": "1:23 left", "progress": 0.7, "warning": false,
 "shape": {"points": [[0, -1], [1, 1], [-1, 1]], "color": 4290787371, "angle": 30}}
```

| Field | Meaning |
| --- | --- |
| `text` | Optional, at most 24 characters |
| `shape` | Optional. `points`: up to 16 corners, each from -1 to 1 around the middle (y down); or `{"circle": true}`. `color` is 0xAARRGGBB, `angle` clockwise in degrees |
| `progress` | Optional, 0 to 1 (rounded to hundredths) |
| `warning` | Optional; true shows the panel in the warning colour |

A status with none of `text`, `shape` and `progress` hides the panel. The host sends at most 10 a second per controller; when it has to wait, the newest status is sent once the gap has passed. The phone shows the panel in its top bar, in the ping's place, so no control gets smaller. The puzzle sends the held piece (turning as it turns) and the time left.

The host closes the connection with 4003 if a controller sends `layout` or `status`.

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
| `stages` | object | Optional (M12). Stage name → list of ms integers, at most 256 per stage: a viewer's own samples (`touch_to_frame`, `frame_jitter`). The host feeds each one into its stage statistics, as if the host had measured it. Unknown stage names are kept; more than 256 samples of one stage is a protocol error. Left out when empty |
| `view` | object | Optional (M12). `{"frames": n, "gaps": n, "late": n}`: the frames the viewer drew since its last batch, how many arrived out of step and how many it drew late. Left out when the phone doesn't show the game |

Timing: about every 10 s, on every mode or settings change, and at disconnect. The controller keeps every batch not yet acknowledged (the newest per segment, up to 64 segments) and sends them again after each reconnect. Batches stay under about 4 KB.

`data` (defined in `packages/metrics`, `SegmentRecorder`): `v` (1), `start` (ms since the phone began recording, for "switched within the first minute"), `touches`, `activeMs` (since m11.3: time near player activity, meaning inputs plus up to 5 s after the last one, and all of any hold; hosts and the report fall back to `ms` when it's missing), and optional maps of counts: `presses`, `pressMs` (total held time), `pressMaxMs` (by control: button names, `dpad`, `ls`, `rs`), `empty` (taps on no control, by cell `"column,row"` of a 6 by 3 grid over the controller area), `near` (empty taps within 8 mm of a control, by the nearest control), `slide` (a finger that started on a control slid off it), `rapid` (4 or more taps within 6 mm in 1 s, by control or `empty`), `multi` (how many controls were held when a new one was pressed), `haptics` (events received, by name), `settings` (the settings in effect: numbers and booleans), `sticks` (`ls`/`rs`: `touchMs`, `deadMs`, `fullMs`, `reversals`) and `gyro` (`touchMs`, `deadMs`, `fullMs`, `reversals`, `recal`). Only counts: never a touch trace, never text. The host drops anything else (`sanitizeSegmentData`).

### `metrics_ack` (host → controller)

`{"seg", "i"}`: that batch arrived. Once the last batch of an ended segment is acknowledged, the controller forgets the segment.

## 10. Rating (capability `rating`)

- `rate_ask` (host → controller): `{"id": "<string>", "game": "arena"}`. The host decides when: after a game, first after the third, then at most once every 5 games and 3 minutes per player.
- `rating` (controller → host): `{"id": <echoed>, "face": "good" | "okay" | "bad", "tags": [...]}`. No `face` means skipped (also after 20 s). Tags: `buttons_too_small`, `laggy`, `hard_to_steer`, `rotation_hard`; others may come from newer apps. An unknown face counts as skipped.

## 10a. Viewing the game (capability `view`, M12)

A controller that lists `view` also shows the game itself: the host runs the game in fixed steps and sends the phone what to draw. The messages below need the capability, so a controller without it never gets one. A host that shows the game on its own screen sends none of them: a controller that lists `view` and gets no `view_start` keeps its controller screen.

| Message | Direction | Fields (wire key: meaning) |
| --- | --- | --- |
| `view_start` | host → controller | `game`: module ID (`shape_race`, `arena`) · `sv`: the snapshot version the frames carry · `setup`: the module's setup JSON · `hz`: frames a second the host publishes |
| `frame` | host → controller | `n`: step number: `-1` for the frame a host sends before the first step while the round is held (the "Get ready" beat), then from 0 · `at`: the host's clock in ms at that step · `s`: the module's snapshot JSON · `snd`: sound names since the last sent frame, left out when empty · `acks`: player ID → the last input seq the host applied (only players with one) · `pl`: player ID → `[number, name]`, the name `""` when the player has none |
| `view_end` | host → controller | `reason`: `finished` (the game ended), `quit` (someone left) or `abandoned` (the game stopped without ending: the host closed, the connection dropped, a new game started) |
| `host_away` | host → controller | `s`: whole seconds left before the round ends if the host stays away (0 or more) |
| `host_back` | host → controller | no fields |
| `player_away` | host → controller | `player`: player ID, as in a frame's `pl` · `n`: the player's number, from 1 · `s`: whole seconds left before the game goes on without them (0 or more) |
| `player_back` | host → controller | `player`: player ID: the player is back, or the grace is over and the game went on without them |

`view_start` comes first, `view_end` last, and each `frame` between them carries one step of the game, sent `hz` times a second. Before the first step, a host that holds a round (the "Get ready" beat) sends one frame with `n` `-1`: the board at step 0, with the `s`, `pl` and `acks` a step's frame has and no `snd`. It goes out whether or not a viewer has paired yet, so a viewer that pairs during the beat gets it after `view_start` and draws the held board. No frame follows while a round is held or paused, and the next one carries step 0. An older viewer reads `-1` → `0` as no gap and draws that frame as it draws any other. The host encodes each frame once and sends every viewer the same text.

**`view_start`'s `setup`** belongs to the module. Shape Race sends `puzzle` (the puzzle file's ID), `level` (`easy`, `medium` or `hard`), `timeLimitS`, `teams` (player ID → `left` or `right`) and, when the match uses the tray-on-top layout phones draw, `layout`: `phones`, left out otherwise. The Arena sends `{}`. A viewer of another app version that finds no such puzzle, or can't decode the frames' snapshot version, shows "Update the app to see this game" instead of drawing.

**Shape Race's snapshots are version 2** (M14 a1, a2): each board's JSON keeps the keys it had and may add four, left out when they are at their defaults — `nt` `1` in a party night's round, `pts` the points that board's side has earned, `pop` its live awards, oldest first, each `[side, x, y, amount, age ms, icon]`: side `0` is left and `1` right, x and y are field units to a tenth, and icon `0` is a star and `1` the flag of a finished picture, and `sd` the side that plays the board (`0` left, `1` right), which a one-board round that plays for the right needs: a board without it is the side of its place in `b`. A pop-up lives 1.2 s, so a board's `pop` holds at most 5. The keys sit inside each board, so a race's frame carries a `pts` and a `pop` per side, and `setup` carries nothing new.

Beside the boards a frame carries `cat` while the cat is out (M14 a2), and no `cat` means no cat: `[state, side, x, y, warning ms, target]`, state `0` warning, `1` walk, `2` bat and `3` leave, side `0` left and `1` right, x and y field units to a tenth, `warning ms` the ms of warning still to come, and `target` the index in `pc` of the piece it is after, `-1` for none. It is a frame's own key, like its `b`, so it says nothing about a board the other side plays.

A phone one build older compares `sv` `2` with the version 1 it knows and shows "Update the app to see this game" rather than drawing a frame it would read wrongly.

**Sounds.** `snd` lists the sound names a step played, and a phone plays them from its own copy when it draws the frame that carries them, so every phone hears the game. Haptics stay per-player messages (§8).

**Waiting for the host.** While it shows a game, a host that goes away (its app is hidden, the screen locks) sends `host_away` with the seconds left; `host_back` means the game goes on and the frames come back. The host's grace is 30 s, and a round that outlives it ends with `view_end` `abandoned`. A phone whose link to the host drops while it shows a game counts 30 s down by itself, because a suspended host can't send anything.

**Waiting for a player.** A player who drops while a round runs keeps their place for 30 s, and the game waits for them: the frames stop, so the others learn why. The host sends `player_away` with that player's number and the seconds left, and `player_back` when the player is back, when the grace is over with the game going on without them, or when someone on the host screen says to go on. The messages go to the viewers of a running view, like `host_away`; the phone that was away is not told it is back.

**`at`.** A step's `at` is the host's clock when the frame is published minus the game time still to simulate after that step, rounded to ms. Steps run inside one drawn frame therefore get evenly spaced times, and a stall or a pause shows up as real time passing. A phone measures a frame's **skew** as its arrival on the phone's own clock minus `at`; the fastest arrival of the last 2 s sets the base and every later frame's jitter is its skew above the base. The phone draws after a playout delay worked out from those jitters, so the host's clock never has to be estimated.

**A viewer that pairs while a game is being shown** — a controller that just joined, or one that reconnected after a drop — gets the stored `view_start` and then the latest `frame`, before any later frame, so it can draw the game at once. A viewer that pairs while the game waits for players gets a `player_away` for each of them after those two, so it can say why the frames have stopped. A viewer that pairs after `view_end` gets nothing. A viewer sends its measurements back in its metrics batches (§9): the raw samples in `stages` and its frame counts in `view`.

The host closes with 4003 if a controller sends one of these view messages.

## 11. Message direction summary

| Type | Direction | Needs |
| --- | --- | --- |
| `hello`, `pair`, `input` | controller → host | |
| `welcome`, `pair_result`, `player`, `haptic` | host → controller | |
| `ping`, `pong` | both | |
| `metrics`, `rating` | controller → host | host listed `metrics` / `rating` |
| `metrics_ack`, `rate_ask` | host → controller | controller listed `metrics` / `rating` |
| `layout`, `status` | host → controller | controller listed `layout` / `status` |
| `view_start`, `frame`, `view_end`, `host_away`, `host_back`, `player_away`, `player_back` | host → controller | controller listed `view` |

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
| Status panel | at most 10 a second per controller |
| Frames to a viewer | 20 to 60 a second, 60 by default (`view_start`'s `hz`) |
| Host away before the round ends | 30 s (the host's grace) |
| A player away before the round goes on | 30 s (the same grace, per player) |
| Shortest press a game sees | 50 ms (the host keeps a quick tap held that long) |

The game host interface (`GameHost` in `packages/connection`, PRD v2 P3) is the in-process side of this: games get players, gamepads, haptics, sounds, layouts, the status panel, rating prompts, latency and analytics records from it, and never touch the protocol directly. Games read each gamepad once a frame; so that a tap whose press and release arrive between two frames isn't lost, the host reports every press as held for at least 50 ms.
