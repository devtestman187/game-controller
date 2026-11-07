job: m12 step5 s5a G4 — the host side of host mode: resume, presence, kind, tablet
stop: after G4 (G2 → G4 in one job). No phone app change (s5b). No change to how the TV looks or behaves.
read: docs/design/m12-host-mode.md §0, §1, §2, §4 (the contract; it wins) · docs/briefs/m12/s5-g0-survey.md (facts) · docs/coding-guidelines.md · packages/party_host (lib, test) · packages/connection/lib/src/{host_server,transport/*}.dart · packages/metrics/lib/src/session.dart · tv_test_app/lib/src/tv_host_setup.dart · tv_test_app/test

do:
1 `packages/metrics`: `HostType.tablet = 'tablet'` (session.dart:80-85). session.dart is 424 lines: first move `DelayStats` and `RatingScheduler` (`:10-79`) to `lib/src/session_stats.dart` as a pure move (prove with `tools/review.sh --strings`; export unchanged through the library), so it ends under 400.
2 `HostIdentity` gains `kind` (`String`, one of `HostKind.tv`, `.pc`, `.phone`, `.tablet`: a new `abstract final class HostKind` of string constants beside it, with the TXT key `kind`) and `serviceName` (the advertised name). `tvHostIdentity()` sets `kind` (`tv` on Android, `pc` on Windows, `pc` otherwise) and `serviceName` from today's "Thumb Party TV (…)" logic (move it, don't change it). The host log line and exported log header that name the host use `serviceName`.
3 The TXT record (`host_service.dart:280`) adds `kind`. Discovery on the phone ignores unknown keys, so no phone change.
4 `LiveHostService` takes an optional `InProcessListener inProcess` and adds it to the `HostServer`'s listeners (`host_service.dart:102-115`). host_service.dart is 305 lines: keep it ≤ 330, or move the advertising part (`:274-295`) into `host_advertising.dart`.
5 `HostService.resume()` (abstract member; `LiveHostService` implements it, `FakeHostService` records calls): if the server isn't listening, start it again on the same port (fall back to any port, as `_bind` does, and update `state`); if advertising isn't running, start it again. Does nothing when both run.
6 `HostPresence` (`lib/src/host_presence.dart`) exactly as contract §2, with `hostAwayProvider` (a `Provider<ValueListenable<bool>>`, default: a constant false notifier, so the TV never pauses this way). `Pausable` pauses its builder while `away` is true, without opening the menu, and unpauses when it's false again. `onAbandon` is supplied by the shell; party_host provides `abandonRound(BuildContext)` that pops to `gamesRouteName`, and the session ends its view with `ViewEndReason.abandoned` and records `round_end` with `reason: abandoned` (add `GameSession.dispose({ViewEndReason reason})` only if needed, keeping `finished:` working; say what you chose).
7 Export the new types from `party_host.dart`.

tests:
- metrics: `HostType.tablet` round-trips through a session summary and the report prints it.
- party_host `host_presence_test`: fake clock and `FakeHostService`: hidden at 0, shown at 10 s → `away` false, `resume` called once, `onAbandon` not called; hidden at 0, shown at 31 s → `onAbandon` once, `resume` once; hidden twice without shown → one away period; `away` true between; dispose stops listening.
- party_host: a `Pausable` with `away` true: the builder gets `paused == true` and no pause menu is shown; false again → `paused == false`.
- party_host: `LiveHostService` with an in-process listener: a client over `InProcessConnector` and one over WebSocket both pair and both are players (`gameHost.players` length 2). Use the existing host test helpers; no real network beyond loopback.
- party_host: `resume()` after the server was stopped listens again on the same port; when both run it does nothing (no second advertise call on a fake advertiser).
- party_host: the TXT map passed to the advertiser has `id`, `v` and `kind`.
- tv_test_app: `tvHostIdentity()` has kind `pc` on Windows (the test runs on Windows) and the same service name as before.
- Existing tests: no expected value changes. If one has to change, list it old → new with the reason.

report: line counts of every file touched or created (flag > 300), the `--strings` proof of the session.dart move, test counts per check before and after, what you chose in do 6.
rules: no file over 400 (tests 500); every new lib file ≤ 300; no wire change other than the TXT `kind`; the TV's screens and behaviour unchanged · tools/review.sh: no FAIL on your lines.
allow: packages/metrics · packages/party_host · packages/game_kit/lib/src/game_session.dart · packages/game_kit/test · tv_test_app/lib · tv_test_app/test
pub: yes
check: format analyze protocol connection metrics kit arena puzzle host phone tv
report: docs/briefs/m12/s5a-report.md
