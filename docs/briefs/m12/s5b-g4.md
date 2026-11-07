job: m12 step5 s5b G4 — host mode complete: the own player's pad, C34, Stop hosting, lifecycle, abandoned rounds
stop: after G4. Step 5 ends here.
read: docs/briefs/m12/s5b-g3-report.md (where G3 stopped, and why) · docs/briefs/m12/s5b-g1-plan.md §6, §9, §10 · docs/design/m12-host-mode.md (contract) · docs/coding-guidelines.md · controller_app (lib, test) · packages/party_host/lib/src/{host_presence,providers}.dart, ui/{pause_menu,puzzle_screen,game_screen}.dart · packages/game_kit/lib/src/game_session.dart · packages/test_game/lib/src/{arena_session,arena_view}.dart · packages/puzzle_game/lib/src/{puzzle_session,puzzle_report,play_view}.dart

decisions:
- Q-A, the scope (G3 report option 1, in this shape): in `providers/connection.dart`, today's `clientProvider` body becomes `tvClientProvider` (unchanged: the WebSocket client, its tokens, `lastHost`). New `ownClientProvider` (a `Notifier<ControllerClient?>`, null; `set`/`clear`) in the same file, so nothing imports `host/`. `clientProvider = Provider((ref) => ref.watch(ownClientProvider) ?? ref.watch(tvClientProvider))`, with no `onDispose` of its own (each client's owner disposes it: the TV client its provider, the own client `PhoneHost`). `HostingNotifier.start` sets `ownClientProvider` to the host's client before the route opens; stop clears it. Drop the host route's nested `ProviderScope`. While hosting the TV client stays built and idle (G3's guards already stop its reconnects).
- Q-B: `connect_panels.dart` may stay at ~298; if this job adds lines to it, move the per-status widgets to `connect_status.dart`.
- Q-C: the chip's badge goes back to `clientStateProvider`.
- Abandoned rounds (contract §2, s5a's open item):
  - `GameSession.abandon()`: ends the view with `ViewEndReason.abandoned` and marks the session disposed, so a later `dispose` does nothing. Subclasses override it to record first: `PuzzleSession` writes `round_end` with `data: {reason: abandoned}` (no winner) unless the match already has a result; `ArenaSession` writes `round_end` with `{reason: abandoned}` if a round is running, then its `frames` record as `dispose` does.
  - `PuzzlePlayView` and `ArenaView` take an optional `Listenable? abandon`; when it fires, they call `_session.abandon()`.
  - party_host: `AbandonSignal extends ChangeNotifier` with `void fire()`, and `hostAbandonProvider` (one instance per container). `PuzzleScreen` and `GameScreen` pass `ref.read(hostAbandonProvider)` to the views. `abandonRound(context)` fires it, then pops as today.
  - The phone: `PhoneHost`'s `onAbandon` fires the root container's `hostAbandonProvider`, then pops the games navigator (G3's `abandon()`).

do, in this order, every check green after each slice:
1 Q-A. Then finish plan §9's test: steps 4–6 (labels on the pad, A through the menus, Shape Race solo starts with the own player on the left).
2 S2 (plan §10): "Show on this device" and "Stop hosting" (chip menu and system back), a second "Host a game" after stopping.
3 S3: the lifecycle and switch-offs (`host_lifecycle_test.dart`); `FakeHostService.resumes` exists if a fake is easier than the real service.
4 S4: `hosting_test.dart` and the connect screen cases.
5 Abandoned rounds as decided above, with tests: game_kit `abandon()` ends the view `abandoned` once and a later dispose sends nothing; puzzle: abandoning mid-match records one `round_end` with `reason: abandoned`, abandoning after the result records nothing new; arena: mid-round → `round_end` abandoned + `frames`; party_host: `abandonRound` fires the signal and pops; phone: hidden 31 s then shown → the games screen, and the session's last view_end is `abandoned` (or the signal fired, if the view isn't reachable from the test).

tests: as above and plan §10. Existing tests: no expected value changes; list any old → new with the reason.
report: line counts of every file touched or created (flag > 300), test counts per check before and after, deviations, and the questions left.
rules: no lib file over 400 (tests 500); new lib files ≤ 300; `controller_client.dart` (398) must not grow; every party_host import in controller_app is `as party`; the TV app's behaviour unchanged · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s5b-g4-report.md · controller_app/lib · controller_app/test · packages/party_host · packages/game_kit/lib/src/game_session.dart · packages/game_kit/test · packages/test_game/lib · packages/test_game/test · packages/puzzle_game/lib · packages/puzzle_game/test
pub: yes
check: format analyze protocol connection metrics kit arena puzzle host phone tv
report: docs/briefs/m12/s5b-g4-report.md
