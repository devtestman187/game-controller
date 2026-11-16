# M14 stats2 c1-build-metrics: the build number in the summary and the CSVs

## Summary

The apps will send their version as "0.14.0+654" (version, plus, build). The metrics package now
splits that string once, keeps the bare version in `app` as before, and records the build beside it:

- `session_clean.dart`: `splitAppBuild("0.14.0+654")` -> `(app: '0.14.0', build: '654')`. The build
  is 1 to 9 digits (`maxBuildDigits`, `buildPattern`), anything else is empty; the version is what
  comes before the last `+`, so "+dev" leaves no trace.
- `session.dart`: the host's version is split when the collector is made (its `hostApp` getter keeps
  returning the bare version, so callers are unchanged), and the summary's `host` map gets
  `'build'` when there is one.
- `session_player.dart`: `PlayerRecord.build`, written by `joined()` from the split app string and
  put in the player's JSON as `'build'` when non-empty.
- `report.dart`: `ModeRow.hostBuild` / `.build`; the stats CSV header appends
  `,host_build,build` at the END (37 columns, was 35); `buildCell()` reads a build only as 1-9
  digits, so a summary from a newer version can't shift a row.
- `report_rounds.dart`: the rounds CSV header appends `,host_build` after `start_s` (18 columns,
  was 17), and each round row ends with the host's build.

Tests first: the new `test/csv_build_test.dart` (12 tests) was run against the code as it was and
failed 10 of 12 (`+2 -10`); the two that passed only assert that a build is *absent*, which the old
code never wrote. After the change the full suite was 25 failures, all header/column pins in ten
existing test files plus the new cases for columns that moved (round_offset's `start_s` is now cell
16, not the last). Those are updated, then the suite is green: 157 tests (145 before + 12 new).

## Decisions

1. **"+dev" loses its tail.** `app` is the text before the last `+` whether or not the tail is
   digits, so a local build reads "0.14.0" with no build — the brief's "the summary keeps the bare
   version in app", and a dashboard then groups a dev build with its version.
2. **9 digits at most.** `maxBuildDigits = 9` because a version code and Play's build numbers fit
   it, and a longer tail is not a build; the same pattern guards both writing and reading.
3. **The build is re-checked when read.** `buildCell()` in `report.dart` keeps only 1-9 digits, so a
   summary written by a newer version with a comma or text in `build` cannot shift a CSV row.
4. **No `build` key when there is none.** The summary omits it rather than writing `''`, like `os`
   and `device`; old exports and new ones from a plain version stay the same shape.
5. **A reconnect keeps what it knew.** `joined()` updates the build only when the new version names
   one, exactly as it already treated `app`.
6. **The host's split is stored, not recomputed.** The collector keeps a private
   `({String app, String build})` and exposes `hostApp` as a getter, so the public name, its
   meaning (bare version) and every caller (`live_stats.dart`: `hostApp: identity.appVersion`) are
   unchanged.

## Computed values (the tests pin these)

- `splitAppBuild('0.14.0+654')` -> app `0.14.0`, build `654` (host and player).
- `'0.14.0'` -> no build key; `'0.14.0+dev'` -> app `0.14.0`, no build key.
- `'0.14.0+1234567890'` (10 digits), `'0.14.0+65a'`, `'0.14.0+'` -> no build key.
- Stats CSV header: 37 fields (was 35), ends `,host_app,app,host_build,build`. A row with both at
  654 ends `...,0.14.0,0.14.0,654,654`; with plain versions `...,0.14.0,0.14.0,,`; an old summary
  `...,0.12.0,0.13.2,,`.
- Rounds CSV header: 18 fields (was 17), ends `,start_s,host_build`. A round row's last cell is
  `654`, or empty for an old summary.
- Checks: `tools/check.sh format analyze metrics` -> PASS format, PASS analyze, PASS metrics
  (157 tests).

## Self-check (review-rules A)

1. **Every host setup.** Not host-specific: the same `SessionCollector` code path runs on a TV/PC
   host and a phone host. A phone's own player goes through `joined()` like any other
   (`csv_build_test.dart`: player app/build), and a host one build older sends a plain version and
   gets no build (`a plain version is no build`). Apps are wired in c2.
2. **Kept state.** The player's build is held from the first `joined()` that names a version until
   the session summary, updated only by a later join that names one; nothing times, counts or waits
   on it, and no round state holds it (`a player sends "0.14.0+654"`).
3. **How it combines.** It adds no pause, timer, wait or input path; it only adds summary keys and
   CSV cells (`the stats CSV names the builds`, `the round CSV names the host build`).
4. **Folder.** Only files inside `allow:` were written.
5. **Stop rather than overstep.** Not needed; nothing in the brief contradicted the code.

## Questions and suggestions

1. **Question:** a dev build ("+dev") is now indistinguishable from the release of the same
   version in the report. If that matters, a later job could keep a `'dev': true` flag on the host
   and player, rather than a build string.
2. **Suggestion:** any spreadsheet or script that read the last two CSV columns by position now
   sees the build columns; named-column readers are unaffected. Worth a line in c3's docs.

## Hand-over

- c2 wires the apps: `host_service.dart` passes `identity.appVersion` to `LiveStats`, so once the
  phone's identity and the host identity send "0.14.0+654" the metrics side needs no change.
- The report side takes the build from `host['build']` and `player['build']`, so c2 must not add a
  separate field name.
- `report.dart` is at 300 lines, `session.dart` 361, `report_rounds.dart` 258: all under the 380
  limit, but `session.dart` is close — a further job that grows it should split it.
- Nothing outside the metrics package was touched; the CSV column counts changed (35 -> 37,
  17 -> 18), so c3's docs should state the new headers.
- Old exports (no build) read fine, with empty cells.

## Commit message

```
stats: record the app build number in the session summary and CSVs

The apps will send their version as "0.14.0+654". splitAppBuild() (session_clean.dart) splits
it once: the summary keeps the bare version in "app" as before, the build (1-9 digits only) goes
in a new "build" key on the host and on each player, and a plain or "+dev" version has none.
The stats CSV appends host_build,build at the end (37 columns) and the rounds CSV appends
host_build after start_s (18), so old columns keep their place and old summaries read as empty
cells. Tests first in csv_build_test.dart; the header pins in ten existing test files updated.
```

## Status row

m14 stats2 c1: the summary records the host's and each player's build ("0.14.0+654" -> app 0.14.0,
build 654, no key for plain or "+dev"), and both CSVs carry it (stats: host_build,build last, 37
columns; rounds: host_build last, 18) — done, 157 metrics tests green; open: c2 wires the apps to
send version+build, c3 documents the new columns, dev builds are not told apart from releases.

## Delete

- none

