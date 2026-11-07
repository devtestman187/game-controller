# M12 step 8 contract: battery, heat, the frame-rate test option, and the report

Refines m12.md §2.6 (host-side data) and §5 step 8, and wins where they differ. From the G0 survey ([s8-g0-survey.md](../briefs/m12/s8-g0-survey.md)); Claude's answers to its questions are §0.

## 0. Decisions on the survey's questions (Nov 7, 2026)

1. **The host's battery and heat come in through party_host, from the shell.** `party_host` defines `HostDeviceMonitor` (`Future<HostDeviceSample?> sample()`; a sample is battery 0..1 or null, charging, thermal name, low power) and `hostDeviceMonitorProvider` (default: none, so the TV records nothing). The phone app overrides it with an adapter over its `DeviceStatusSource`. `metrics` gets plain values (no Flutter, no channel). (The design's `DeviceMonitor` name becomes `HostDeviceMonitor`, since the phone app's `DeviceStatusSource` already exists.)
2. **Where each player watched is an explicit value per player record**, `watched`: `host_phone` for the host phone's own player (an in-process channel, `ControllerInfo.isLocal`), `joined_phone` for a phone that drew frames (its `view` block has frames > 0), else `host_screen`. It is decided when the summary is written. The Windows keyboard player keeps `local: true` and is `host_screen`.
3. **The frame rate is a hosting setting chosen per round.** `PuzzleSession` and `ArenaSession` take `HostingSettings`, given by the screen that creates the round. party_host's `hostingSettingsProvider` defaults to `HostingSettings.fromEnvironment()` (the TV and its debug define, as today); the phone app overrides it with a saved value.
4. **The rate is recorded with each round**: `round_start`'s data and the summary's round map gain `hz`. The host files each player's stage samples under the frame rate of the view that was running when they arrived (the host knows its current `view_start.hz`). So the summary's player record gains `stagesByHz` (`{"60": {stage: summary}, …}`) next to the existing `stages`.
5. **The frame-rate option is a test option in the phone app's Settings, shipped in test builds.** It goes in the "Game on this phone" section, under "Button visibility": "Frame rate (test)" with 60 / 30 / 20, saved under `hostingFrameRateHz`, and it applies from the next round. Its subtitle: "For testing: fewer pictures a second saves battery but looks less smooth".
6. **A session gets off a host phone through Diagnostics.** While the phone hosts, and afterwards until the app closes, the Diagnostics report ends with `Session summary (for the report):` and the last saved session's summary JSON on one line. `metrics:report` gains `--paste <file>`: it reads every such line from a pasted text file. That fits the bug-report flow (the owner pastes Diagnostics). No new plugin.
7. **`summarySchema` stays 1.** Every new field is optional, and the report reads old files as before.
8. **Per-round battery and heat.** At each round's start and end the host takes a sample (when a monitor exists). The summary's round map gains `battery: {start, end}` and `thermal` (the state at the end), and `host.device` gains the session's `batteryStart`, `batteryEnd`, `charging` (true if any sample was), `lowPower` (any), and `thermalS` (seconds in each state, from samples every 30 s).
9. **The survey's conflict 6** (a player's `view` counts repeated on each of their mode rows): the new tables below count per player, not per mode row. The by-mode tables stay as they are, and the doubling is noted in the report's help text.

## 1. The report (metrics)
`report()` adds two tables after today's:
- **By host and where they watched**: one row per (host type, watched): players, input delay median (the existing stage), touch-to-frame median and p95, frame jitter median.
- **By frame rate**: one row per (host type, hz): rounds, minutes, touch-to-frame median and p95, late and gaps per minute, battery drop per hour (rounds not charging, at least 5 minutes in all, else "—"), and the hottest thermal state seen.

The CSV keeps its 33 columns; a second CSV (`--csv-rounds <file>`) writes one row per round: session id, host type, game, hz, timeS, battery start/end, thermal.

## 2. Sizes first
`session.dart` (379) must stay under 400: split it before adding, as a pure move. `metrics_test.dart` (612) is over the test limit: split it as a pure move, and put the new tests in new files. `diagnostics_screen.dart` (359) gains no more than 5 lines (the session line goes in `diagnostics_view_section.dart` or a sibling). `host_service.dart` (345) may not pass 360.

## 3. Exit check (m12.md §5 step 8)
A test builds a summary for a TV session and a phone-hosted one (with a joined phone, rounds at 60 and 30 Hz, battery samples) and checks that the report prints both new tables with the expected numbers. On devices: the owner's two-phone test session, pasted from the host phone's Diagnostics, run through `metrics:report --paste`.

## 4. Jobs and gates
| Job | What | Gates |
| --- | --- | --- |
| s8-g1 | Plan: the two pure-move splits (seams named), the order, every file and test, conflicts | G1 |
| s8a | The splits | G4 (`--strings`, test counts) |
| s8b | §0.1–0.8 host side and metrics (monitor, samples, `watched`, `hz`, `stagesByHz`, round battery) | G3: the metrics fields with tests → G4 |
| s8c | The report tables, `--paste`, `--csv-rounds`; the phone app's monitor adapter, the frame-rate option, the Diagnostics session line | G4 |
