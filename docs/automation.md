# The automation interface (M15)

Every host build carries one small HTTP API: the Windows, Linux and Android TV apps and the phone in host mode. It is the same code in `packages/party_host` (`lib/src/automation/`), so a script that works against the TV works against a phone hosting. It starts games, adds **simulated players**, sends their input, reads the state, takes screenshots, shows the latency test card and takes the stream measurements of job p1.

It is **off by default**. The code is compiled into every build, release included, and does nothing until a launch switches it on; a store build has nothing that switches it on, so nothing listens and no port is opened.

Scripts use [`tools/automation.dart`](../tools/automation.dart) or plain HTTP; [`tools/demo-run.sh`](../tools/demo-run.sh) is a worked example that starts a Bumper Round with two simulated players and takes a screenshot.

## Switching it on

| Host | How it turns on |
| --- | --- |
| Windows, Linux and Android TV desktop builds | `THUMBPARTY_AUTOMATION=1` in the environment, or `tools/tv-dev.sh start --automation` for the dev copy (which passes `--dart-define=AUTOMATION=true`) |
| An Android TV or TV build made with Flutter | `flutter build ... --dart-define=AUTOMATION=true` |
| The phone app in host mode | the same `--dart-define=AUTOMATION=true` (a phone has no environment of its own) |

A build starts listening only once its settings say so, and logs `Automation listening on 127.0.0.1:8787` (or the line saying why it couldn't, e.g. `Automation is off: automation listens on 0.0.0.0, so it needs a token (THUMBPARTY_AUTOMATION_TOKEN)`). A port already taken is logged and the host keeps hosting: automation being unavailable never stops the game.

| Variable | What it does |
| --- | --- |
| `THUMBPARTY_AUTOMATION=1` | switches the interface on (the only value that does) |
| `THUMBPARTY_AUTOMATION_PORT` | the port to listen on (8787 unless set; `0` asks the system for a free one) |
| `THUMBPARTY_AUTOMATION_BIND` | the address to listen on (`127.0.0.1` unless set: a container sets `0.0.0.0` so the sampler and the published port reach it, which requires a token) |
| `THUMBPARTY_AUTOMATION_TOKEN` | the shared token every request must carry when set, and required whenever the bind address isn't loopback |
| `THUMBPARTY_PORT` | pins the **controller** port: the host listens on exactly that port and fails loudly if it is taken, instead of taking a free one. `status` reports the port in use |
| `THUMBPARTY_STATS_CONSENT=no` | answers the first-run stats question "no" at start, so the home screen is clear in a session without a person. There is no value that answers yes: sharing stays an adult's choice |

## Security

- **Loopback only by default.** Nothing on the network can reach it unless a launch sets `THUMBPARTY_AUTOMATION_BIND`, and a bind beyond this machine without a token is refused rather than started weakly. A streamed session is the exception: its entrypoint asks for `0.0.0.0` (the player page's relay and the bench both call it from the session's own network), so inside a session the token and the owner's firewall are what keep it closed (`streaming/README.md`).
- **A failed bind is said on screen.** The host's Stats screen shows one line, `Automation could not start: <reason>`, and it goes when a later bind succeeds, when the server stops or when its provider is rebuilt (M15 g1).
- **A token when the launch sets one**, in `x-automation-token` or `Authorization: Bearer …`; a request without it gets a 401 before anything happens.
- **No environment default answers the stats question "yes"**: `POST settings` answers it only when a script asks, and neither the interface nor the environment turns sharing on.
- **A body is at most 64 KB**, and a body over the cap is refused whole: no field of it is applied (M15 g1). A request that **declares** a longer length is refused from that number alone, without any of it being read, with a 400 saying `the body is too long`; the client sees the 400 once it has sent the body (the host answers while the body is still arriving, and a client that declares a length and sends nothing waits on an open socket). A body with no declared length (chunked) is read only until a chunk would pass the cap, and then the answer goes out with the connection closing after it: a script already writing past the cap may see the close instead of the 400, because the rest is not read to hand the answer over.
- **The player page relay forwards what the page measures, and nothing else.** The session's relay (`streaming/player/serve.py`) posts the page's `stats/stream` batches and reads the host's clock from `GET status`, with the session's token; no other call is relayed, so anyone who can open the player page can write measurements into its session's stream record and nothing else — no input, no player, no setting, no game. The record holds technical numbers only (`docs/protocol.md` §13). A host that shouldn't be measured keeps the interface off.
- **It is a development tool**: start it for a measuring run, a demo or a test, and leave it off otherwise.

## The calls

Every call starts with `/automation/v1`; the examples use the default `http://127.0.0.1:8787`. Answers are JSON with `"ok": true`, or `"ok": false` and an `"error"` saying what to change, with a 400 (a body it can't use), 401 (no token), 404 (no such call), 405 (the wrong method), 409 (nothing to take a picture of) or 500 (the host couldn't). Add `-H "x-automation-token: $THUMBPARTY_AUTOMATION_TOKEN"` when the host has a token.

### GET status

The app's version, host type, the screen now, whether a round runs, the players, the pairing code, the controller port and whether the host is ready. The host's clock (`hostMs`, the number `probe/press` answers and a viewer's times are kept on) and the frames it has drawn (`frames.drawn`, a counter since the app started) come with it, so a sampler can read the game's own frame rate between two calls.

A reading also carries the game's own frame times since the previous reading (`frames.buildMs`, `frames.rasterMs`, `frames.vsyncMs`, `frames.slow` of `frames.count`, M15 k1): taking them empties the window, so a sampler reads them once per window and nobody else does. A press through `probe/press` leaves its way through the host behind (`probe.legs`): the newest 32 presses, each with its number `n` and the stamps `pressMs`, `tickMs`, `builtMs` and `rasterMs` of its arrival, of the frame that could first use it and of that frame being built and rasterised. The sampler takes the presses above the last `n` it read and writes them as the `host_tick`, `host_build` and `host_raster` stages beside the pipeline's own.

```bash
curl -s http://127.0.0.1:8787/automation/v1/status
```

```json
{"ok":true,"version":"0.14.0","app":"0.14.0 (37)","hostType":"windows","hostName":"Living room",
 "screen":"home","round":false,"ready":true,"pairingCode":"481204","port":45780,"hostMs":412345,
 "frames":{"drawn":850},"players":[{"id":"p1","number":1,"nickname":"Ada","simulated":false,"mode":"dpad"}]}
```

### POST players

Adds a simulated player through the host's own local-player path (so it works every screen a phone can, menus included), or removes one. A character is a colour 1–6 and an accessory (`ears`, `antenna`, `bow`, `cap`, `tuft`, `crown`).

```bash
curl -s -X POST http://127.0.0.1:8787/automation/v1/players \
  -d '{"nickname":"Robo","character":{"colour":3,"accessory":"antenna"}}'
curl -s -X POST http://127.0.0.1:8787/automation/v1/players -d '{"remove":"local-1"}'
```

```json
{"ok":true,"player":{"id":"local-1","number":2,"nickname":"Robo","simulated":true,"mode":"dpad",
 "character":{"colour":3,"accessory":"antenna"}}}
```

### POST input

A press, a release or a stick position for a simulated player: the shape controllers send (`buttons` are `a`, `b`, `x`, `y`, `lb`, `rb`, `select`, `start`; `dx`/`dy` are the D-pad, -1 to 1; `lx`/`ly` and `rx`/`ry` are the sticks). An empty button list releases. `player` may be left out when the host has one simulated player. The same call works the menus, so a script drives every screen.

```bash
curl -s -X POST http://127.0.0.1:8787/automation/v1/input -d '{"buttons":["a"]}'
curl -s -X POST http://127.0.0.1:8787/automation/v1/input -d '{"player":"local-1","dy":1}'
curl -s -X POST http://127.0.0.1:8787/automation/v1/input -d '{"lx":0.5,"ly":-1}'
```

```json
{"ok":true,"player":"local-1","hostMs":51230}
```

### POST game/start

Starts a game without the menus. `game` is `arena` or `shape_race`. The arena takes `mode` (`race` or `bumper`) and `map` (a map id, or leave it out for Surprise me); Shape Race takes `puzzle` (an id) and `level` (`easy`, `medium` or `hard`) and `teams`, each side by player number. `settings` carries `chaos` (`off`, `little`, `party`), `robo` (`easy`, `medium`, `hard`) and `night` (`rounds`: 3 or 5, which starts a party night instead of one round). Fields a game doesn't have are refused.

```bash
curl -s -X POST http://127.0.0.1:8787/automation/v1/game/start \
  -d '{"game":"arena","mode":"bumper"}'
curl -s -X POST http://127.0.0.1:8787/automation/v1/game/start \
  -d '{"game":"shape_race","level":"easy","teams":{"2":"left","3":"right"},"settings":{"chaos":"little"}}'
curl -s -X POST http://127.0.0.1:8787/automation/v1/game/start -d '{"game":"arena","settings":{"night":{"rounds":3}}}'
```

```json
{"ok":true,"round":{"game":"arena","mode":"bumper"}}
```

### POST game/stop

Ends the round and shows the home screen again; the latency card goes away with it.

```bash
curl -s -X POST http://127.0.0.1:8787/automation/v1/game/stop
```

```json
{"ok":true}
```

### POST settings

Changes the look (`auto`, `sunny`, `night`), the frame rate the next round runs at (20–60), sound on or off, and answers the first-run stats question (`statsConsent`: `true` or `false`). A body with none of them is refused.

```bash
curl -s -X POST http://127.0.0.1:8787/automation/v1/settings -d '{"look":"night","frameRateHz":30,"sound":false}'
curl -s -X POST http://127.0.0.1:8787/automation/v1/settings -d '{"statsConsent":false}'
```

```json
{"ok":true,"settings":{"look":"night","frameRateHz":30,"sound":false}}
```

### GET state

The current round (as `game/start` describes it), its latest frame — the same JSON a viewer draws — and the result of the round that ended last.

```bash
curl -s http://127.0.0.1:8787/automation/v1/state
```

```json
{"ok":true,"round":{"game":"arena","mode":"bumper"},
 "frame":{"n":412,"atMs":398840,"snapshot":{...},"sounds":[],"roster":{...}},
 "result":null}
```

### GET screenshot

A PNG of what the host's screen draws now. Desktop, Android TV and a phone hosting all answer; a phone that is only a controller has no interface at all, and a host with nothing drawn yet (still starting, or in the background) answers a 409 with a reason instead of a picture.

```bash
curl -s http://127.0.0.1:8787/automation/v1/screenshot -o shot.png
```

### POST probe/flash

Shows the **latency test card**: a full-screen block that flips between white and black every 500 ms and carries a frame counter and the host's clock in ms (`flip 12 · 6784 ms`). `{"on":false}` hides it; an empty body shows it. The owner can also open it from the TV's latency/stats screen ("Test card").

```bash
curl -s -X POST http://127.0.0.1:8787/automation/v1/probe/flash -d '{"on":true}'
curl -s -X POST http://127.0.0.1:8787/automation/v1/probe/flash -d '{"on":false}'
```

```json
{"ok":true}
```

### POST probe/press

Presses a button for a simulated player and returns the host's clock at that moment (`hostMs`). The press lands before the next frame, so a viewer times press → pixel change from that number: the frame counter beside the host clock flips when the press reaches the screen, and since job c2 the card's colour flips with it, so a viewer watching the picture sees the press arrive as a colour change. The button is let go on the frame after the press, so two calls a frame apart are two presses, as two taps of a thumb are (two inside one frame are one press: the release has not happened yet). The release clears the player's whole pad, so a stick or button another `input` call set just before a probe press is dropped a frame later.

```bash
curl -s -X POST http://127.0.0.1:8787/automation/v1/probe/press -d '{"player":"local-1","button":"a"}'
```

```json
{"ok":true,"player":"local-1","button":"a","hostMs":51250}
```

### POST stats/stream

The ingest end of job p1's measurements (`docs/protocol.md` §13): one batched body with a viewer and any mix of its stages, gauges, counters and facts, plus the container's own resource readings. It lands in the live session's summary — no upload, no consent needed — and answers the viewer id it went to. A malformed body is refused whole, however far down it the bad item is. When no session is running the batch is dropped and the answer says so without an error — `{"ok":true,"accepted":false,"reason":"no session"}` — so a sampler that starts before the first player joins keeps sending and needs no special case.

```bash
curl -s -X POST http://127.0.0.1:8787/automation/v1/stats/stream -d '{
  "viewer":{"kind":"browser","platform":"chrome"},
  "stages":[{"name":"stream_encode","ms":10,"fps":60},{"name":"stream_network","ms":14,"fps":60}],
  "gauges":[{"name":"bitrateSentKbps","value":6100}],
  "counters":[{"name":"framesSent","value":1000}],
  "facts":[{"name":"codec","value":"h264"}],
  "resources":[{"cpuPct":50,"memMb":840,"gameFps":60}]
}'
```

```json
{"ok":true,"viewer":"v1"}
```

A viewer that keeps reporting sends its id back (`"viewer":"v1"`) instead of the object, so the player that sent the first batch and the sampler beside it keep writing to one row; an id the session never gave out is refused rather than landing nowhere.

### GET stats/session

The live session's summary so far, whether one runs, and the stats consent, so a script reads the numbers without the upload.

```bash
curl -s http://127.0.0.1:8787/automation/v1/stats/session
```

```json
{"ok":true,"running":true,"consent":false,
 "session":{"schema":1,"id":"…","players":[…],"stream":{"viewers":[…]},…}}
```

A session only simulated players joined carries `"simulated": true` in its summary and is never uploaded, with or without consent. The summary keeps at most 8 viewers and 16 series per viewer, which a full summary with a stream record stays under the PRD's 50 KB budget with.

## A press's way through the host

Whatever sets a player's pad, the game reads it on the next frame it draws and can show it on that same frame. A scripted press (`input`, `probe/press`) sets the pad and asks for that frame itself, so it lands in the first frame the screen can show it, also on a screen that would otherwise draw nothing (M15 g1, k3). A phone's press arrives at the host's connection, becomes a host-state change, and is drawn by the next frame the game or the menus draw, which a round's view does every frame. The host's own view paints the session's current snapshot right after the game's `advance` read the pads; the playout buffer that holds frames back belongs to the phone, not the host.

## What it replaces

The debug-only start flags are now thin wrappers over the same code paths, and keep working for the existing tools:

| Flag | Today | Deprecated in favour of |
| --- | --- | --- |
| `START_GAME=arena\|shape_race` | opens the game as the app's home screen (`AutomationGameScreen`, the same screen `POST game/start` pushes) | `POST game/start` |
| `FRAME_RATE_HZ=20\|30\|60` | the host's frame rate, the same settings path `POST settings` sets (`frameRateHz`) | `POST settings` |
| `SHARE_VIEW=true` | lets the phones that join show the hosted game (the `shareViewProvider` path); no automation call changes it | still a build define |

`tools/tv-dev.sh start --game` and `--hz` still pass the first two; `--automation` is the new one. A README in a script that uses them keeps working, but new scripts should use the API.

## The script client

```bash
dart tools/automation.dart status
dart tools/automation.dart players --nickname Ann
dart tools/automation.dart input --player local-1 --buttons a
dart tools/automation.dart start --game arena --mode bumper
dart tools/automation.dart screenshot --out shot.png
dart tools/automation.dart stop
```

`--url` (or `THUMBPARTY_AUTOMATION_URL`) points it at another address, `--token` (or `THUMBPARTY_AUTOMATION_TOKEN`) supplies the token, and `--help` lists the calls. `tools/demo-run.sh` runs a whole session: it adds two simulated players, starts a Bumper Round, waits three seconds, prints the state, saves `automation-demo.png`, prints the session summary and stops the round.

## How it is built

| Part | File |
| --- | --- |
| The wire: paths, methods, token, body limit, answers | `packages/party_host/lib/src/automation/automation_server.dart` |
| What each call does, over the host's own providers | `packages/party_host/lib/src/automation/host_automation.dart` |
| The switch and its settings | `packages/party_host/lib/src/automation/automation_settings.dart` |
| The start a call asks for, shared with the debug flags | `packages/party_host/lib/src/automation/automation_game_start.dart` |
| The frame a screenshot captures | `packages/party_host/lib/src/automation/screen_frames.dart` |
| The ingest reader for `stats/stream` | `packages/party_host/lib/src/automation/stream_ingest.dart` |
| A press's way through the host (`probe.legs`) | `packages/party_host/lib/src/automation/probe_leg.dart` |
| The game's frame times (`frames.*`) | `packages/party_host/lib/src/automation/frame_timing.dart` |
| The shell: the boundary, the card, pushing a round | `packages/party_host/lib/src/ui/automation_gate.dart` |
| The card | `packages/party_host/lib/src/ui/latency_test_card.dart` |

Each host app passes its own settings in `main()` (`automationSettingsProvider`, `controllerPortProvider`) and wraps its app in `AutomationShell`: `tv_test_app/lib/main.dart`, `controller_app/lib/main.dart`. The wire and the actions are tested apart: `automation_server_test.dart` drives the HTTP side with a fake API, `automation_api_test.dart` drives the real actions through a host widget.
