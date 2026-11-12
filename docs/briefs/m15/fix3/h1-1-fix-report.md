# M15 h1 phase 1 fix: the should-fix findings of the fix2 review

## Summary

Nine of the ten **should** findings of `docs/briefs/m15/fix2/REVIEW.md` are done; the tenth (a widget test that
fails without `scheduleFrame()`) is done only in part, and says why under Decisions.

- **1:** `reporter.js` keeps the frame loop's handle and `stop()` cancels it, so a reconnect starts one loop.
- **2:** `bench.sh` and `tools/stream.sh` refuse `--viewer-cpus` beside `--viewer external`; the docs' example,
  both flag lists and a `stream_tool_test.dart` test say so.
- **3:** `docs/automation.md` gives both shapes (declared → 400 "the body is too long" at once; chunked → the
  connection closes) and the deleted server-level test of the declared case is back.
- **4:** the g1 report's kbit/s cells (2237 vbv1, 2201 vbv2), `browser/safari` naming, core lists (`0-7` never
  became ready, `0-11` worked) and the un-starved viewer **withdrawn: the pinned run had no pinning**.
- **5:** both docs say sixteen checks; the distro prints 16 `ok` lines. **6:** the start-error test waits on
  the host's log through a `Completer`, not on 5 ms polls. **7:** a two-press-in-one-frame test exists but
  passes without the call. **8:** fix1's `must` is marked wrong where it stands.
- **Coulds done:** `automation_body.dart`'s refusal comment; two decisions in the g1 report.

## Decisions

1. **The kbits reading stands (ruling 1):** no setting changed; fix1/REVIEW.md's `must` now carries its
   correction, so a later reader doesn't "fix" 167 into 167 000.
2. **The pair is refused, not warned (ruling 4):** a warning is read and forgotten, and g1-ext1 is what that
   looks like; `check_args` in `bench.sh` and `check_viewer` in `stream.sh` both exit 2 before anything runs.
3. **The declared-too-long test sends the whole body.** The first attempt declared `maxBodyBytes + 1` on a raw
   socket and sent none of it: the server answered nothing and left the socket open, so "answers before it
   reads" cannot be seen from outside a Dart server (observed, three variants). The test therefore declares the
   length and sends it, as the deleted test did, and asserts the 400 and the line. The early
   `contentLength > limit` throw is covered at unit level (`automation_server_test.dart:324`, which fails the
   moment it goes); only the server-level path is not.
4. **The start-error test waits on the log, not on a bare notifier:** `AutomationShell`/`AutomationGate` have no
   event for "listening", and the provider's own clear runs before the bind (a microtask), so the two log lines
   are the only signals that say which bind ended. Both are the server's own report, delivered as a stream
   event: no delay, no poll.
5. **No test can fail without `scheduleFrame()`:** measured, `hasScheduledFrame` is false after a settle, and a
   press turns it true even with the call removed, because the same press flips the latency card's provider,
   which the harness has a listener for. The added test presses twice inside one frame and checks both releases;
   it documents the rule but is not a regression test, and the frame expectations it had proved nothing (dropped
   in M15 fix4 i1).
6. **Coulds left alone on purpose:** `automation_server.dart:84` (a deletion touching the g1 report's wording,
   no defect), the `kindOf`/stats duplication, the two screens' bind line, the two bench viewer-wait items,
   report:209's `screen_fit_test` claim, and the over-400-line files; the technical ones are in
   `docs/code-health.md` ("M15 streaming"). `relay_test.py`'s `any(...)`/unused `body` was fixed in M15 fix4 i1.
7. **One accidental bench run in the distro:** a `bash -c "source streaming/bench.sh"` (meant only to load the
   functions) ran a 60 s bench. Its containers were stopped by the script's own trap, no keep-alive was left,
   and its `/work/stream-bench/bench` output folder was removed; nothing of it is in this diff.

## What changed, file by file

- `streaming/player/reporter.js`: `_animationFrame` holds the fallback loop's handle; `stop()` cancels it.
- `streaming/bench.sh`: refuses `--viewer-cpus` beside `--viewer external`; header comment and `--help` say so.
- `tools/stream.sh`: `check_viewer` refuses the pair (exit 2, before the distro is touched); usage says so.
- `tv_test_app/test/stream_tool_test.dart`: "a benchmark refuses cores for a viewer it does not start".
- `docs/automation.md`: the 64 KB rule, both shapes and what a client sees.
- `docs/dev-tools.md`: the example without `--viewer external --viewer-cpus`; the core lists; "sixteen checks";
  the pair's refusal.
- `streaming/README.md`: the core lists and the pair's refusal; "sixteen checks".
- `packages/party_host/lib/src/automation/automation_body.dart`: the doc comment stops promising a refusal that
  a chunked sender may lose to the close.
- `packages/party_host/test/automation_server_test.dart`: `_callDeclaring` and the restored declared-too-long
  test.
- `packages/party_host/test/automation_start_error_test.dart`: `logged()` (a `Completer` on the host's log)
  replaces `until()`; the container is built over an overridden `logProvider`.
- `packages/party_host/test/automation_api_test.dart`: the two-presses-in-one-frame test.
- `docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md`: the un-starved viewer withdrawn, §2 rewritten, the
  kbit/s cells, the `browser/safari` wording, the core lists, the rerun line, three new decisions, a correction
  note in the Summary.
- `docs/briefs/m15/fix1/REVIEW.md`: one line on the `must` at :15 saying the kbits reading stands.

## Test values

- Declared body: `AutomationServer.maxBodyBytes + 1` = 65537 declared → `400`, body exactly
  `{"ok":false,"error":"the body is too long"}`, and the fake API was never called (0 calls).
- Chunked body (unchanged): 16 KB chunks, exactly **5** read (4 × 16 KB = 65536 fit, the fifth crosses),
  then `HttpException` at the client because the server closes.
- `tools/check.sh format analyze host tv`: format PASS, analyze PASS, host **417 tests** (415 before: +2, the
  restored cap test and the two-press test), tv PASS.
- `tv_test_app/test/stream_tool_test.dart` alone: **12** tests (11 before).
- `streaming/player/relay_test.py` in the distro: `relay test: 16 checks passed`.
- `bench.sh --viewer external --viewer-cpus 12-15` in the distro prints
  `bench: --viewer-cpus needs --viewer chrome: a viewer you open yourself is pinned on that device` and exits
  at `exit 1` (traced with `bash -x`; the `wsl -- bash -lc` wrapper loses nested exit codes, `echo $?` said 0).
- `bash -n` on `streaming/bench.sh` and `tools/stream.sh`: clean. No `node` here, so `reporter.js` was checked
  by eye only.

## Not done

- A test that fails without `host_automation.dart:181`'s `scheduleFrame()`: no widget test can be (Decision 5).
- The coulds listed in Decision 6.
- Nothing else in the ten shoulds: each is fixed and the two script fixes are tested.

## Questions

1. Item 2 promised "400 before reading"; a Dart server shows a client nothing until the body arrives, so the
   docs say the host refuses from the declared number rather than that the client sees it early. Is that wording
   what you want?
2. Should `--viewer-cpus` with `--viewer external` be refused by `stream.sh` as well as `bench.sh` (it is), or
   would you rather the outer tool passed it on and let the bench answer?

## Self-check (docs/review-rules.md part A)

1. **Every host setup:** no protocol, no game and no phone flow changed; the changes are one JS loop, two script
   guards, one doc comment, three test files and docs. Tested by the host (417) and tv suites.
2. **When kept state starts and ends:** the reporter's `_animationFrame` starts with `start()` on a browser
   without `requestVideoFrameCallback`, ends with `stop()` (now cancelled) and is null while nothing runs; the
   test's log wait ends with the line it waits for, and its subscription is cancelled with `whenComplete`.
3. **How a new state combines:** nothing new pauses, hides or blocks input. The frame handle combines with a
   reconnect (a new reporter, the old one stopped) and with `start()` called once per reporter.
4. **Stay in the job's folder:** only the `allow:` list was written; `flutter test` again flagged
   `tv_test_app/{linux,windows}/flutter/generated_plugin*` with line endings only (`git diff --numstat` shows no
   content change), as the g1 report noted.
5. **Stop rather than overstep:** the one thing the brief asked that the code cannot show (a test failing
   without `scheduleFrame()`) is reported, not faked; nothing outside the allow list was edited.

## Hand-over

Lines that work today (distro `tp-stream`, image built; `--label` is the run's name):
- `tools/stream.sh bench --seconds 60 --label x` — headless Chrome viewer; add `--probe` for the latency card.
- `tools/stream.sh bench --viewer external --probe --seconds 60 --label phone` — waits up to 180 s per session
  for a device that opens the printed URL; never add `--viewer-cpus` (refused now).
- `tools/stream.sh bench --viewer-cpus 12-15 --session-cpus 0-11 --label pinned` — the un-starved comparison,
  `--viewer chrome` only, not yet run: this is phase 2's job.
- `tools/stream.sh bench --set SESSION_VBV_KBITS=167 --label vbv`; `selftest`; `stats`.
- Flags: `--sessions --seconds --game --size --players --port-base --label --out --keep --set --viewer
  --viewer-cpus --session-cpus --probe`.
- Do not redo: the kbits decision, the body-cap wording and its two tests, the core lists, the bitrate column,
  `browser/*` naming, sixteen checks, the pair's refusal. The `scheduleFrame()` test can only be revisited if
  the harness stops scheduling a frame when the card's provider flips.

## Commit message

M15 h1-1: the fix2 review's shoulds, and an honest pinned run

The reporter cancels its animation-frame fallback when a consumer closes, and the
bench refuses --viewer-cpus beside --viewer external instead of ignoring it. The
body cap's docs now say which shape sees a 400 and which sees the close, and the
server test for a declared-too-long body is back. The g1 report's bitrate column,
core lists and viewer naming are corrected, its un-starved viewer is withdrawn (the
pinned run had no pinning), and fix1's kbits must is marked wrong. The start-error
test waits on the host's log instead of polling; no test can fail without the
probe's scheduleFrame, and that is reported.

## Status row

- **h1 phase 1 fixed (fix3 run):** nine of ten shoulds done (reporter loop, viewer-cpus refusal, body-cap docs
  and tests, four report/doc corrections, sixteen checks, start-error test); **open:** no test fails without
  `scheduleFrame()`, the un-starved viewer waits for a `--viewer chrome` rerun, and the coulds named in the
  report.

## Delete

- none
