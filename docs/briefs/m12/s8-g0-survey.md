# m12 step 8 (G0) survey: battery, heat, the report and the host frame-rate option

Read-only survey: facts from the code with file:line, no proposals. Shorthand: SE=`packages/metrics/lib/src/session.dart`, R=`packages/metrics/lib/src/report.dart`, RT=`packages/metrics/lib/src/report_table.dart`, LS=`packages/party_host/lib/src/live_stats.dart`.

## Answers

**1 `HostType`.** Five values: `android_tv`, `windows`, `phone`, `tablet`, `other` (SE:9-17). A TV is `android_tv` and a PC `windows`, else `other`, in `tv_test_app/lib/src/tv_host_setup.dart:25-29` (its `HostKind` tv/pc at :30); a phone host is `phone`, a tablet `tablet`, in `controller_app/lib/src/host/phone_host_setup.dart:16-21` (decided by `controller.device?.kind == DeviceInfo.tablet`). The summary says this once: `'host': {'type', 'app', 'os'}` (SE:247), beside `schema` (:245), `id` (:246), `date` (the day only, :249), `durationS` (:250), `players` (:251), `rounds` (:252) and `frames` {drawn, dropped} (:253). The collector's constructor takes exactly type/app/os (SE:57-64); `LS:39-41,184-191` fills them from the host identity, wired in `packages/party_host/lib/src/host_service.dart:137-146`. Nothing else about the host device is in the file.

**2 The `deviceStatus` channel.** One channel, `com.thumbparty.app/haptics`, one method `deviceStatus` (dart: `controller_app/lib/src/device_status.dart:48-61`). It returns battery 0..1 (or -1 when unknown), charging, thermal string (nominal/fair/serious/critical/unknown), cpuMs (this process's CPU time) and lowPower (`DeviceStatus.fromMap` :16-25; fields :27-38). Android: `controller_app/android/app/src/main/kotlin/com/thumbparty/app/MainActivity.kt:65-86` (BatteryManager capacity :68, `currentThermalStatus` mapped :69-78, `Process.getElapsedCpuTime` :83, `isPowerSaveMode` :84), dispatched at :34. iOS: `controller_app/ios/Runner/AppDelegate.swift:105-119` (batteryLevel/state, `ProcessInfo.thermalState` through `thermalName` :121-129, rusage :108-111, `isLowPowerModeEnabled`), dispatched at :82-83. Read every 10 s by `SessionMonitor` (`device_status.dart:112-144`; `period` default :116; keeps ~90 s, :153-157), started only when the phone is **not** hosting: `controller_app/lib/src/ui/controller_screen.dart:65` ("The battery and CPU readout is the controller's; a host has its own") — and no host-side sampler exists. The samples become `SessionStats` (`device_status.dart:69-108`: cpuPercent, `batteryPerHour` :86-92 which needs 5 min and no charging, sendRate) and are shown only in Diagnostics (`controller_app/lib/src/ui/diagnostics_screen.dart:164-189`), shared as text at :221-231. Nothing in `packages/metrics` or `packages/party_host` imports it, and no summary field comes from it.

**3 Summary, report, CSV, and "where each player watched".** Per player (SE:259-291): install, player, `local` (only when true, :265), platform, app, device, connectedS, disconnects, reconnect, quitsMidGame, inputs, inputsPerS, ping, `stages` (:276), `view` {frames, gaps, late} only when the phone drew any (:277-278, summed per player in :129-136), firstMode, `modes` {ms, activeMs, games, wins, draws} (:294-311), switches, segments {id, mode, ms, activeMs, ended, data} (:321-328), ratings, games, gameStats. A round is one flat map: {game, timeS, players, winner|winners, draw} (SE:209-216), capped at 1000 (:208). `summarySchema = 1` (SE:343). Report: `rowsOf` makes one `ModeRow` per player per mode (R:140-150, `_PlayerRows` :154-241); the CSV header is 33 columns (R:95-98) and `toCsv` :100-134 ends with the view columns (:131-133). The tables are in RT: `groupBy` :88-96, `table` :150-167, `enjoyment` :170-191, `report()` = "By input mode", "By device and mode", enjoyment (:193-200), `csv()` :202-206. The CLI is `packages/metrics/bin/report.dart` (usage :1-11/:17-24, folders :79-99, `--firestore` :103-142, dedupe by `id` :67, tables :70, CSV :71-74).
Where a player watched is not recorded as such. The host's own player is written `local: true` (SE:265), set at `LS:164` for a `GamePlayer.local` player; a phone that draws the game gets a `view` block, a phone that watches the TV gets none (`packages/metrics/test/view_report_test.dart:119-124`). `ControllerInfo.isLocal` (`packages/connection/lib/src/host_types.dart:54`) and `capabilities` (:87, `supports()` :98) exist, but `_checkPlayers` records a join with number/platform/app/device only (`LS:159-166`) — neither field reaches the summary.

**4 Frame rate.** `HostingSettings`: `frameRateHz` default 60, min 20, max 60, `ranges` step 10 (`packages/game_kit/lib/src/hosting_settings.dart:46-63`), plus `maxPlayoutFrames`. Its only runtime source is `fromEnvironment()` (:25-26): release gives the defaults, debug gives `startFrameRateHz` from `--dart-define=FRAME_RATE_HZ` (:6) through `fromFrameRate`, which refuses out-of-range values (:31-37). `GameSession` accepts settings but defaults to `fromEnvironment` (`packages/game_kit/lib/src/game_session.dart:24-29`), tells viewers the rate in `view_start.hz` (:30-37) and sends a frame every `1000/hz` ms (:253-256). No caller passes settings: `PuzzleSession` (`packages/puzzle_game/lib/src/puzzle_session.dart:52-66`) and `ArenaSession` (`packages/test_game/lib/src/arena_session.dart:29-31`) have no such parameter, and each view builds a new session per round (`packages/puzzle_game/lib/src/play_view.dart:86-95`). So a different rate per round needs a code change, not a restart, and nothing changes it today (unsure whether the rate could be said to live anywhere else — it cannot: no prefs key, no provider and no screen mentions it). No round record carries the rate: `round_start` has puzzle/level/format/players (`puzzle_session.dart:70-78`), `round_end` has timeS/puzzle/format/modes/winners/draw (`packages/puzzle_game/lib/src/puzzle_report.dart:57-70`); `hz` only ever leaves in `view_start`.

**5 Playtest settings.** `PuzzleSettings` (`packages/puzzle_game/lib/src/settings.dart:4-97`): 10 numeric values and `dropReadyHighlight` (:37), with `ranges` (:44-55), `toJson` (:57-67), `fromJson` (:79-93) and `withValue` (:96). Kept as JSON in SharedPreferences under `'puzzleSettings'` by `puzzleSettingsProvider` (`packages/party_host/lib/src/providers.dart:264-287`, key at :268, save :283). Screen: `packages/party_host/lib/src/ui/puzzle_settings_screen.dart` (rows :15-26, `format` :28-37, `_step` :90-95, Reset :53-58), opened from the games screen (`games_screen.dart:61`; reachable on a phone host because `controller_app/lib/src/host/host_games.dart:14-20` shows that same `GamesScreen`). A running session re-reads them every step through `playtest()` (`puzzle_session.dart:84-85,115`), supplied by `play_view.dart:91` from `party_host/lib/src/ui/puzzle_screen.dart:171`. The existing pattern for recording a value with a round is a hand-written `_record` call: `round_start` (`puzzle_session.dart:70-78`) and `round_end` (`puzzle_report.dart:57-70`); no settings snapshot is recorded per round today.

**6 The report command, and a session file off a host phone.** `dart run metrics:report <folder or .json files>` from `packages/metrics` (`bin/report.dart:4-7`), or `--firestore <project> --token <token>` (:6, :103-142); it keeps only files whose `schema == summarySchema` (:93) and dedupes by id (:67). Nothing under `tools/` runs it (`tools/check.sh:25` only names the test suite). The host writes `<support>/sessions[-debug]/session-<stamp>-<id>.json` (`LS:192-196`; folders: `tv_host_setup.dart:54-57`, `phone_host_setup.dart:35-38`). The Stats screen's Export copies them into the export folder (`packages/party_host/lib/src/ui/stats_screen.dart:44-54` → `LS:241-245` → `packages/party_host/lib/src/session_store.dart:63-80`), but that screen is reached only from the TV's home (`tv_test_app/lib/src/ui/home/home_screen.dart:241`); the phone host has no route to it, and its export folder is the app's documents dir (`phone_host_setup.dart:41`). The phone app's only share is the Diagnostics text (`diagnostics_screen.dart:6,221-231`). The phone host passes no uploader (`controller_app/lib/src/host/phone_host.dart:38-45`; the parameter is optional, `host_service.dart:106,146`; `controller_app/lib/src/host/host_overrides.dart` overrides none). So today a session file cannot leave a host phone by any path in the app.

**7 Tests that pin the formats.** `packages/metrics/test/metrics_test.dart` (612 lines, 38 tests): the summary test :404-550 pins schema/date/duration/host :484-487, rounds :488-490, frames :491, player fields :493-527, the no-names rule :529-534, then report and CSV :536-549. `packages/metrics/test/view_report_test.dart` (126, 6): row values :65-74, table text :76-84, 33 CSV fields ending `41,62,3,9,720,3,5` :86-91, absent view :93-105, sums :109-117, no `view` key :119-124. `packages/metrics/test/host_type_test.dart` (22, 1): tablet round trip, CSV prefix `s,2026-11-07,tablet,` :6-21. party_host: `test/live_stats_test.dart` (344), `test/stats_screen_test.dart` (47). game_kit: `test/hosting_settings_test.dart` (4), `test/session_test.dart:78-90` (frames at 20/30/60).

## Sizes
| file | lines |
| --- | --- |
| packages/metrics/lib/src/session.dart | 379 ⚑ |
| packages/metrics/lib/src/report.dart | 245 |
| packages/metrics/lib/src/report_table.dart | 209 |
| packages/metrics/bin/report.dart | 142 |
| packages/metrics/test/metrics_test.dart | 612 ⚑ |
| packages/metrics/test/view_report_test.dart | 126 |
| packages/party_host/lib/src/live_stats.dart | 299 |
| packages/party_host/lib/src/host_service.dart | 345 ⚑ |
| packages/party_host/lib/src/session_store.dart | 81 |
| packages/party_host/lib/src/providers.dart | 287 |
| packages/party_host/lib/src/ui/stats_screen.dart | 294 |
| packages/party_host/lib/src/ui/puzzle_settings_screen.dart | 161 |
| packages/party_host/lib/src/host_identity.dart | 80 |
| packages/game_kit/lib/src/hosting_settings.dart | 64 |
| packages/game_kit/lib/src/game_session.dart | 287 |
| packages/puzzle_game/lib/src/puzzle_session.dart | 178 |
| packages/puzzle_game/lib/src/puzzle_report.dart | 76 |
| packages/puzzle_game/lib/src/settings.dart | 97 |
| packages/test_game/lib/src/arena_session.dart | 132 |
| controller_app/lib/src/device_status.dart | 165 |
| controller_app/lib/src/providers/device.dart | 79 |
| controller_app/lib/src/ui/diagnostics_screen.dart | 359 ⚑ |
| controller_app/lib/src/host/phone_host.dart | 128 |
| controller_app/lib/src/host/phone_host_setup.dart | 42 |
| controller_app/lib/src/host/hosting.dart | 88 |
| controller_app/android/.../MainActivity.kt | 86 |
| controller_app/ios/Runner/AppDelegate.swift | 250 |

## Constraints
- Persisted format: summary JSON schema 1 (SE:343), read by `rowsOf` (R:140) and by the CLI (bin/report.dart:93); the 33-column CSV header (R:95-98) and the table text are pinned by tests.
- Prefs keys: `puzzleSettings` (providers.dart:268), `statsConsent`/`uploadedSessions` (LS:102-103).
- Wire: `view_start.hz` (game_session.dart:35); `MetricsMessage.view` {frames, gaps, late} (`packages/protocol/lib/src/metrics.dart:58-60,122-126`); no wire message carries a host's battery or heat.
- Exported API: `HostType` constants, the `SessionCollector` constructor and `summary()`, `ModeRow` (33 fields, `csvHeader`, `toCsv`), `table`/`groupBy`/`report`/`csv` via `packages/metrics/lib/metrics.dart` (14 lines), `HostingSettings.ranges`/`fromFrameRate`, the `HostService` and `StatsService` interfaces (stats_service.dart is 39 lines).
- Already over 300 lines: session.dart 379, host_service.dart 345, diagnostics_screen.dart 359; metrics_test.dart 612 is over the 500-line test limit.

## Conflicts
1. m12 §2.6 (:88) says the summary adds the host's battery drop and thermal states and, per player, where they watched (host screen / host phone / joined phone). None of the three exists: no device-status data reaches the summary, and `local` plus `view` are the only proxies (answer 3).
2. m12 §5 step 8 (:148) promises "a test option on the host phone to switch the frame rate (60, 30, 20) between rounds without a rebuild, recorded with each round". There is no runtime source but the dart-define, no settings parameter on either session class and no rate in any record.
3. m12 §2.6 (:88) puts device status "behind a `DeviceMonitor` interface"; the code's interface is `DeviceStatusSource` (device_status.dart:42-44) inside `controller_app`, which `metrics` and `party_host` do not depend on.
4. PRD v2 :170, :403, :644, :655 and :727 expect the host phone's battery drop and temperature in the session summary; the summary has no field for either.
5. m12 §2.5 (:78) and §4 (:128) match the code (20-60, default 60, a hosting setting), but nothing can set that setting: `HostingSettings` is only ever built by `fromEnvironment`.
6. `view` is the player's own total, not per mode, yet `ModeRow` repeats it on every mode row (R:205,236-238) and `table` sums it per mode group (RT:150-167) — a player in two modes counts twice in a by-mode table.
7. The phone/tablet host type is a guess from `device.kind` (phone_host_setup.dart:16), the same field that picks `HostKind` (:21); the two cannot disagree today, but neither is confirmed by the OS.
8. `host.os` is a bare platform string from the identity (LS:84, tv_host_setup.dart:31), not a device description, so the report cannot tell two phones apart as hosts.

## Questions
1. Should the host phone's battery and heat go in through the `metrics` package (as a plain map like the rest of the summary) or stay in `party_host` and be injected by the shell, as `HostDirectories` and the uploader are? The design says `DeviceMonitor`, the code has `DeviceStatusSource` in `controller_app`: which layer should own it?
2. For "where they watched", is `local` plus the presence of `view` enough (a joined phone that never drew counts as TV), or does the contract want an explicit value per player, and does it belong in the player record or in each mode segment?
3. Is the frame rate to be a `HostingSettings` value set per round by the host app (which needs a parameter on `PuzzleSession`/`ArenaSession`), or a host-level setting the sessions read like `playtest()` does?
4. Which record should carry the rate: `round_start` data, `round_end` data, or a new host-level field in the summary (m12 §2.6 names none)?
5. Is the frame-rate option a debug-only test option (like `FRAME_RATE_HZ`) or a shipped setting on a host phone's screen? Step 8 says "test option ... without a rebuild".
6. How should a session file get off a host phone: an Export button on a phone-reachable screen, an uploader override in the phone shell, or the OS share sheet? Nothing in the code does any of them today.
7. Do the new host fields bump `summarySchema` to 2 (the CLI drops other schemas, bin/report.dart:93), or stay optional additions under schema 1?

Housekeeping: an empty probe file `.dart_tool/zz-bash-probe.md` (0 bytes, git-ignored) was left by a tool check and could not be removed (`rm` is refused by the permission rules; moving it out of the repo needs approval). It is not tracked and not part of the job.

## Commit message

```
docs(m12): survey battery, heat, the report and the frame-rate option

Answer step 8's seven G0 questions from the code: HostType and what the
summary records about the host; the deviceStatus channel on both platforms
and who samples it; the summary, report and CSV shapes and the absent
"where they watched"; where frameRateHz comes from and why no round
records it; how playtest settings are stored and recorded; how a report is
run and why no session file can leave a host phone; the tests that pin the
formats. Adds sizes, constraints, conflicts with m12 §2.6 and §5, and
seven open questions. No code changed.
```

## Status row

| 8 Battery, heat and the report | G0 survey done ([s8-g0-survey.md](s8-g0-survey.md)): HostType, the deviceStatus channel, summary/report/CSV shapes, the frame-rate source, playtest settings and the report command, with sizes, conflicts and 7 questions. Open: Claude's step 8 contract | |

## Delete

- none
