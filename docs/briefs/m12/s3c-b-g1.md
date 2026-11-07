job: m12 step3 s3c-b G1 — plan for the measuring tools
stop: after G1. A plan only: no code, no file changes except the plan.
read: docs/design/m12-sessions.md §1, §2, §4, §6 (the contract; it wins) · docs/design/m12.md §2.5, §5 step 3 · docs/coding-guidelines.md · docs/dev-tools.md (tv-dev.sh, tv-window.ps1, smoke.sh) · packages/connection (lib/src/{controller_client,client_*,viewer_timing,viewer_stats}.dart, bin/sim_controller.dart) · packages/metrics (bin/report.dart, lib) · packages/protocol/lib/src/{metrics,view}.dart · packages/game_kit/lib · packages/party_host/lib (where a game screen is opened, and how the TV picks Shape Race's puzzle, difficulty and teams) · packages/test_game/lib/src/arena_view.dart · packages/puzzle_game/lib/src/play_view.dart (being rewritten in s3b G4; plan against the session API in docs/briefs/m12/s3b-g1-plan.md §2) · tools/{smoke,tv-dev}.sh · tv_test_app/lib

the job the plan is for (s3c-b G4, after s3b G4 and s3c-a land):
1 Client wiring: a `ControllerClient` that lists `Capability.view` owns one `ViewerStats` (exposed, for FrameView), calls `inputSent(seq, nowMs)` for every input it sends, and puts `drain()`'s `stages` and `view` into each metrics batch it sends. No change for a client without `view`.
2 `sim_controller --view`: lists `view`; feeds `ViewerTiming`, a `PlayoutBuffer` and the client's `ViewerStats` without drawing; a 60 Hz timer is its "draw": a frame counts as drawn the first time `renderAtMs` passes its `at`. At the end it prints `touch_to_frame` and `frame_jitter` (median, p95, count), frames/gaps/late, and the frame size in bytes (mean, max). It needs to send inputs while viewing so acks arrive (the existing `--stream`?). `sim_controller.dart` is 266 lines: say how it splits to stay ≤ 300.
3 The metrics report (`packages/metrics`) prints `touch_to_frame` and `frame_jitter` (median, p95) and the view counts next to the input delay, per controller and in the summary.
4 Debug-only start options for the development TV app, passed by `tools/tv-dev.sh start [--hz 20|30|60] [--game arena|shape_race]` as `--dart-define`s: the frame rate reaches every `GameSession` (proposal: `HostingSettings.fromEnvironment()` in game_kit, used when no settings are given; range-checked, 60 when unset), and `--game` opens that game straight from launch in debug builds only (Shape Race: the first Easy puzzle, one team, whoever is connected). Release builds ignore both.
5 `tools/smoke.sh` gains a `frames` step: start the dev TV app with `--game arena`, run a `--view --stream` sim for its run, and pass when the sim prints a touch-to-frame median; print the median and the frame size.

the plan must answer, with file:line facts:
- every file touched or created, its size now and after, and the order; anything over 300 after (lib) and how it splits.
- 1: where the client sends inputs and builds metrics batches today; where `seq` comes from; how the phone app's metrics batches are built (does the change reach them without a phone app edit?).
- 2: how the sim's run and summary are structured today; which option makes it send inputs; how it would measure frame bytes (the raw text length of each `frame` message is fine).
- 4: every place a `GameSession` (`ArenaSession`, `PuzzleSession`) is constructed and how settings would reach it; the shortest debug-only path from launch to a running Arena and a running Shape Race in party_host / tv_test_app, and what it skips (pairing screen? player join?). If a debug start that skips menus would need more than ~60 lines in party_host, propose instead driving the menus with `tools/tv-window.ps1` keys and give the key sequence.
- 5: how smoke.sh's steps and the sim's run line up; how long the frames step adds.
- conflicts with the contract or the s3b G4 / s3c-a work, and questions (numbered), each with your proposed answer.

rules: read-only except the plan file. Facts with file:line. Don't paste code longer than 5 lines.
allow: docs/briefs/m12/s3c-b-g1-plan.md
report: docs/briefs/m12/s3c-b-g1-report.md
