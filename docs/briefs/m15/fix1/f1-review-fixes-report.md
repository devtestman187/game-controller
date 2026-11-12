## Summary

All eleven items are done; `tools/check.sh format analyze metrics host tv` passes.

- **session.dart** is 269 lines (from 400): the stream methods moved to `session_stream.dart`, the rounds to `session_rounds.dart`, both parts of the library, so the public API is unchanged.
- **The 64 KB cap** now holds for chunked bodies: `readRequestBody` counts as it reads; an over-long body is read to its end and discarded (up to twice the cap) so the 400 arrives, and no more than the cap is ever buffered.
- **`stats/stream` is all-or-nothing**: the whole body is checked before the viewer is registered or anything applied.
- **A failed bind** is kept in `startError`, logged once and reported through `automationStartErrorProvider`; the latency screen shows "Automation could not start: <reason>".
- **One live getter** (`live`); the duplicate `session` is gone.
- **Streaming resources** print `mean/p95`, with `_p95` CSV columns and `pipeline_ms` / `pipeline_ms_p95`.
- **The probe press** releases its button on the next frame; two presses in a row are two presses.
- **The sampler** warns once per cgroup file it can't read; `/proc` reads stay silent.
- **The unused `waitingForController`** string is out of `tv_text.dart`.
- **Docs**: protocol.md §13 quotes 45,580 bytes (44.5 KB) at the current cap, with 89 KB kept as the reason it was halved; automation.md gains the relay assumption, the cap wording and the no-session answer; STATUS.md describes branch `m15` and its first numbers.
- **No session**: `POST stats/stream` answers 200 `{"ok":true,"accepted":false,"reason":"no session"}` and drops the batch.
- **Counts:** metrics 142 → 144, host 407 → 412, tv 58 → 59 (1 skipped); no touched file over 380 lines, no function over 60.

## The items

### 1. session.dart under 300 lines

- `packages/metrics/lib/src/session.dart`: `part 'session_rounds.dart';` and `part 'session_stream.dart';`; the
  round methods, the six stream methods, `maxRoundTags`, `_roundTags` and `_roundTagPattern` moved out; 400 → 269
  lines. The summary's stream key is now `'stream': ?_streamOf(_stream)`.
- `packages/metrics/lib/src/session_rounds.dart` (new, 107 lines): `extension SessionRounds` with `roundStarted`,
  `roundEnded`, `roundBattery` (bodies unchanged, the static call qualified as `SessionCollector._mode`), plus the
  round-tag rules.
- `packages/metrics/lib/src/session_stream.dart` (new, 44 lines): `extension SessionStream` with `streamViewer`,
  `hasStreamViewer`, `streamStage`, `streamGauge`, `streamCounter`, `streamFact`, `streamResource` and the private
  `_streamOf`.

The round seam was needed as well as the stream one: moving the stream block alone left 365 lines.
Proving test: the package's own suite (metrics 144 tests pass), which uses every moved method unchanged.

### 2. The 64 KB cap for bodies with no length

- `packages/party_host/lib/src/automation/automation_body.dart`: `maxAutomationBodyBytes` and the new
  `readRequestBody(body, {contentLength, limit})`, which counts bytes as they arrive, keeps at most `limit` and
  refuses with `AutomationError('the body is too long')`.
- `packages/party_host/lib/src/automation/automation_server.dart`: `maxBodyBytes` aliases the shared constant and
  `_body` reads through `readRequestBody`.
- `packages/party_host/lib/party_host.dart`: exports `automation_body.dart`, so the server's test uses the same
  reader.

Proving tests: `automation_server_test.dart`, "a body with no length is refused at the cap, before it is all read"
(a real chunked request over the cap answers 400 and no call reaches the API; a stream of 16 KB chunks is refused
and reading stops at 9 chunks, twice the cap) and "a refusal says what to change, with the code for it" (the
declared-length body still answers 400).

### 3. `stream_ingest.dart` all-or-nothing

- `packages/party_host/lib/src/automation/stream_ingest.dart`: every stage, gauge, counter, fact and resource is
  read and checked into a record first; only then is the viewer registered or known and everything applied. The doc
  comment says a malformed body is refused whole however far down the bad item is.

Proving test: `stream_ingest_test.dart`, "a batch whose last item is malformed leaves the stream record as it was".

### 4. A bind failure, said once

- `packages/party_host/lib/src/automation/automation_server.dart`: `onStartError`, `_startError`, `startError`;
  the reason is logged as `Automation could not start: <reason>` and passed on once; `start()` returns early after
  a failure so no retry loop logs again.
- `packages/party_host/lib/src/automation/automation_providers.dart`: `automationStartErrorProvider` (a
  `NotifierProvider<String?>`) fed by the server provider's `onStartError`.
- `tv_test_app/lib/src/ui/latency_screen.dart`: watches the provider and shows one line in the look's caution
  colour above the figures.
- `tv_test_app/lib/src/tv_text.dart`: `TvText.automationNotStarted(reason)`.

Proving tests: `automation_server_test.dart`, "a port already in use is kept as an error and logged once" (a real
`ServerSocket` holds the port; the server keeps hosting, `startError` names the port, one log line);
`tv_test_app/test/latency_screen_test.dart`, "a failed bind is one line on the latency screen".

### 5. One `session` getter

- `packages/party_host/lib/src/live_stats.dart`: the duplicate `SessionCollector? get session` is removed; `live`
  stays.
- `packages/party_host/test/live_stats_test.dart`: callers use `live` (and `sessions()` for the saved files).

Proving test: the host suite (412 tests), which failed to analyze before the test's callers were changed.

### 6. Mean/p95 for the container readings

- `packages/metrics/lib/src/report_stream.dart`: the resources table uses a new `_meanAndP95(host, name)`, so each
  reading prints `mean/p95` (`50.0/55.0`) as a stage cell prints `median/p95`; the header doc says so.
- `packages/metrics/lib/src/report_stream_csv.dart`: each container gauge gains a `_p95` column (`cpu_pct`,
  `cpu_pct_p95`, …) and `pipeline_ms` + `pipeline_ms_p95` are added; the header doc lists both.
- `packages/metrics/lib/src/report_stream_test.dart`: the resource cells and the new CSV cells are asserted against
  the fixed sessions (mean 50/55, 925/950, 45/50, 12/14, 59/60, 60/60, 32/34 and 70/70, 1800/1800, 78/78, 12/12,
  30/30, 45/45; `pipeline_ms` 32, `pipeline_ms_p95` 34).
- `packages/party_host/test/stream_ingest_test.dart`: its report cells follow the same `mean/p95` shape.

Decision: the brief words `pipeline_ms` as "median and p95", but a gauge's summary is `mean/p95/max` — there is no
median (docs/protocol.md §13). The CSV gives the gauge's mean in `pipeline_ms` and its p95 in `pipeline_ms_p95`, as
every other container reading.

### 7. The probe press releases on the next frame

- `packages/party_host/lib/src/automation/host_automation.dart`: after the press is applied, a
  `SchedulerBinding.instance.addPostFrameCallback` sets a released `GamepadState`, with a comment saying why.
- `packages/party_host/test/automation_api_test.dart`: "a probe press lets its button go on the next frame, so a
  second probe registers" (two presses in a row flip the card twice).

### 8. The sampler warns once per unreadable cgroup file

- `packages/metrics/lib/src/stream_sampler.dart`: `CgroupFiles(directory, warn)` with a `_reported` set; a
  `FileSystemException` warns once per file name and reads null.
- `packages/metrics/bin/stream_sampler.dart`: builds it with `warn: (m) => stderr.writeln(m)`; `cpu.stat`,
  `memory.current` and `memory.peak` go through it, `/proc` reads keep `_readFile` (silent).
- `packages/metrics/test/stream_sampler_test.dart`: "a cgroup file that cannot be read warns once and reads null"
  (a missing directory, two reads, one warning).

Decision: the warning is per missing file rather than per sampler, so a container with the wrong cgroup path says
which files it cannot see (three lines at most) instead of only the first.

### 9. The unused string

- `tv_test_app/lib/src/tv_text.dart`: `waitingForController` and its comment deleted; nothing referenced it (the
  host's own copy in `HostText` is used by the automation game screen).

Proving test: the tv suite analyzes and passes; a missing use would have failed the analyzer.

### 10. Docs

- `docs/protocol.md` §13: the cap paragraph quotes **45,580 bytes** (44.5 KB) at 16 series and eight viewers,
  measured by `stream_budget_test.dart`, and keeps 89 KB as the size that made the cap halve.
- `packages/metrics/test/stream_budget_test.dart`: loops on `maxStreamViewers`/`maxStreamSeries`/`maxStreamSamples`
  and a new test pins the measured size ("a full record at the series cap is the size docs/protocol.md quotes",
  45,580).
- `docs/automation.md`: the security list gains the player-page relay assumption — the relay posts `stats/stream`
  and reads `GET status` with the session's token and relays no other call, so anyone who can open the player page
  can write technical measurements into that session's record and nothing else; the body bullet says the cap holds
  with or without a declared length; `stats/stream` documents the no-session answer and "refused whole"; the probe
  section says the button is released on the next frame.
- `docs/briefs/m15/STATUS.md`: "Where things stand" rewritten to the branch `m15` state (p1, c1, a2, c2 and this
  fix batch; first numbers; mirrored networking and the firewall rule still to come; next steps), with the old "Not
  yet created" bullet replaced.

### 11. `stats/stream` with no session

- `packages/party_host/lib/src/automation/host_automation.dart`: `ingestStream` reads
  `statsServiceProvider.live` and returns `const {'accepted': false, 'reason': 'no session'}` when there is none
  (the server's `_ok` makes it 200 `{"ok":true,...}`); `_liveSession()` is gone.
- `packages/party_host/test/automation_api_test.dart`: "measurements posted with no session are accepted and
  dropped".
- `docs/automation.md`: the `stats/stream` section quotes the answer.

## Test counts

| Suite | Before | After |
| --- | --- | --- |
| `packages/metrics` | 142 | 144 |
| `packages/party_host` | 407 | 412 |
| `tv_test_app` | 58 (1 skipped) | 59 (1 skipped) |

## Checks

`tools/check.sh format analyze metrics host tv`: all pass — format 3 s, analyze 10 s, metrics 144 tests (6 s), host
412 tests (79 s), tv 59 tests (13 s). One earlier run failed only on format (three host files rewritten); they are
formatted now.

## Review rules, part A

1. **Every host setup:** shared host code only — TV/PC host and both phone host modes run the same `AutomationServer`/`HostAutomation`, nothing reads a platform; tested by `automation_api_test` and the TV screen test.
2. **When kept state starts and ends:** `startError` is set once inside `start()` on a `SocketException`, never retried, and ends with the server (a settings change rebuilds the provider); a disabled interface sets nothing.
3. **How a new state combines with the others:** the start-error line is passive — no input blocked, no round state, nothing paused; the probe's frame callback runs with or without a round; shown in the TV screen test.
4. **Stay in the job's folder:** only the allowed paths changed (files below); `docs/briefs/m15/fix1/run-base` was already there and is not mine.
5. **Stop rather than overstep:** nothing needed stopping; the three judgement calls (mean vs median, read-and-discard after the cap, per-file warning) are decisions recorded above, not unasked changes.

## Files changed

- `docs/automation.md`: relay assumption, body cap wording, no-session answer, probe release.
- `docs/briefs/m15/STATUS.md`: branch state and first numbers.
- `docs/protocol.md`: the measured full-record size at the current cap.
- `docs/briefs/m15/fix1/f1-review-fixes-report.md`: this report.
- `packages/metrics/lib/src/session.dart`: parts added, round and stream methods moved out.
- `packages/metrics/lib/src/session_rounds.dart` (new): the round methods and tag rules.
- `packages/metrics/lib/src/session_stream.dart` (new): the stream methods and `_streamOf`.
- `packages/metrics/lib/src/report_stream.dart`: resources cells print mean/p95.
- `packages/metrics/lib/src/report_stream_csv.dart`: `_p95` columns and `pipeline_ms`.
- `packages/metrics/lib/src/stream_sampler.dart`: `CgroupFiles` with a once-per-file warning.
- `packages/metrics/bin/stream_sampler.dart`: cgroup reads through `CgroupFiles`.
- `packages/metrics/test/report_stream_test.dart`: mean/p95 cells and the new CSV columns.
- `packages/metrics/test/stream_budget_test.dart`: caps used by name; the measured size pinned.
- `packages/metrics/test/stream_sampler_test.dart`: the unreadable cgroup warning.
- `packages/party_host/lib/party_host.dart`: exports `automation_body.dart`.
- `packages/party_host/lib/src/automation/automation_body.dart`: `readRequestBody` and the shared cap.
- `packages/party_host/lib/src/automation/automation_server.dart`: the reader, `startError`, `onStartError`.
- `packages/party_host/lib/src/automation/automation_providers.dart`: `automationStartErrorProvider`.
- `packages/party_host/lib/src/automation/host_automation.dart`: frame-released probe; no-session answer.
- `packages/party_host/lib/src/automation/stream_ingest.dart`: validate everything, then apply.
- `packages/party_host/lib/src/live_stats.dart`: duplicate getter removed.
- `packages/party_host/test/automation_api_test.dart`: probe release and no-session tests.
- `packages/party_host/test/automation_server_test.dart`: chunked cap and port-in-use tests.
- `packages/party_host/test/live_stats_test.dart`: `live` and `sessions()` callers.
- `packages/party_host/test/stream_ingest_test.dart`: all-or-nothing test; mean/p95 cells.
- `tv_test_app/lib/src/tv_text.dart`: the automation line added, the unused string removed.
- `tv_test_app/lib/src/ui/latency_screen.dart`: the one-line start error.
- `tv_test_app/test/latency_screen_test.dart`: the start-error test.

`tv_test_app/{linux,windows}/flutter/generated_*` show as modified from `flutter pub get`, not from this job.

## Questions and suggestions

1. The gpu/cpu gauges are printed to one decimal in the table; the CSV keeps them as text, so a chart can't read
   `50.0/55.0`-style cells — that is the table, not the CSV, and the CSV's columns are numeric (suggestion only).
2. The relay could forward `probe/press` and `probe/flash` too, which would let a browser measure press-to-screen
   itself; today the benchmark presses from the container (suggestion, noted in docs/automation.md's relay bullet).
3. `docs/dev-tools.md` still says the automation interface takes a body "of at most 64 KB" without the chunked
   detail; that file is outside this job's allow list (suggestion).

## Commit message

M15 fix1: the review's ten fixes and the no-session ingest answer

The session split into parts (rounds, stream) under 300 lines; the 64 KB body cap now holds for chunked bodies and
stats/stream is refused whole; a failed bind is reported through a provider the latency screen shows; the probe
press releases on the next frame; the sampler warns once per unreadable cgroup file.
The Streaming report and CSV print mean/p95 for the container readings and gain pipeline_ms; the full record at the
cap measures 45,580 bytes, quoted in docs/protocol.md; automation.md documents the relay and the no-session answer.
Unused string removed; STATUS.md describes branch m15.

## Status row

- **f1 done:** the m15 review's ten fixes (session split, chunked body cap, all-or-nothing ingest, bind error on the latency screen, one live getter, mean/p95 + pipeline_ms in the report and CSV, frame-released probe, cgroup warnings, unused string gone, docs incl. the 45,580-byte record) and the no-session `stats/stream` answer (200, `accepted:false`); **open:** fix1/t1 latencies (jitter buffer, encode), tuning and the family test, and the owner's Windows Firewall rule for other devices.

## Delete

- none
