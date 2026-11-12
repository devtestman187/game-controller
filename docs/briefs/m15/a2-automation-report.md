# M15 a2: the automation interface in shared host code: report

One automation interface lives in `packages/party_host/lib/src/automation/`, so the Windows, Linux and Android TV
builds and the phone in host mode share it. It is compiled into every build and **off by default**: a launch has to
switch it on, and nothing in a store build does. Its wire and its actions are separate (`AutomationServer` /
`AutomationApi` / `HostAutomation`), which is what the two test files drive apart.

The full API, with a curl example for each call, is in [docs/automation.md](../../automation.md). The short form:

| Call | What it does | Example |
| --- | --- | --- |
| `GET status` | version, host type, screen, round, players, pairing code, controller port, ready | `curl -s localhost:8787/automation/v1/status` |
| `POST players` | add a simulated player (`nickname`, `character`), or `{"remove":"local-1"}` | `curl -s -X POST localhost:8787/automation/v1/players -d '{"nickname":"Robo"}'` |
| `POST input` | a press, release, D-pad or stick for a simulated player, menus included | `curl -s -X POST localhost:8787/automation/v1/input -d '{"buttons":["a"]}'` |
| `POST game/start` | a game without the menus: `game`, `mode`, `map`, `puzzle`, `level`, `teams`, `settings.chaos/robo/night` | `curl -s -X POST localhost:8787/automation/v1/game/start -d '{"game":"arena","mode":"bumper"}'` |
| `POST game/stop` | back to the home screen, card off | `curl -s -X POST localhost:8787/automation/v1/game/stop` |
| `POST settings` | `look`, `frameRateHz` (20–60), `sound`, `statsConsent` | `curl -s -X POST localhost:8787/automation/v1/settings -d '{"frameRateHz":30}'` |
| `GET state` | the round, its latest frame (a viewer's JSON), the last result | `curl -s localhost:8787/automation/v1/state` |
| `GET screenshot` | PNG of the host's frame, or a 409 when nothing is drawn | `curl -s localhost:8787/automation/v1/screenshot -o shot.png` |
| `POST probe/flash` | show or hide the latency test card (`{"on":false}` hides) | `curl -s -X POST localhost:8787/automation/v1/probe/flash` |
| `POST probe/press` | a button press for a simulated player, answering the host's clock (`hostMs`) | `curl -s -X POST localhost:8787/automation/v1/probe/press -d '{"button":"a"}'` |
| `POST stats/stream` | one batched body of a viewer's stages, gauges, counters, facts and the container's resources | see docs/automation.md |
| `GET stats/session` | the live session summary, `running`, `consent` | `curl -s localhost:8787/automation/v1/stats/session` |

Answers are `{"ok":true,…}`, or `{"ok":false,"error":…}` with 400/401/404/405/409/500. A body is read field by field
(`automation_body.dart`), so a script gets "the body needs "game"" rather than a stack trace, and a bad body is
refused whole.

## How each host type turns it on

| Host | Switch |
| --- | --- |
| TV / Windows / Linux desktop build | `THUMBPARTY_AUTOMATION=1` in the environment, or `tools/tv-dev.sh start --automation` (`--dart-define=AUTOMATION=true` for the dev copy) |
| An Android TV build made with Flutter | `flutter build … --dart-define=AUTOMATION=true` |
| Phone in host mode ("Play on this phone" / "Show on this device") | the same `--dart-define=AUTOMATION=true`; the phone has no environment of its own, so the shell passes `AutomationSettings.fromSources(env: (_) => null, buildEnabled: …)` |

The shells read the environment/defines (they alone may; `party_host` has no platform code) and pass
`automationSettingsProvider` and `controllerPortProvider` into `main()`; both apps wrap their app in `AutomationShell`
(the boundary every screenshot captures, and the card over every route) and `AutomationGate` (which pushes the round
`POST game/start` asks for). The settings themselves are in `automation_settings.dart`: off by default, listen on
`127.0.0.1:8787`, optional token, optional pinned controller port, optional stats answer.

Every host also carries `THUMBPARTY_PORT` (pin the controller port; it then fails loudly instead of taking a free
one, and `status` reports the port) and `THUMBPARTY_STATS_CONSENT=no` (answer the first-run stats question "no" at
start). There is no value that answers it "yes".

## Security choices

- **Off unless a launch says so**: `enabled` is false in `AutomationSettings`'s default; a store build never sets it,
  so no socket is opened and no timer runs.
- **Loopback by default** (`127.0.0.1`); `THUMBPARTY_AUTOMATION_BIND` moves it, and a bind beyond the machine without
  a token is refused (`AutomationSettings.problem`) rather than started weakly. The refusal is logged, the host keeps
  hosting.
- **A shared token** when set, in `x-automation-token` or `Authorization: Bearer …`, checked before dispatch (401).
- **64 KB body cap** and JSON decode in the server, the field checks in the API; nothing decoded reaches the host
  unchecked.
- **Sharing stays an adult's choice**: neither the environment nor the interface's default answers stats "yes";
  `POST settings` answers it only when a script asks.
- **Simulated sessions never leave the device**: a session only simulated players joined carries `"simulated": true`
  and the upload queue skips it, with or without consent; its numbers are still in `GET stats/session`.

## What it replaces

| Old | Now | Kept for |
| --- | --- | --- |
| `START_GAME=arena\|shape_race` (debug only) | `AutomationGameStart` → `AutomationGameScreen`, the same screen `POST game/start` pushes | `tools/tv-dev.sh start --game`; noted deprecated in docs/dev-tools.md |
| `FRAME_RATE_HZ=20\|30\|60` (debug only) | the same settings path `POST settings {"frameRateHz":…}` sets: `hostingSettingsProvider` composes `frameRateOverrideProvider` over the build's own | `tools/tv-dev.sh start --hz`; deprecated |
| `SHARE_VIEW=true` (debug only) | still the build define it was: it feeds `shareViewProvider`, the same provider a call would set (the brief's API has no share-view call) | `tools/tv-dev.sh start` always passes it |
| The Linux probe patch's private start path | `AutomationGameStart`/`AutomationGameScreen`, shared by every host | — |
| A debug-only screen | the shared `LatencyTestCard`, reachable from `POST probe/flash` and the TV's latency screen ("Test card") | — |

The debug start now lives in `tv_test_app/lib/src/debug_start.dart` as two thin functions
(`debugStart`, `debugStartScreen`) over the automation types, so a flag and a script open the same screen.

## Simulated players, stats and the budget

- `POST players` adds a local player through the host's own path (`addLocalPlayer(scripted: true)`); `GamePlayer` and
  `LocalPlayer` carry `scripted` beside `simulated`, and `ControllerMenus` lets a scripted player work the menus as a
  phone does (`!simulated && !away && (!local || scripted)`).
- `LiveStats` marks a session `simulated` when every player is simulated or scripted (`nobodyReal`), and the upload
  queue skips `summary['simulated'] == true`.
- The 50 KB budget test (p1's question 5) measured a full summary with 8 viewers and every series full at 89 KB with
  32 series per viewer; `maxStreamSeries` is now 16 (the pipeline's own 15 fit) and the test passes under 50 KB.
  docs/protocol.md §13 says 16.

## Files changed

- `packages/party_host/lib/src/automation/` (new): `automation_settings.dart`, `automation_api.dart`,
  `automation_server.dart`, `host_automation.dart`, `automation_body.dart`, `automation_game_start.dart`,
  `automation_providers.dart`, `screen_frames.dart`, `stream_ingest.dart` — the interface, its settings, the actions,
  the ingest reader.
- `packages/party_host/lib/src/ui/automation_gate.dart` (new): `AutomationShell` (frame boundary, card overlay) and
  `AutomationGate` (pushes a round, pops it, clears the launch when a round ends).
- `packages/party_host/lib/src/ui/automation_game_screen.dart` (new): the screen a `game/start` round opens (arena,
  or Shape Race with a level, puzzle and teams).
- `packages/party_host/lib/src/ui/latency_test_card.dart` (new): the flipping card, the flip number and the host clock.
- `packages/party_host/lib/src/ui/arena_round_field.dart` (new): the arena's field under `Pausable`, moved out of
  `game_screen.dart` (399 → 433 lines with the auto start; 393 after the move).
- `packages/connection/lib/src/status_throttle.dart` (new): the status panel's rate limit, moved out of
  `server_game_host.dart` (399 → 415 lines with `scripted` and `latestFrame`; 392 after the move).
- `packages/party_host/lib/src/ui/game_screen.dart`: `autoStart` (waits for the map library), the result recorded for
  `GET state`, the field drawn by `ArenaRoundField`.
- `packages/party_host/lib/src/ui/puzzle_screen.dart`: the result recorded for `GET state`.
- `packages/party_host/lib/src/providers.dart`: `frameRateOverrideProvider` composed into `hostingSettingsProvider`,
  `controllerPortProvider`.
- `packages/party_host/lib/src/host_service.dart`, `lan_listener.dart`: a pinned controller port
  (`LiveHostService(pinnedPort:)` → `LanListener(pinnedPort:)`), and `latestFrame` for `GET state`.
- `packages/connection/lib/src/transport/web_socket_listener.dart`: `pinned` — a named port is the only one tried.
- `packages/connection/lib/src/{game_host,game_types,local_player,memory_game_host,server_game_host}.dart`:
  `scripted` on local players and players, `character` on `addLocalPlayer`, `latestFrame`.
- `packages/party_host/lib/src/ui/controller_menus.dart`: the scripted-player filter.
- `packages/party_host/lib/src/live_stats.dart`, `stats_service.dart`: simulated-only marking and the skipped upload;
  the live session and the consent answer.
- `packages/metrics/lib/src/{session,stream_stats}.dart`: the `simulated` key, `maxStreamSeries` 16.
- `packages/party_host/lib/src/testing/{host_fakes,fake_stats}.dart`, `text/host_text.dart`, `lib/party_host.dart`
  (exports).
- `tv_test_app/lib/main.dart`, `src/debug_start.dart`, `src/tv_text.dart`, `src/ui/latency_screen.dart`: the TV's
  switch, its pinned port, the debug flags as wrappers, the "Test card" button.
- `controller_app/lib/main.dart`, `src/host/automation_build.dart` (new), `src/host/host_overrides.dart`: the phone's
  `--dart-define` switch, the shell, the frame-rate override.
- `tools/automation.dart` (new): the script client, one option per call.
- `tools/demo-run.sh` (new): two simulated players, a Bumper Round, a screenshot, the summary.
- `tools/tv-dev.sh`: `start --automation`, and the usage text says `--game` is deprecated.
- `docs/automation.md` (new), `docs/protocol.md` (16 series, the ingest pointer, the `simulated` key),
  `docs/dev-tools.md` (the two tools, the section, the deprecated flags).
- Tests (new): `packages/party_host/test/automation_settings_test.dart` (6), `automation_server_test.dart` (8),
  `automation_api_test.dart` (9), `packages/metrics/test/stream_budget_test.dart` (2),
  `simulated_session_test.dart` (2); `live_stats_test.dart` +1.

## Tests

Each new test was written first and failed for the missing behaviour. Assertions cover: off by default and nothing
listening; on by flag; the token required off loopback (and a bearer token); the routing table and the refusals
(400/404/405/too long); status; an added player as a local scripted player; input driving the menus to a game; start
and stop; state's frame and result; the probe's flood + press with the host's clock; the ingest landing in the
summary; the PNG (header magic) and the clean 409; simulated-only sessions marked, kept and not uploaded; the budget;
and the old `START_GAME` path still opening a game (`tv_test_app` test kept passing).

| Suite | Before | After |
| --- | --- | --- |
| connection | 290 | 290 |
| metrics | 123 | 127 |
| kit | 73 | 73 |
| host | 380 | 404 |
| phone | 463 | 463 |
| tv | 56 (1 skipped) | 56 (1 skipped) |

## Checks

`tools/check.sh format analyze kit metrics connection host phone tv`: **all passed** (format, analyze, connection 290,
metrics 127, kit 73, host 404, phone 463, tv). `tools/review.sh`: **0 fail, 14 note** (the notes are file sizes and
long members that were there before this job, plus one heuristic note on the switch expression). `tools/automation.dart`
analyzes clean at the repo's 120 columns.

The TV suite rewrites `site/shots/menus.png` and `site/shots/results.png` as a side effect of its screenshot tests;
both were restored to their committed bytes afterwards (nothing outside `allow:` is changed).

## Self-check (docs/review-rules.md part A)

1. **Every host setup**: TV/PC host and a phone hosting both switch the interface on only by their own switch and
   listen on loopback; a joined phone and a phone on "Show on this device" are not hosts here (the interface is the
   host's), and an older build ignores the new fields (`automation_settings_test`'s default and `automation_api_test`).
2. **When state starts and ends**: the server starts once at app start (off: never listens) and stops on dispose; the
   card's ticker lives with the card (shown/hidden, widget disposed); `_mapsSub` closes on the round's start and in
   dispose; `_players` entries live until `remove` or the game host drops them; the frame rate override lives for the
   run (`automation_server_test`, `automation_api_test`).
3. **New state combined with others**: the automation launch is a route pushed over the home screen; a running round
   is stopped before another starts (never stacked); `game/stop` and leaving the round clear the launch and hide the
   card; the card is an overlay, so it combines with the pause menu, host away, player away, Get ready, the results
   and a dropped link without owning any of them (`Pausable` still owns the round's pause) — the probe/card test
   shows a card drawn over a running round.
4. **Stay in the job's folder**: only the files in `allow:` changed; the two `site/shots` PNGs the test suite rewrites
   were restored.
5. **Stop rather than overstep**: no blocker; the two extractions (`ArenaRoundField`, `StatusThrottle`) were needed to
   keep `game_screen.dart` and `server_game_host.dart` under the 400-line rule after the additions.

## Decisions (low-usage mode)

- A scripted player is a local player with a `scripted` flag, rather than a new player kind: menus and games already
  know local players, and `simulated` stays what it was (a built-in simulated controller).
- `ArenaField` was already a name in `test_game`, so the moved widget is `ArenaRoundField`.
- The automation shell replaces a running round instead of stacking routes, and clears a launch when its route pops
  itself (a round that ends and leaves) so a later `status` isn't a stale `game`.
- `POST players` with a `character` needs both `colour` (1–6) and `accessory`; a colour alone is refused rather than
  guessed, as the host's own character picker always pairs them.
- The ingest answers 400 (not 409) when no session is running: it is the same `AutomationError` path as every other
  body problem, and the message says so.
- The mobile screenshot answers from the host screen the app draws (shared `ScreenFrames`), and a host with nothing
  drawn answers 409; a phone used only as a controller has no interface at all (it isn't hosting).
- `SHARE_VIEW` gets no automation call (the brief's API list has none); it keeps feeding `shareViewProvider`, which is
  the path a call would use, and the docs say so.
- `THUMBPARTY_STATS_CONSENT` accepts only `no`; any other value leaves the question to the person.
- The 16-series cap was chosen from the measured 89 KB at 32, halving it per series; the budget test pins it.

## Questions and suggestions

1. `tools/automation.dart` prints the `ok` envelope as it comes; should a later version print only the payload?
2. The interface has no call for `shareView` (streaming to joined phones). If demo videos want it, one `settings` field
   would do; it is a one-line addition to `_applyGameSettings`' neighbour.
3. A container's bind (`THUMBPARTY_AUTOMATION_BIND=0.0.0.0`) is documented but no image sets it yet; job c1's image
   would need the token and the bind in its environment.
4. `probe/press` presses in D-pad mode only; a stick press (for a game that reads sticks) would need a mode field.
5. The TV suite rewriting `site/shots/*.png` on every run is a side effect worth its own tiny job (a golden update
   switch), so a job's diff doesn't carry those bytes.

## Commit message

```
host: one automation interface for every build (M15 a2)

Add the shared HTTP+JSON automation API in party_host: players, input,
game start and stop, settings, state, screenshot, the latency card, the
probe and the p1 stream ingest, off unless a launch switches it on.
The debug start flags become wrappers over the same paths, and
docs/automation.md, tools/automation.dart and tools/demo-run.sh show it.
Simulated-only sessions are marked and never uploaded; a full summary with
a stream record stays under the PRD's 50 KB.
```

## Status row

M15 a2 done: the shared automation interface (off by default, loopback only, token when off loopback), its calls
documented in docs/automation.md with curl examples, the stream ingest, the latency test card, the flags as wrappers,
tools/automation.dart and tools/demo-run.sh; open: a container bind and a stick press for the probe (report
questions 3–4).

## Delete

- none
