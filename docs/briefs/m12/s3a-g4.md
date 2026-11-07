job: m12 step3 s3a G4 — wire the view messages into the host and the client; the controller_client.dart split
stop: after G4 (s3a complete). No game_kit, no sessions, no sim_controller --view, no phone app change (s3b, s3c).
read: docs/design/m12-sessions.md §1, §2 (the contract; it wins) · docs/briefs/m12/s3a-g2-report.md · docs/briefs/m12/s3-g0-survey.md answers 4, 7, 8 · packages/connection/lib/src/{game_host,server_game_host,memory_game_host,host_server,host_connection,controller_client,client_messages,client_controls,client_types}.dart · packages/connection/test/helpers.dart · docs/protocol.md · docs/coding-guidelines.md

decisions (answers to s3a-g2-report Q1–8): Q1 Claude added the two cases (the client ignores the view messages, the host closes on them); G4 replaces the client's case with real handling · Q2 protocol.md is in this job · Q3 yes, lastAcked moves to ackSeq even without a sample · Q4, Q5, Q7, Q8 ok as they are · Q6 the real-snapshot size test goes in s3b.

do:
1 First, a pure move (no behaviour change; proven by `tools/review.sh --strings` and unchanged test counts): controller_client.dart (400 lines) → under 380. The seams:
   - The two `_snap.copyWith(...)` calls in `_scheduleRetry` and `_giveUp` become `ClientSnapshot` methods in client_types.dart: `reconnecting({detail, attempt, osErrorCode})` and `failed(problem, detail)`, which clear rttMs, rttStats and player as today.
   - `_noLog` → `noLog` in log.dart; `_sameList` → `sameStrings` in client_types.dart (neither exported).
2 `GameHost` gets the five members of contract §2, with its doc comments. `ServerGameHost`:
   - `hasViewers`: any paired controller whose hello lists `view`.
   - `inputSeq(id)`: the seq of the last applied `InputStateMessage` for that controller (survey answer 7: `HostConnection.input`); null for a local player and before any input.
   - `startView` stores the start and sends it to every viewer. `publishFrame` stores it as the latest frame and sends it (ignored before startView or after endView). `endView` sends and forgets both.
   - A viewer that pairs while a view is on (a new controller or a reconnect) gets the stored start and then the latest frame, before any later frame.
   - Each sample in a paired controller's `MetricsMessage.stages` becomes `reportStage(controllerId, stage, ms)`. The batch's `view` counts are left on the forwarded message (s3c reads them).
3 `HostServer.capabilityFor`: `ViewStartMessage`, `FrameMessage`, `ViewEndMessage` → `Capability.view`. `sendToAll` encodes the message once and sends the same text to each controller (say in the report how).
4 `MemoryGameHost`: `viewStarts`, `frames`, `viewEnds` lists; `hasViewers` settable (default false); `inputSeqs` map read by `inputSeq`. `FakeGameHost` (party_host/lib/src/testing/host_fakes.dart): the same minimal members.
5 Client: `ControllerClient.view` (`Stream<ViewEvent>`, broadcast) with sealed `ViewEvent`: `ViewStarted(start)`, `ViewFrame(frame, arrivedAtMs)` (the client's clock when the message was handled), `ViewEnded(end)`, in client_controls.dart or a new client_view.dart. They're emitted only while connected and only if the client's identity lists `view`; otherwise logged as unexpected and dropped, as for layout and status. ControllerClient gains only the getter.
6 docs/protocol.md: a "Viewing the game (M12)" section: contract §1's table, the `at` rule from contract §3, and the late-joiner rule. Add the metrics batch's `stages` and `view` to its metrics section, and the three messages to the direction summary.
7 Tests, on both transports (`TestTransport.values`, as m10_test.dart):
   - A controller without `view` gets none of the three messages; one with `view` gets start, frames and end in order, with every field intact.
   - `hasViewers`: false with none, true once a viewer pairs, false after it disconnects; a non-viewer never counts.
   - Late joiner: startView, frames n 0, 1, 2, then a viewer pairs → it gets start, then frame 2, and nothing older. After endView a new viewer gets nothing. A viewer that drops and reconnects mid-view gets start and the latest frame again.
   - publishFrame before startView and after endView sends nothing.
   - `inputSeq`: null before input; 3 after inputs seq 1, 2, 3; an older seq after that leaves it at 3; a local player's is null.
   - Metrics: a paired viewer's batch with `stages: {touch_to_frame: [40, 62], frame_jitter: [0]}` gives three stage samples for that controller with those ms (on `ServerGameHost.stages`); none from an unpaired one.
   - Client: `view` events in order with `arrivedAtMs` set; a client not listing `view` emits nothing even if a raw peer sends them (the `rawPeer` test connector).
   - MemoryGameHost records the calls.
8 Report: line counts of every file touched (flag > 300); the --strings result for step 1; test counts before and after per file; how sendToAll encodes once.

rules: no public API change outside the contract; existing tests unchanged (only new ones; say if one had to change and why); no file over 400; controller_client.dart under 380 · tools/review.sh: no FAIL on your lines.
allow: packages/connection · packages/party_host/lib/src/testing/host_fakes.dart · docs/protocol.md
check: format analyze protocol connection metrics arena puzzle host phone tv
report: docs/briefs/m12/s3a-g4-report.md
