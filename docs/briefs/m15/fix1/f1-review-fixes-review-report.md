## Summary

Verdict: **small fixes** — the code reads sound and the checks I ran pass, but the reviewed commit carries another job's test file, and the new bind error has an end and a wiring that nothing tests.
- Severity: 1 must, 3 should, 5 could.
- Top: the f1 commit contains t1's `stream_tool_test.dart` changes, whose keep-alive / `--set` / 413 tests cannot pass on f1's `tools/stream.sh` and `serve.py`, so `tools/check.sh tv` fails on this commit and the report's count (58 → 59) does not include them.
- Top: nothing clears `automationStartErrorProvider`, so self-check A2's "ends with the server (a settings change rebuilds the provider)" is false.
- Top: the `onStartError` → provider link (`automation_providers.dart:161`) has no test; deleting it leaves both new tests green.
- Ran: `dart analyze --fatal-infos` on `packages/party_host packages/metrics tv_test_app` — clean; `packages/metrics` 144 tests pass (the quoted 45,580 bytes included); `automation_api_test` 11, `automation_server_test`, `stream_ingest_test` and `tv_test_app/test/stream_tool_test.dart` pass on today's tree (which already has t1's code).

## Findings

- **must** tv_test_app/test/stream_tool_test.dart:57 the f1 commit adds the keep-alive, `bench --set` and relay-413 tests (57, 72, 86, 153) but f1's `tools/stream.sh` has no `keep-alive` or `--set` command and f1's `serve.py` has no 413 (`git show 5ffd764:…`), so the tv suite fails on the reviewed commit and the file is missing from the report's file list and count → give these lines to t1's commit (t1's report already claims the file) and list it there.
- **should** packages/party_host/lib/src/automation/automation_body.dart:24 the reader keeps draining to twice the limit after the cap is passed, the opposite of item 2's "stop with the too long error as soon as the cap is passed", and its test at automation_server_test.dart:288 says "before it is all read" while :305 asserts 9 × 16 KB (147,456 bytes) were read → stop the stream at the cap, or have Claude confirm the drain and rename the test to what it asserts.
- **should** packages/party_host/lib/src/automation/automation_providers.dart:142 the start error has no end: nothing clears it, not a successful start and not a rebuild of the server provider, so the report's A2 line "ends with the server (a settings change rebuilds the provider)" is untrue → clear it when a start succeeds (or from the server provider's dispose), or say in A2 that it lasts until the app exits.
- **should** packages/party_host/lib/src/automation/automation_providers.dart:161 nothing tests the `onStartError` → `automationStartErrorProvider` link: the server test passes no callback and the TV test (latency_screen_test.dart:49) sets the notifier itself, so deleting this line keeps both green → add one test that fails a bind with the provider listening and asserts its state.
- **could** packages/party_host/lib/src/automation/host_automation.dart:177 `addPostFrameCallback` does not ask for a frame, so when nothing else draws one the release waits and the probe button stays held → call `SchedulerBinding.instance.scheduleFrame()` after queueing it.
- **could** docs/automation.md:162 "two calls in a row are two presses" is false for two calls inside one frame (the second changes nothing before the release) → say "two calls a frame apart".
- **could** packages/party_host/lib/src/automation/automation_body.dart:20 `readRequestBody` and `maxAutomationBodyBytes` were made public library API (party_host.dart:11) only so the server test can call the reader, though other host tests import `package:party_host/src/…` directly → import the src file in the test and drop the export.
- **could** packages/party_host/lib/src/automation/stream_ingest.dart:23 a viewer that is neither a word nor an object now gets its own refusal, a behaviour change that is neither in the brief nor under the report's decisions → list it as a decision or remove it.
- **could** packages/metrics/bin/stream_sampler.dart:174 the report's "no touched file over 380 lines" is not true of this touched file (444 → 445 lines) → say "no `lib/` file" in the report, or split the file, which is over the guideline's 400 even before this job.

## Decisions to confirm

- `pipeline_ms` in the CSV is the gauge's **mean** beside `pipeline_ms_p95`, not the brief's "median": `docs/protocol.md` §13 says a gauge keeps `n, mean, p95, max`, so there is no median to give — safe, but it is a decision worth one line in the report's decision list.
- The body reader drains an over-cap body to twice the cap instead of stopping at the cap (item 2's letter): it keeps memory at the cap and gets the 400 out, so it looks safe; confirm it rather than leave it as a summary sentence.
- The round methods moved out of `session.dart` as well as the stream methods (365 lines otherwise): the public API is unchanged, so it fits item 1's "public API stays".
- The start error lasts for the whole app run by design; if that is wanted, A2 has to say so (see the second should).
- The repo's commit for f1 appears to hold t1's `stream_tool_test.dart` edits (the f1 report's tv count matches a run without them); worth knowing whether that is a harness attribution or a worker slip before it is counted against f1.

## Could not check

- The tv suite on the f1 tree itself (I cannot check out): the failure is inferred from `git show 5ffd764:tools/stream.sh` (no `keep-alive`, no `--set`, no `KEY=VALUE`) and `git show 5ffd764:streaming/player/serve.py` (no 413, no 64 KB check).
- The host suite's 412 count: I ran only `automation_api_test`, `automation_server_test` and `stream_ingest_test`, not the whole package.
- The c2 first numbers in STATUS.md (126 ms, 203 ms, 37 fps) — they come from the earlier reports and were not re-measured.
- The container's stderr in a real run: the new cgroup warning was only exercised through `CgroupFiles` with a missing directory.

## Commit message

M15 f1 review: findings on the fix batch

Read the fix batch against the guidelines, the review rules and its brief.
One must: the reviewed commit carries t1's stream_tool_test.dart, whose new
keep-alive, --set and 413 tests cannot pass on f1's tools/stream.sh and serve.py.
Should: the body reader drains past the cap; the bind error never clears and
its provider link is untested. Could: the probe release needs a frame, the
docs overstate two presses in a row, an unlisted export and refusal, and the
file-size claim for bin/stream_sampler.dart. No code or document changed.

## Status row

- **f1 review done:** one must (t1's `stream_tool_test.dart` sits in f1's commit), three shoulds (cap drain vs the brief and its test name, the bind error never clearing, the provider link untested) and five coulds; **open:** Claude to verify and route the must, and the f1 fixes themselves are otherwise sound.

## Delete

- none
