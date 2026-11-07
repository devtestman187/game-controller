# m12 step 8 G1 — plan: two pure moves, then battery, heat and the report

Read-only plan; this report is the only file changed. Sizes are `wc -l` today (Nov 7, 2026), `≈` after the move.
Contract [m12-report.md](../../design/m12-report.md) (§0, §2 sizes, §4 jobs), facts from
[s8-g0-survey.md](s8-g0-survey.md). No code changed, so nothing to run.

## 1. The splits (s8a, pure moves)

**`metrics/lib/src/session.dart` 379 → ≈262; new `src/session_player.dart` ≈125 (internal, not exported).**
Moved verbatim, private names made public in the new file: `PlayerRecord` (`_Player` 19–47), `ValueStats`
(`_ValueStats` 367–379), `playerJson` (`_playerJson` 257–291), `modesJson` 293–311, `switchesOf` 313–318,
`segmentJson` 320–328, `startMsOf` 330, `activeMsOf` 332–337 — 118 lines, importing `protocol`, `session_stats`.
**Stays**: `HostType` 8–17, `SessionCollector` 49–255 (`summary()` calls `playerJson`), `_mode` 339, `summarySchema`
342–343, `_clean`/`_cleanDevice`/`_technical` 345–363, `_tagPattern` 365; 379 − 118 + 1 import = ≈262, same keys.

**`metrics/test/metrics_test.dart` 612 → four files, 38 tests before and after.**
`test/support/touch_helpers.dart` (≈30): `testMap` 7–17, `recorder` 19–20. `test/segment_test.dart` (≈175):
geometry 25–43, counters 45–159, sanitizing 300–325 (15). `test/active_time_test.dart` (≈150): 161–298 (12).
`test/session_stats_test.dart` (≈85): 327–348 and 350–401 (7). `metrics_test.dart` keeps 403–587, 590–612 (4, ≈220).
Proof: the same 38 tests, `tools/review.sh --strings` 0 added / 0 removed, format and analyze clean.

## 2. s8b and s8c, in order (lines after; ⚑ = a `lib/` file past 360)

**s8b** — the monitor, the samples, `watched`, `hz`, `stagesByHz`, the round's battery.
- `metrics/src/host_device_sample.dart` ≈35: `HostDeviceSample` (battery 0..1 or null, charging, thermal, lowPower); `metrics.dart` +1 export.
- `metrics/src/session_device.dart` ≈90: `HostDeviceTally` — battery start/end, charging and lowPower (any), thermalS (name → s), `add(s, forS)`, `toJson()`.
- `metrics/src/session_player.dart` ≈175: `inProcess`, `stagesByHz`, `Watched`/`watchedOf`, `playerJson` writes both, `minViewHz`/`maxViewHz`.
- `metrics/src/session.dart` ≈300: `joined(inProcess:)`, `stage(hz:)`, `roundStarted({hz})`, `roundEnded` (its `hz`; returns the number), `roundBattery`, `deviceSample`, `host.device`.
- `party_host/pubspec.yaml` +2 (game_kit path); `party_host.dart` +1 export; `src/host_device_monitor.dart` ≈40 (`HostDeviceMonitor`, `NoHostDeviceMonitor`).
- `party_host/src/device_sampler.dart` ≈95: `HostDeviceSampler` — the 30 s timer, the round hooks, dispose.
- `live_stats.dart` ≈310 (monitor, sampler, `hz: host.viewRateHz`); `host_service.dart` ≈352; `providers.dart` ≈300; `server_game_host.dart` ≈321 (`int? get viewRateHz`).
- `puzzle_session.dart` ≈184 (`settings`, `round_start.hz`), `play_view.dart` ≈137, `arena_session.dart` ≈135, `arena_view.dart` ≈87.
- `party_host/src/ui/puzzle_screen.dart` ≈200, `ui/game_screen.dart` ≈279: `hostingSettingsProvider` read in `initState` (as `_target`, :82).

**s8c** — the tables, `--paste`, `--csv-rounds`, the adapter, the option, the Diagnostics line.
- `metrics/src/report.dart` ≈252: `ModeRow.watched`; the CSV keeps 33 columns.
- `metrics/src/report_table.dart` ≈225: `plainTable(title, headers, rows)` (`table()`'s text unchanged); `report()` adds the two tables.
- `metrics/src/report_watched.dart` ≈80: "By host and where they watched" (`groupBy` on host + `watched`; players = installs).
- `metrics/src/report_rounds.dart` ≈150: `RateRow`, `rateRows`, `frameRateTable`, `csvRounds` (`session,host,game,hz,time_s,battery_start,battery_end,thermal`).
- `metrics/src/paste.dart` ≈50: `summariesInPaste(text)`; `metrics.dart` +3 exports; `bin/report.dart` ≈185 (`--paste`, `--csv-rounds`, usage).
- `controller_app/src/host/host_monitor.dart` ≈30 (`PhoneHostMonitor`), `hosting_frame_rate.dart` ≈45 (`hostingFrameRateProvider`, 60/30/20), `host_overrides.dart` ≈34.
- `ui/settings_sections.dart` ≈272 ("Frame rate (test)"), `diagnostics_view_section.dart` ≈85 (`sessionReport`), `diagnostics_screen.dart` ≈362 ⚑ (§2: 364).
- `party_host/src/stats_state.dart` ≈64 (`lastSaved`), `live_stats.dart` ≈313 (`_save()` keeps it) — the line outlives the host.

## 3. Stage samples by the running view's rate (§0.4)
The rate is `ServerGameHost._viewStart.hz` (:63; set `startView` 205–214, cleared `endView` 224–229) — the same
`ViewStartMessage` the viewers got: one line, `int? get viewRateHz => _viewStart?.hz;`, no `GameHost` change, so no
fake grows. The only door is `LiveStats`'s listener (`live_stats.dart:59`), which both routes reach (the host's and
phones' batches via `_reportStages`, `server_game_host.dart:254–260`): `stage(..., hz: host.viewRateHz)` →
`PlayerRecord.stagesByHz['$hz'][stage]`. `stages` keeps every sample, so today's output is unchanged; no view (a TV
with `shareView` false) → null → `stages` only; a rate outside 20–120 is not filed by rate.

## 4. Round battery samples (§0.8)
`HostDeviceSampler` listens to `host.records` beside `SessionRecorder` (`live_stats.dart:56–61`), so round records
stay sync while the read is not. `round_start` → `await monitor.sample()`, the battery kept; `round_end` → one more,
then `session()?.roundBattery(start: kept, end: sample?.battery, thermal: sample?.thermal)`, filling the last round
(guarded: `_rounds` non-empty, no `battery` yet) — the trade-off of Q7. Every 30 s while a session runs
(`deviceSampleInterval`, injectable like `SessionMonitor.period`) it calls `deviceSample(raw, forS: 30)`; round
samples pass `forS: 0`, so `thermalS` counts the 30 s ones only. A missing monitor is the default
`NoHostDeviceMonitor` (null): no samples, no `host.device`, no round battery/thermal, as on a TV today; a null
battery still counts thermal, charging and lowPower. Dispose cancels the timer; a late sample finds no session.

## 5. Tests each job adds; existing ones that change
**s8a**: none — 38 stay 38, now 15/12/7/4.
**s8b**: `metrics/test/host_device_test.dart` ≈120: `host.device` `{batteryStart: 0.9, batteryEnd: 0.8, charging:
true, thermalS: {'nominal': 30}}` after two samples 30 s apart; a round's battery/thermal from its two; a null
battery leaves the numbers out. `test/watched_test.dart` ≈80: in-process → `host_phone`, frames → `joined_phone`,
keyboard and never-drew → `host_screen`. `test/view_rate_test.dart` ≈110: `stagesByHz {'60': …, '30': …}` with
`stages` unchanged; `round_start.hz` present and absent. `party_host/test/device_sampler_test.dart` ≈130:
`period: 10 ms` samples each tick, the round takes its two, a missing monitor and a null battery change nothing;
`live_stats_test.dart` +35 (a stage filed under the rate) and `connection/test/view_test.dart` +20 (null, 60,
null). `puzzle_session_test.dart` +30, `arena_session_test.dart` +25 and the two screen tests +20: `round_start.hz`
is the settings' 30 (60 by default), the round at the provider's rate.
**s8c**: `metrics/test/report_watched_test.dart` ≈80 and `test/report_rates_test.dart` ≈130: both tables' rows and
text — rounds, minutes, touch ms, drop per hour, the hottest thermal, the "—" cases (< 5 min, charged).
`test/paste_test.dart` ≈60 (two summaries from a Diagnostics text, junk skipped) and `test/report_two_hosts_test.dart`
≈150 (§3's exit test: a TV and a phone-hosted summary print both tables); `controller_app/test/host_monitor_test.dart`
≈40; `test/settings_test.dart` +45 (60 shown, 30 saved, a restart reads 30); `test/diagnostics_test.dart` +35 (the
marker and one-line JSON while hosting and after, none without a host); `test/hosting_test.dart` +25 (a round's
`view_start.hz` is the saved 30).
**Existing expectations that change: none** — new keys are written only when known, so `metrics_test`'s round
equality holds (no hz there), `live_stats_test.dart:203`'s `host` equality holds (no monitor), `view_report_test`
reads a missing `watched` as null, the CSV keeps 33 columns, and no test asserts `round_start`'s data.

## 6. Conflicts and questions
1. **Per-rate late and gaps need per-rate view counts**, absent from §0.4 (`view` is one total): `viewByHz` through
   the same seam, or "—"?
2. **"rounds not charging"** has no per-round charging. Plan A (preferred): `charging` in the round's battery block.
   Plan B: the session's `host.device.charging`, "—" when true.
3. **`watched` needs `ControllerInfo.isLocal`**, which stops at `live_stats.dart:159–166`: `joined(inProcess:)`, an
   8th parameter (a `JoinInfo` value object fixes the count too, but rewrites the call sites and four tests)?
4. **party_host → game_kit** for `HostingSettings` (§0.3): the contract names it, though guidelines §1 wants new
   dependencies named. Confirm.
5. **"shipped in test builds"** (§0.5): the row under `kDebugMode` (as `sessions-debug` does), or always shown?
6. **The Diagnostics line's source**: `StatsState.lastSaved` (what `_save()` wrote) rather than a new `StatsService`
   member, so `FakeStats` is untouched; the marker on its own line, the JSON on the next.
7. **The round battery lands after the record** (§4): it fills the last round, guarded — not an ordinal. OK?
8. **Numbers**: battery 0..1, two decimals; `stages` the union, `stagesByHz` the breakdown; `diagnostics_screen.dart`
   ≈362 (past 360, inside §2's 364). Confirm.

## Commit message

```
docs(m12): plan step 8's splits, battery, heat and the report

Map both pure moves (session.dart to session_player.dart; metrics_test.dart
to four files, the same 38 tests), then s8b (monitor, 30 s and round
samples, watched, hz, stagesByHz, round battery) and s8c (both tables,
--paste, --csv-rounds, the phone adapter, the Diagnostics line) with sizes,
the two seams, the tests per job and eight open questions.
```

## Status row

| 8 Battery, heat and the report | G1 plan done ([s8-g1-plan.md](s8-g1-plan.md)): the two pure moves are mapped (session.dart to ≈262 plus session_player.dart, metrics_test to four files, 38 tests), and s8b/s8c are ordered with sizes, the `viewRateHz` and `HostDeviceSampler` seams, the tests and eight questions. Open: Claude's answers, then s8a |

## Delete

- none
