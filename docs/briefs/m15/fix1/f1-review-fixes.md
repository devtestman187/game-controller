job: M15 f1: the fix batch from the run's review (docs/briefs/m15/REVIEW.md): code and document fixes in metrics, the automation interface and the docs
pub: no
stop: after it.
read: docs/briefs/m15/REVIEW.md (the findings; Claude verified the ones below in the code) · docs/automation.md · docs/protocol.md (the stream record) · packages/metrics/lib/src (session.dart, stream_stats.dart, report_stream.dart, report_stream_csv.dart) · packages/party_host/lib/src/automation (all) and its tests · packages/party_host/lib/src/live_stats.dart · docs/briefs/m15/STATUS.md · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude's decisions on the review's findings (Nov 11, 2026). Do each; behaviour changes are test-first.
1. **`packages/metrics/lib/src/session.dart` is 400 lines.** Move the stream methods and the stream summary keys out (an extension or a part in its own file) so `session.dart` ends under 300. No behaviour change; the public API stays.
2. **Automation body cap** (`automation_server.dart`, `_body`): the 64 KB cap must hold for a body with no content length. Read the request in chunks and stop with the "too long" error as soon as the cap is passed; never buffer more than the cap. Test with a chunked body larger than the cap.
3. **Stream ingest is all-or-nothing** (`stream_ingest.dart`): validate the whole body first, then apply it, so a malformed batch changes nothing (the doc comment and `docs/automation.md` already promise this). Test: a batch whose last item is malformed leaves the session's stream record exactly as it was (no viewer registered).
4. **A bind failure must be visible** (`automation_providers.dart`, `unawaited(server.start())`): keep the error, write it once to the host's log, and expose it through a provider the latency/stats screen can show as one line ("Automation could not start: <reason>"). Test with a port already in use.
5. **One name for the live session** (`live_stats.dart`): remove the second getter `session`; callers and tests use `live`.
6. **Resources table shows `mean/p95`** for CPU, memory and GPU in the Streaming report (`report_stream.dart`), as stage cells show `median/p95`; the CSV gets matching `_p95` columns and a `pipeline_ms` column (median and p95). Update the column docs.
7. **The probe press releases its button** on the next frame (`host_automation.dart`), so a second probe of the same button registers. Test: two probes in a row both flip the card.
8. **`stream_sampler.dart`**: warn once (to stderr) when a cgroup file cannot be read; keep returning null for vanishing `/proc` entries. Test with a missing cgroup path.
9. **Delete** the unused `waitingForController` text in `tv_test_app/lib/src/tv_text.dart` (check no test uses it).
10. **Docs**:
    - `docs/protocol.md` near the series cap: measure a full record at today's cap (16 series, eight viewers) in a test and quote that size; keep 89 KB only as the reason the cap was halved. If the full record is over the PRD's 50 KB, say so plainly in the report under "Not done" with the number (do not change the cap).
    - `docs/automation.md` security list: add the trust assumption that the session's player page relays measurement calls to the host with the session's token, so anyone who can open the player page can post measurements and trigger the probe for that session; nothing else of the API is relayed.
    - `docs/briefs/m15/STATUS.md`: rewrite "Where things stand" and "Not yet created" to today's state: branch `m15` (worktree `E:\AI\game-controller-m15`) holds the stream record and report (p1), the session image and `tools/stream.sh` (c1), the automation interface (a2), end-to-end measuring and `tools/stream.sh bench` (c2); first numbers: one 1080p session 126 ms capture to screen (jitter buffer 89), press to screen 203 ms median against gate 1's 80 ms; two sessions about 37 fps each; WSL is in mirrored networking mode since Nov 11 (owner's `.wslconfig`); watching from another device waits for the owner's firewall rule; next is this fix batch and the latency tuning job (fix1/t1). Keep the rest of the file.
11. **Measurements posted while no game session exists** (the owner saw this on Nov 11 on the home screen: the player page showed "the host did not take the measurements: no session is running"): `POST stats/stream` then answers 200 with `{"ok":true,"accepted":false,"reason":"no session"}` and drops the batch, instead of an error. Test it. Document in docs/automation.md.

Not in this job (job t1 does them): anything under `streaming/` or `tools/stream.sh`, the encoder's bitrate, latency tuning.

tests (each failing first): items 2, 3, 4, 7, 8 as named; item 6's table cells and CSV columns from the existing fixed sessions; item 10's record-size test. All existing tests pass.

in the report: start with `## Summary` (at most 30 lines: what was fixed per item number, the measured record size, decisions, anything not done). Then per item: files and the test that proves it. Test counts before and after.
self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow:
allow: docs/briefs/m15/fix1/f1-review-fixes-report.md · packages/metrics · packages/party_host · tv_test_app/lib · tv_test_app/test · docs/automation.md · docs/protocol.md · docs/briefs/m15/STATUS.md
check: format analyze metrics host tv
report: docs/briefs/m15/fix1/f1-review-fixes-report.md
