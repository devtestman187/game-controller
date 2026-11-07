# M12 step 8 s8c — G4 report: the two tables, `--paste`, `--csv-rounds`, the phone's monitor, the frame-rate option, the Diagnostics session line

Plan §2's s8c list with the brief's answers (Q5 the row is always shown, Q6 `StatsState.lastSaved`, Q8
`diagnostics_screen.dart` ≤ 364), §5's s8c tests plus §3's exit test. The summary stays `schema: 1`; the by-mode tables
keep their text; the CSV keeps its 33 columns. One thing the plan didn't name had to be added for §1 and the exit test
to be possible at all: a round now records whether it charged (see Deviations 1).

## What was done

### `metrics`

- `lib/src/report.dart`: `ModeRow.watched` (the player's `host_phone` / `joined_phone` / `host_screen`, null from an
  older summary), `_PlayerRows.watched`, and `report()` now prints `table('By input mode')`, `table('By device and
  mode')`, `watchedTable(rows)`, `frameRateTable(summaries)`, `enjoyment(summaries)`.
- `lib/src/report_table.dart`: `_median` is public as `medianOf` (both new tables need it), and `plainTable(title,
  headers, rows)` holds what `table()` did — `table()`'s own text is unchanged.
- `lib/src/report_watched.dart` (new): "By host and where they watched" — `host`, `watched`, `players`, `input ms`,
  `touch ms` (median/p95), `jitter ms`. Each player counts once (their mode rows repeat their stage and view numbers,
  §0.9), grouped by host type and place, sorted host then place, "—" where nothing was measured.
- `lib/src/report_rounds.dart` (new): `RateRow` (rounds, minutes, one touch median/p95 per player, late, gaps, the
  battery's seconds and drop, the hottest thermal), `rateRows(summaries)`, `frameRateTable(summaries)` ("By frame
  rate": `host`, `hz`, `rounds`, `minutes`, `touch ms`, `late/min`, `gaps/min`, `battery %/h`, `thermal`),
  `csvRounds(summaries)` (`session,host,game,hz,time_s,battery_start,battery_end,thermal`). A drop per hour needs
  `minBatteryS` (300 s) of samples and rounds that ran on battery; a charging round is counted in `rounds` and its
  heat, never in the drop.
- `lib/src/paste.dart` (new): `sessionSummaryMarker` and `summariesInPaste(text)` — the marker on its own line, the
  one-line JSON on the next, `schema` checked, junk and unreadable lines skipped.
- `lib/src/session.dart`: `roundBattery(..., charging:)` and `charging: true` in the round's battery block only when
  it is true (so a round on battery writes exactly what it did in s8b).
- `bin/report.dart`: `--paste <file>` (missing file → stderr and exit 66; no summaries → a stderr note),
  `--csv-rounds <file>`, the header comment and `_usage`, and §0.9's note in the help text.
- `metrics.dart`: +3 exports (`paste.dart`, `report_rounds.dart`, `report_watched.dart`).

### `party_host`

- `lib/src/device_sampler.dart`: the round's battery block gets `charging: sample?.charging ?? false`.
- `lib/src/stats_state.dart`: `lastSaved` — the last summary `_save()` wrote, kept after the session ends.
- `lib/src/live_stats.dart`: `_save()` sets `current: summary, lastSaved: summary`.

### `controller_app`

- `lib/src/host/host_monitor.dart` (new): `PhoneHostMonitor implements party.HostDeviceMonitor` over the app's
  `DeviceStatusSource`; battery −1 (the native "can't read it") and thermal `unknown` become null.
- `lib/src/host/hosting_frame_rate.dart` (new): `hostingFrameRates` (60, 30, 20), `defaultHostingFrameRateHz`,
  `hostingFrameRateProvider` (saved under `hostingFrameRateHz`; an unknown saved value reads as 60; `set()` refuses a
  rate that isn't offered), and `hostingSettingsAt(hz)`.
- `lib/src/host/host_overrides.dart`: `party.hostingSettingsProvider` = `hostingSettingsAt(hostingFrameRateProvider)`
  and `party.hostDeviceMonitorProvider` = `PhoneHostMonitor(deviceStatusSourceProvider)`.
- `lib/src/host/phone_host.dart`: `PhoneHostInputs.monitor` (the live host is built by `PhoneHost.live`, not by
  `hostServiceProvider`, so the override alone can't reach it), passed to `LiveHostService`.
- `lib/src/host/hosting.dart`: `_inputs` passes `ref.read(party.hostDeviceMonitorProvider)`.
- `lib/src/ui/settings_sections.dart`: the "Frame rate (test)" row at the end of "Game on this phone" — the label, the
  subtitle, and a `SegmentedButton` (`Key('settingsFrameRate')`) of 60 / 30 / 20.
- `lib/src/ui/diagnostics_view_section.dart`: `lastSessionSummary(ref)` (null before the first host) and
  `sessionReport(summary)` (the marker, the JSON line).
- `lib/src/ui/diagnostics_screen.dart`: `buildReport` ends with `b.write(sessionReport(lastSessionSummary(ref)))`
  (+1 line → 360).

### Docs

- `docs/dev-tools.md`: a new "The stats report: metrics:report" section — the command lines (`--firestore`, `--paste`,
  `--csv`, `--csv-rounds`), what the tables count, the 5-minute battery rule, what `--paste` reads, and where the
  sessions come from.

### Tests

- `metrics/test/report_watched_test.dart` (5), `test/report_rates_test.dart` (10), `test/paste_test.dart` (4),
  `test/report_two_hosts_test.dart` (4, §3's exit test), `test/host_device_test.dart` +1 (a charging round keeps
  `charging: true` in its battery block).
- `party_host/test/live_stats_test.dart` +1 (the saved session stays in the state after the session ends), plus a
  `deleteTempFolder` helper: the teardown's `dir.delete(recursive: true)` was failing under a full run with Windows'
  errno 32 ("used by another process") because the session file the end-of-session save writes is still held for a
  moment. It retries 20 times, 25 ms apart, and rethrows the last error, so a real leak still fails the test.
- `controller_app/test/host_monitor_test.dart` (3), `test/settings_test.dart` +2 (60 shown and saved as 30; a relaunch
  reads 30), `test/diagnostics_test.dart` +3 (the marker and one JSON line while hosting, after stopping, none without
  a host), `test/hosting_test.dart` +1 and a default check in the first test (the host's `hostingSettingsProvider`
  follows the saved 30 → 20; 60 by default).

## Line counts (new and touched)

| file | lines | |
| --- | --- | --- |
| `metrics/lib/src/report.dart` | 264 | was 245 (plan ≈252) |
| `metrics/lib/src/report_table.dart` | 218 | was 209 (`table()`'s body moved to `plainTable`) |
| `metrics/lib/src/report_watched.dart` | 50 | new |
| `metrics/lib/src/report_rounds.dart` | 211 | new |
| `metrics/lib/src/paste.dart` | 28 | new |
| `metrics/lib/src/session.dart` | 307 | was 305 |
| `metrics/bin/report.dart` | 171 | was 142 (plan ≈185) |
| `party_host/lib/src/device_sampler.dart` | 125 | was 120 |
| `party_host/lib/src/stats_state.dart` | 63 | was 56 |
| `party_host/lib/src/live_stats.dart` | 326 | was 324 |
| `controller_app/lib/src/host/host_monitor.dart` | 31 | new |
| `controller_app/lib/src/host/hosting_frame_rate.dart` | 43 | new |
| `controller_app/lib/src/host/host_overrides.dart` | 41 | was 33 |
| `controller_app/lib/src/host/phone_host.dart` | 133 | was 128 |
| `controller_app/lib/src/host/hosting.dart` | 89 | was 88 |
| `controller_app/lib/src/ui/settings_sections.dart` | 282 | was 244 |
| `controller_app/lib/src/ui/diagnostics_view_section.dart` | 88 | was 66 |
| `controller_app/lib/src/ui/diagnostics_screen.dart` | **360** | was 359 (aim 300, §2's limit 364) |

No lib file is past 360 (`live_stats.dart` 326 and `session.dart` 307 are the next largest; both were over 300
before this job). No test file is past 500 (`party_host/test/live_stats_test.dart` 417 is the largest);
`metrics/test/report_rates_test.dart` is 193, `report_two_hosts_test.dart` 154, `report_watched_test.dart` 124.

## Test counts (per check, before → after)

| check | before | after | added |
| --- | --- | --- | --- |
| metrics | 64 | **88** | 24 (5 + 10 + 4 + 4 + 1) |
| host (`party_host`) | 75 | **76** | 1 |
| phone (`controller_app`) | 320 | **329** | 9 (3 + 2 + 3 + 1) |
| tv (`tv_test_app`) | 28 | 28 | — |
| **total** | **487** | **521** | **34** |

## The exit test's two tables (verbatim, `report([tvSummary(), phoneSummary()])`)

```
By host and where they watched
host          watched  players  input ms  touch ms  jitter ms
-------  ------------  -------  --------  --------  ---------
phone      host_phone        1        25         -          -
phone    joined_phone        1         -     90/90          8
windows   host_screen        1        30         -          -

By frame rate
host     hz  rounds  minutes  touch ms  late/min  gaps/min  battery %/h  thermal
-------  --  ------  -------  --------  --------  --------  -----------  -------
phone    60       4      6.7     40/40       0.9       0.3         36.0  serious
phone    30       2      2.0     90/90       1.5       0.5            -  nominal
windows  60       2      3.0         -       0.0       0.0            -        -
```

The whole call printed, in order: "By input mode", "By device and mode" (one `unknown dpad` row — the test's metrics
messages carry no platform), then the two tables above, then `Enjoyment: 2 sessions, 6.5 min and 4.0 games on average,
no ratings`.

## Computed test values

- **By host and where they watched.** The host phone's own player: `[phone, host_phone, 1, 25, -, -]`; the joined
  phone: `[phone, joined_phone, 1, -, 90/90, 8]`; the TV's phone: `[windows, host_screen, 1, 30, -, -]`. The input
  delays are 20 and 25 ms (the own player played at both rates): the upper median is 25, since `quantile(0.5)` on two
  samples takes rank `(0.5 × 1).round() + 1 = 2`. The joined phone's touch samples are 40 (60 Hz) and 90 (30 Hz), and
  its jitter 4 and 8: both medians are the larger one, 90 and 8, for the same reason.
- **By frame rate.** `phone 60`: 4 rounds of 100 s = 6.7 min; 6 late frames over 400 s = 0.9/min; 2 gaps = 0.3/min;
  300 s (three rounds; the fourth charged) losing 3 % of a charge → `0.03 × 100 / (300 / 3600) = 36.0` %/h; the
  hottest heat is `serious` (the charging round's own reading). `phone 30`: 2 rounds of 60 s = 2.0 min; 3 late over
  120 s = 1.5/min; 1 gap = 0.5/min; 120 s is under `minBatteryS`, so `-`; `nominal`. `windows 60`: 2 rounds of 90 s =
  3.0 min; the TV keeps its game to itself, so its phone filed no view or touch by rate: `-` for touch, `0.0` for both
  per-minute figures, `-` for the drop and the heat.
- **The CSV.** `csvRounds` gives 8 rows: two `tv-1,windows,arena,60,90.0,,,` and
  `ph-1,phone,arena,60,100.0,0.8,0.79,fair` (three times), `…,0.77,0.79,serious`, and two
  `ph-1,phone,arena,30,60.0,0.76,0.75,nominal`.
- **The round's battery.** `roundBattery(start: 0.77, end: 0.79, thermal: 'serious', charging: true)` →
  `{'start': 0.77, 'end': 0.79, 'charging': true}`; without `charging` the block is exactly s8b's.
- **The frame-rate option.** With `hostingFrameRateHz: 30` saved, `party.hostingSettingsProvider.frameRateHz` is 30
  and `set(20)` makes it 20 (and `prefs.getInt('hostingFrameRateHz')` 20); 60 with nothing saved; an unknown saved
  value reads as 60.
- **The monitor.** A reading of `battery: 0.79, charging: true, thermal: 'fair', lowPower: true` becomes exactly that
  sample; `battery: -1` → null battery, thermal `unknown` → null thermal, charging and lowPower false; a source that
  returns null gives no sample.
- **The state's `lastSaved`.** Null while the session runs (the checkpoint is a minute away), then the ended session's
  id once the last player has left and the session has been saved — with `current` null.
- **The Diagnostics line.** While hosting, the marker's line comes after "Host log (this phone is the host):" and the
  next line decodes to a summary with `schema: 1` and `host.type == 'phone'`; after `stop()` the marker is still
  there and the host log is not; a phone that never hosted has neither.

## Deviations from the plan (and why)

1. **A round's `charging` is new** (`session.dart` `roundBattery`, `device_sampler.dart`). §1's "rounds not charging"
   and the exit test's charging round need it per round; s8b wrote `battery: {start, end}` only. It is written only
   when true, so a round on battery is byte-for-byte what s8b produced and no existing test changed.
2. **`PhoneHostInputs.monitor`** (`phone_host.dart`, `hosting.dart`): the plan's file list has only the overrides.
   The live host is built by `PhoneHost.live(...)` with values from `HostingNotifier._inputs`, not through
   `hostServiceProvider`, so overriding `hostDeviceMonitorProvider` alone would never reach the host that runs.
   `_inputs` now reads the provider, which is the wiring the plan intends.
3. **`docs/dev-tools.md`** has a new section though §2's s8c list doesn't name it; the brief's allow list does, and
   `--paste` / `--csv-rounds` are the first flags a phone user needs told about ("the session off a host phone").
4. **Two named constants in `report_rounds.dart`** (`_minuteS`, `_percent`) and two in `_FrameRateRow` (`_topGap`,
   `_labelGap`), so `tools/review.sh`'s number check has nothing to report on the new lines.
5. **`_median` → public `medianOf`** in `report_table.dart` (the plan's `plainTable` only): the two new tables need
   the same median as the mode rows, and a second copy would drift.
6. **A temp-folder delete retry in `live_stats_test.dart`'s teardown** (see Tests): a Windows file-locking flake the
   new test exposed on full runs, not a change of what the suite asserts.

## Expectations that changed (old → new)

No existing test's expectation changed — in this repo's files or in the other packages. While writing the new tests I
corrected my own first guesses, which are worth recording since they are the median rule in action:

- The host phone's own player, input samples 20 and 25 ms: I first expected 20, the table says **25** (upper median
  with two samples; `quantile(0.5)`'s rank is `(0.5 × 1).round() + 1 = 2`).
- The joined phone, touch 40 and 90 ms, jitter 4 and 8: I first expected `40/90` and `4`; the table says **`90/90`**
  and **8** (the single sample at each rate gives median = p95, and two jitter samples give the upper one).
- The round CSV rows: I first left the thermal cells empty; the rounds carry `fair` / `serious` / `nominal`.
- The header lines: splitting on whitespace breaks `input ms`, `touch ms` and `battery %/h`, so the tests compare the
  whole header line with its runs of spaces collapsed.

## Checks

- `tools/check.sh format analyze metrics host phone tv` — **PASS** all six: format (1s), analyze (5s), metrics
  (88 tests), host (76), phone (329), tv (28), "All checks passed (48s)". An earlier run of the same command failed
  `host` once with the Windows errno 32 above, which is why the retry is there; two runs after it passed.
- `tools/review.sh` — **2 fail, 5 note**, and neither FAIL is on a line I changed:
  - `controller_app/lib/src/ui/diagnostics_screen.dart:24` `build` 196 lines (>60). My only hunk in this file is
    `@@ -282,0 +283 @@` (one line inside `buildReport`), so the function is untouched (it was 194–196 lines in
    s5c/s6 and is named as tech debt in STATUS.md).
  - `controller_app/lib/src/ui/settings_sections.dart:7` `_HapticsSection.build` 70 lines (>60). My hunks are
    `@@ -240,0 +241 @@` and `@@ -244,0 +246,31 @@`; `_HapticsSection` itself is untouched (named as tech debt in
    STATUS.md since s4).
  - The 5 notes: the 360-line `diagnostics_screen.dart` (under 400, past the 300 aim, and §2 allows 364),
    `buildReport` 51 lines (>40; it was 50), `ModeRow _row` 55 lines (>40; it was 54), `session.dart` 307
    and `live_stats.dart` 326 lines (both over 300, both over 300 before this job). The number notes my new lines
    raised are fixed (Deviation 4).

## Questions and suggestions

1. **`rounds` in "By frame rate" includes the charging round**, since the round happened; only the battery figure
   skips it. §1 says "rounds not charging" only about the drop. Confirm that reads right.
2. **`minutes` is the rounds' own time**, so a 60 Hz row can show 6.7 min where the session was 10; the input-mode
   table still shows the session's minutes. Worth a line in the help text if anyone compares the two.
3. **`host_screen` repeats the hosts' own rows**: today the only `watched` values are `host_phone` (this phone) and
   `host_screen` (a TV or tablet hosting). Fine for now; if a tablet ever hosts and its own player draws, one row per
   host type still holds.
4. **The CLI was not run end to end.** I tried `dart run metrics:report --paste <file>` on a paste file built by the
   exit test's summaries, but this session's sandbox refused to run the tool (approval required for `dart run` on a
   `bin/` entry point), so `--paste`, `--csv-rounds` and the "Round CSV written to …" line are covered by the unit
   tests and the analyzer only. A one-line check on a normal machine would close it.
5. **Suggestion (not done):** the phone's Settings could show the frame rate only while hosting is possible — but it
   is "always shown" by the brief, so it stays.
6. **Suggestion (not done):** `l10n`/strings — "Frame rate (test)" and its subtitle are literals like the rest of
   the Settings screen; if the app gains a translation pass they need moving with the others.

## Commit message

```
feat(m12): the report's host and frame-rate tables, --paste

Add "By host and where they watched" and "By frame rate" to metrics:report,
--paste to read a host phone's Diagnostics text back in, and --csv-rounds for
one CSV row per round. A round records whether it charged, and a host phone
ends its Diagnostics with its last saved session.

Add the phone's HostDeviceMonitor over DeviceStatusSource (battery -1 and an
unknown heat are null), the "Frame rate (test)" setting (60/30/20, saved under
hostingFrameRateHz, applied from the next round) and tests for all of it.
Schema stays 1 and the CSV keeps its 33 columns.
```

## Status row

| 8 Battery, heat, report | s8a (`4bdf083`), s8b (monitor, samples, `watched`, `hz`, `stagesByHz`, round battery, rate tables), **s8c G4 in**: `metrics:report` prints "By host and where they watched" and "By frame rate", reads a pasted Diagnostics (`--paste`) and writes a round CSV (`--csv-rounds`); the phone's `HostDeviceMonitor`, the "Frame rate (test)" setting at 60/30/20, and the Diagnostics session line (marker + one JSON line, while hosting and after). metrics 88, host 76, phone 329, tv 28; `diagnostics_screen.dart` 360 (≤364); the CLI's `--paste`/`--csv-rounds` were not run end to end in the job's sandbox. Open: the owner's two-phone session through `--paste` on devices |

## Delete

- packages/metrics/build/s8c-paste.txt
