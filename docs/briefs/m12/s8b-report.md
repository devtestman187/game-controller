# M12 step 8 s8b — G4 report: the host device, `watched`, `hz` and the rate tables

Plan §2's s8b list in order, with §3's seams and §4's rules, and §5's s8b tests plus the `viewByHz` test the brief
adds. The summary stays `schema: 1`: every new key is optional, and a host without a monitor (the TV) records
nothing new. No existing test expectation changed; two test helpers gained an optional parameter.

## What was done

### `metrics`

- `lib/src/host_device_sample.dart` (new, exported): `HostDeviceSample` — `battery` (0..1 or null), `charging`,
  `thermal`, `lowPower`; all optional with a false default.
- `lib/src/session_device.dart` (new, internal): `HostDeviceTally` — `batteryStart`/`batteryEnd`, `charging` and
  `lowPower` (any sample), `thermalS` (state → seconds), `add(sample, forS:)`, `toJson()` (null when no sample said
  anything; a level outside 0..1 is skipped). `batteryLevel()` keeps a level to two decimals.
- `lib/src/session_player.dart`: `minViewHz` (20) / `maxViewHz` (120), `Watched` (`host_phone`, `joined_phone`,
  `host_screen`) and `watchedOf`, `PlayerRecord.inProcess`, `stagesByHz` and `viewByHz`, `playerJson` writes
  `stagesByHz`, `viewByHz` and `watched`, and the `stagesOf` / `viewOf` helpers.
- `lib/src/session.dart`: `joined(inProcess:)`, `stage(hz:)`, `metrics(hz:)` (the view counts file under the rate
  too), `roundStarted({hz})` (range-checked, kept in `_roundHz`), `roundEnded` writes `hz` and clears it,
  `roundBattery({start, end, thermal})`, `deviceSample(sample, forS:)`, and `host.device` in the summary.
- `metrics.dart`: +1 export.

### `connection`

- `ServerGameHost.viewRateHz`: the running view's `hz`, null between views and with `shareView` false.

### `party_host`

- `lib/src/host_device_monitor.dart` (new): the `HostDeviceMonitor` interface and `NoHostDeviceMonitor`.
- `lib/src/device_sampler.dart` (new): `HostDeviceSampler` — a 30 s timer (`deviceSampleInterval`) and the round
  hooks; the start level is kept as a `Future`, so an end that arrives while the start is still reading awaits it;
  a slow tick isn't counted twice, a broken reading is logged and costs that reading only, and `dispose` stops both.
- `live_stats.dart`: a `monitor` parameter, the sampler, `hz: host.viewRateHz` on the stage listener,
  `inProcess: c.isLocal` on `joined`, and the sampler's dispose.
- `host_service.dart`: `HostDeviceMonitor? monitor` passed through to `LiveStats`.
- `session_recorder.dart`: `metrics(..., hz: host.viewRateHz)` and `roundStarted(hz:)` from the record's `data['hz']`.
- `providers.dart`: `hostingSettingsProvider` (`HostingSettings.fromEnvironment`) and `hostDeviceMonitorProvider`
  (`NoHostDeviceMonitor`), the latter passed to `LiveHostService`.
- `ui/puzzle_screen.dart`, `ui/game_screen.dart`: read `hostingSettingsProvider` once in `initState` (a change of
  the setting waits for the next round) and pass it to `PuzzlePlayView(hosting:)` / `ArenaView(settings:)`.
- `party_host.dart`: +2 exports (`device_sampler.dart`, `host_device_monitor.dart`).
- `pubspec.yaml`: `game_kit` path dependency, with the comment the brief asks for.

### `puzzle_game`, `test_game`

- `puzzle_session.dart`: the public constructor takes `HostingSettings? settings` (passed to the private one), and
  `round_start` carries `hz` from it (in a small `_roundStartData` helper).
- `play_view.dart`: `hosting` (`HostingSettings?`) → `PuzzleSession(settings:)`.
- `arena_session.dart` / `arena_view.dart`: `super.settings` / `settings` and `round_start.hz`.

### Tests

- `metrics/test/host_device_test.dart` (7), `watched_test.dart` (6), `view_rate_test.dart` (6, the brief's
  `viewByHz` test included).
- `connection/test/view_test.dart` +1 (null → 60 → null → null with `shareView` false).
- `party_host/test/device_sampler_test.dart` (7): thermal seconds over two ticks, the round's start/end battery,
  a null battery, no monitor, no `round_start`, a broken monitor, dispose.
- `live_stats_test.dart` +1 (a stage filed under the running view's rate, totals unchanged).
- `game_screen_test.dart` +1 and `puzzle_screen_test.dart` +1 (the round at `hostingSettingsProvider`'s 20 / 30).
- `puzzle_session_test.dart` +1 (`sessionFor` gained `settings`; view_start and round_start at 30, 60 by default),
  `arena_session_test.dart` +1 (round_start at 20; 60 by default).

## Line counts (new and touched)

| file | lines | |
| --- | --- | --- |
| `metrics/lib/src/session.dart` | 305 | was 254 |
| `metrics/lib/src/session_player.dart` | 188 | was 131 |
| `metrics/lib/src/host_device_sample.dart` | 19 | new, exported |
| `metrics/lib/src/session_device.dart` | 56 | new, internal |
| `connection/lib/src/server_game_host.dart` | 323 | was 317 |
| `party_host/lib/src/live_stats.dart` | 324 | was 299 |
| `party_host/lib/src/session_recorder.dart` | 125 | was 121 |
| `party_host/lib/src/host_service.dart` | 350 | was 345 (limit 360, under) |
| `party_host/lib/src/providers.dart` | 315 | was 302 |
| `party_host/lib/src/host_device_monitor.dart` | 21 | new |
| `party_host/lib/src/device_sampler.dart` | 120 | new |
| `party_host/lib/src/ui/game_screen.dart` | 281 | was 274 |
| `party_host/lib/src/ui/puzzle_screen.dart` | 212 | was 205 |
| `puzzle_game/lib/src/puzzle_session.dart` | 185 | was 178 |
| `puzzle_game/lib/src/play_view.dart` | 148 | was 141 |
| `test_game/lib/src/arena_session.dart` | 136 | was 132 |
| `test_game/lib/src/arena_view.dart` | 96 | was 82 |

No lib file is past 360 (`host_service.dart` 350 is the largest) and no test file is past 500 (`connection/test/
view_test.dart` 434 is the largest).

## Test counts (per check, before → after)

| check | before | after | added |
| --- | --- | --- | --- |
| metrics | 45 | **64** | 19 (7 + 6 + 6) |
| connection | 250 | **251** | 1 |
| kit | 33 | 33 | — |
| arena (`test_game`) | 42 | **43** | 1 |
| puzzle (`puzzle_game`) | 97 | **98** | 1 |
| host (`party_host`) | 65 | **75** | 10 (7 + 1 + 1 + 1) |
| phone (`controller_app`) | 311 | 311 | — |
| tv (`tv_test_app`) | 28 | 28 | — |
| **total** | **871** | **903** | **32** |

## Computed test values

- `host.device` after two samples 30 s apart: `{'batteryStart': 0.9, 'batteryEnd': 0.8, 'charging': true,
  'thermalS': {'nominal': 30}}`; a sample with no battery still gives `{'charging': true, 'lowPower': true,
  'thermalS': {'serious': 30}}`; 0.8765 → 0.88 and a 1.2 reading is skipped.
- A round: `{'game': 'arena', 'hz': 60, 'timeS': 12.0, 'players': 1, 'battery': {'start': 0.5, 'end': 0.45},
  'thermal': 'fair'}`; no `hz` key when `roundStarted()` had none, no `battery` key when the reading was null, and a
  round is filled once (`roundBattery` twice leaves the first).
- `watched`: in-process → `host_phone` (even after frames), frames > 0 → `joined_phone`, a keyboard player and a
  phone that never drew → `host_screen`.
- `stagesByHz` `{'60': …, '30': …}` with `stages` the same totals; a rate outside 20–120 (a 5 Hz sample) counts in
  `stages` only; `viewByHz` after 60 frames + 1 gap at 60 Hz and 30 frames + 2 late at 30: `view` = 90 / 1 / 2,
  `viewByHz` = `{'60': (60, 1, 0), '30': (30, 0, 2)}`.
- The sampler with a 1 s period: two ticks in `nominal` → `thermalS {'nominal': 2}`; the round from its start 0.9
  and end 0.8 → `battery` + `charging: true`; a null battery → thermal only; no `round_start` → no battery block.
- The round's rate: puzzle 30 from the settings (60 by default), arena 20 (60 by default); the two screens pass
  the provider's 20 / 30 to the round and the view's start.

## Deviations from the plan (and why)

1. **`party_host/lib/src/session_recorder.dart` changed**, though §2's s8b list doesn't name it: the view counts
   (`metrics`) and `round_start` reach the collector there, so the `hz` seams had to be taken there (+8 lines).
2. **`party_host.dart` +2 exports, not +1**: the plan named only the monitor; `device_sampler.dart` is exported too
   so `device_sampler_test.dart` uses the package's public surface as the other tests do.
3. **`roundEnded` stays `void`.** The plan's "`roundEnded` (its `hz`; returns the number)" — the number is read
   from the summary by s8c, nobody needs it back, so `roundStarted({hz})` keeps it and `roundEnded` writes it.
4. **The sampler's test uses `period: 1 s`, not the plan's 10 ms**: `forS` counts whole seconds (`period.inSeconds`),
   so a 10 ms period adds 0 thermal seconds; `fake_async` is not a declared dependency, and the brief allows none.
5. **`joined(inProcess:)` sits after `local`**, not as the 8th named parameter Q3 names: named arguments have no
   order, and it reads with `local`; the name and meaning are as answered.
6. **A small `_roundStartData` helper at the end of `puzzle_session.dart`**: adding `hz` to the constructor's map
   pushed `tools/review.sh`'s function count from 57 to 64 lines for the `labels: {` member it mis-pairs; the body
   is now one `_record` call. The 54-line (was 57) `func` NOTE at line 23 is that same pre-existing false pair.

## Checks

- `tools/check.sh format analyze connection metrics kit arena puzzle host phone tv` — **PASS** all ten: format (4s),
  analyze (6s), connection 251, metrics 64, kit 33, arena 43, puzzle 98, host 75, phone 311, tv 28.
- `tools/review.sh` — `review: 0 fail, 7 note`. No FAIL on my lines. The notes: five `size` notes on pre-existing
  files (`server_game_host.dart` 323, `session.dart` 305, `host_service.dart` 350, `live_stats.dart` 324,
  `providers.dart` 315; all past the 300 aim, under the 400 limit), `session_recorder.dart`'s `onRecord` 52 lines
  (a NOTE before this job too) and the `labels:` false pair at `puzzle_session.dart:23` (54 lines, 57 before).
- `flutter pub get` in the root after the `party_host` pubspec change; `pubspec.lock` came out unchanged.
- No existing expected value changed; every old assertion still holds as written.

## Questions

1. **`roundEnded` returning the rate** — kept void (deviation 3). Does s8c need the number from the call, or is the
   summary enough?
2. **Sub-second sample periods** — should `HostDeviceSampler` count the true elapsed time (a clock, or `forS` in
   milliseconds/double) instead of `period.inSeconds`? Only tests are affected today.
3. **`HostDeviceSample.lowPower`** — the plan's field list has it, but the summary only writes it to `host.device`;
   is that the only place s8c shows it?
4. **`Watched` is not exported** (`session_player.dart` stays internal), so the tests spell `'host_phone'` and so
   on. Should the constants be public for s8c's tables, or do they keep reading strings?
5. **The backup provider seam** — `hostDeviceMonitorProvider` defaults to `NoHostDeviceMonitor` and s8c overrides it
   in the phone app; is the provider the seam Claude wants (rather than a `LiveHostService` argument read in the
   shell)?

## Suggestions

- Add `fake_async` as a dev dependency in a later job: the sampler's timer test would then run in 0 time and could
  use the plan's 10 ms period.
- The sampler could read the actual interval between ticks (an injected clock) so a slow reading doesn't lose its
  seconds; nothing depends on it yet.

## Not sure about

- The working tree was already dirty when I started (`STATUS.md`, `m12-phone-layout.md`, the TV app's generated
  plugin files, `s7d.md`); I left all of it alone.
- New files are LF; the checkout is CRLF, so `git diff` mentions the conversion for them, as s7a's did.

## Commit message

```
feat(m12): host device samples, watched and rates in the summary

metrics gains HostDeviceSample/HostDeviceTally and the session's
host.device, a round's battery/thermal, watched, inProcess, the round's
hz, stagesByHz and viewByHz (schema stays 1). party_host gains the
HostDeviceMonitor seam, HostDeviceSampler (30 s plus the round edges),
hostingSettingsProvider/hostDeviceMonitorProvider and viewRateHz; the
games send round_start.hz from HostingSettings. Tests 871 -> 903.
```

## Status row

| 8 Battery, heat and the report | s8b done ([s8b-report.md](s8b-report.md)): `HostDeviceSample`/`HostDeviceTally` and `host.device`, a round's battery/thermal, `watched`, the round's `hz`, `stagesByHz`/`viewByHz`, `joined(inProcess:)`, `HostDeviceMonitor` + `HostDeviceSampler` (30 s and the round edges), `hostingSettingsProvider`/`hostDeviceMonitorProvider`, `viewRateHz`, and each game's `round_start.hz` from `HostingSettings`; 903 tests (871 before), no existing value changed. Open: s8c (both tables, `--paste`, `--csv-rounds`, the phone adapter, the Diagnostics line) |

## Delete

- none
