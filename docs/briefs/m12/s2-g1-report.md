# M12 step 2 — G1 report (plan only, no code)

**Status: done, stopped at G1.** The plan is `docs/briefs/m12/s2-g1-plan.md` (214 lines, limit 250). No file
outside the two allowed ones was touched.

## What I read

- `docs/briefs/m12/s2-g1.md`, `docs/coding-guidelines.md`.
- `docs/design/m12-transport.md` (the contract) and `docs/design/m12.md` §2.1, §5a.
- `packages/connection/lib/src/host_server.dart` (813 lines), `controller_client.dart` (839), `host_address.dart`,
  `connection.dart`, `latency.dart`; all eight test files and `test/helpers.dart`.
- Callers: `party_host/lib/src/host_service.dart:102`, `simulated_controllers.dart:53`,
  `party_host/test/live_stats_test.dart:37,69`, `controller_app/lib/src/providers.dart:128`,
  `connection/bin/sim_controller.dart:62`, `connection/tool/ask_rating.dart:13`. `tv_test_app` has none.
- `docs/architecture.md` (for the G4 section) and the M12 parts of `docs/project-notes.md`.

## Files changed

- `docs/briefs/m12/s2-g1-plan.md` — new: the plan (sections 0 to 6 as the brief asks, plus a facts section in the
  style of `s1-g1-plan.md`).
- `docs/briefs/m12/s2-g1-report.md` — this report.

## Computed values (please check these against the rule)

**Test counts, before → after.** I counted `test(` in every file. Before: 89 in 8 files —
`host_address_test.dart` 18, `input_test.dart` 12, `m6_test.dart` 14, `m9_test.dart` 14, `m10_test.dart` 6,
`pairing_test.dart` 12, `reconnect_test.dart` 9, `haptic_test.dart` 4.

| File | both | once | web-socket only |
| --- | --- | --- | --- |
| haptic (4) | 4 | – | – |
| input (12) | 8 | 4 | – |
| m6 (14) | 9 | 4 | 1 |
| m9 (14) | 8 | 6 | – |
| m10 (6) | 5 | 1 | – |
| pairing (12) | 11 | – | 1 |
| reconnect (9) | 7 | – | 2 |
| host_address (18) | – | 18 | – |
| **89** | **52** | **15** | **4** |

Runs after: 52 × 2 + 4 + 15 + 18 = **141** (was 89), plus about 16 runs from the new `test/transport_test.dart`
(2 per case that runs on both channel types). Unit-only tests (the 15 "once") are RttWindow,
demo input ×3, SavedPairing JSON, InputLatency ×3, outbox ×2, gamepad mapping ×4, and the m10 local-player test.
Web-socket only: the plain status page, the two port/address tests, and the restart-on-the-same-port test
(`m6_test.dart:54`, which does `if (second.port != port) updateAddress(...)` at `:86-89`).

**File sizes.** Estimated, from the line ranges each new file takes: transport 715 lines in 10 files, host 895 in
5, client 1150 in 9; every file is under 300 by estimate. The two biggest are `host_connection.dart` (~285) and
`controller_client.dart` (~285); the estimates are ±30 lines, and if one crosses 300 at G3 the next seam is
already named in the plan (§1c: pairing message handling back out of `client_messages.dart`).

## Questions (details in the plan, §5)

1. `HostAddress.local` `display`/`label` recursion when `name` is null (`host_address.dart:74,77`).
2. `ControllerInfo.remoteAddress` is non-nullable today (`host_server.dart:53,725`); local is null. `''` + `isLocal`,
   or make it nullable?
3. `ListenFailed`/`ConnectFailed` have no `toString`; `HostService.start` prints `$e`
   (`host_service.dart:198-200`), so a failed start would show `Instance of 'ListenFailed'`.
4. `WebSocketListener.preferredPort` default: plan assumes `defaultPort` (today `host_server.dart:182`).
5. The seven hand-driven-peer tests need helper additions (`rawPeer`, a test `Connector`, one in-process listener
   per test) that the brief's three helper signatures don't provide. Go ahead, or keep them web-socket only?
6. The 15 channel-free tests: run once, or inside the per-transport loop as the contract's wording implies?

## Suggestions (not acted on)

1. **Keep every gate compiling.** With callers at G4, `HostServer({required listeners})` /
   `ControllerClient({required connector})` break `party_host`, `controller_app`, `bin` and `tool` at G3. The
   seven edits are one line each; doing them in G3 would let every gate end with `tools/check.sh` green.
2. **Consider the split as its own job.** Splitting 1652 lines into 22 files is a pure move and the riskiest part
   of this step to review; on top of the transport change it makes one large diff. If it were a separate job
   (G3a, no behaviour change, tests untouched), the transport diff would be much easier to read.
3. Two internal interfaces (`HostSessionHost`, `ClientHost`) instead of long parameter lists for the per-connection
   classes; both live in `src/` and are not exported. This is the main shape decision in the plan — worth a look
   before G2.
4. Once the helpers share one `InProcessListener` per test, a saved-pairing restart test could run on both
   transports (`m6_test.dart:54` currently can't, because it asserts the port comes back).
5. `ListenFailed.toString` returning `message` also keeps the existing TV error text readable.

## Not sure about

- **Line estimates** are from counting the ranges each file takes, not from a compiler; ±30 per file.
- **Where the heartbeat-timeout policy lives.** The plan puts `_beat`'s timer and log line in `ClientConnection`
  and leaves the retry/give-up decision with `ControllerClient` through `ClientHost`. That keeps the log line and
  the status transitions identical, but it is the least obvious seam in the plan.
- **Running the raw-WebSocket tests on both transports** costs a few helper classes; if that helper grows past
  ~60 lines it starts to rival the tests it serves.
- I did not verify the exact strings a `ListenFailed`/`ConnectFailed` should carry beyond the plan's proposal
  (contract §1 gives the fields, not the text).

## Checks run

- `wc -l docs/briefs/m12/s2-g1-plan.md` → 214 (limit 250).
- Every `file:line` the plan cites was re-checked with `sed`/`grep` against the working tree (host_address `:74`,
  `:77` were wrong on the first pass and are fixed).
- Every path the plan links to exists (`docs/design/m12-transport.md`, `docs/design/m12.md`,
  `docs/coding-guidelines.md`, `docs/architecture.md`, `docs/briefs/m12/s2-g1.md`).
- No code was changed, so no test or analyze run applies to this gate.
