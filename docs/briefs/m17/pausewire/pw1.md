job: pausewire pw1 — a choice round joins the night's pause seam
stop: no host buttons, no ShopDemo change, no protocol change, no night start path (build stop is M17b)
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_flow_controller.dart:20-30,168-200,278-290 · packages/connection/lib/src/choice_round.dart:55-130,160-190 · packages/connection/test/choice_round_pause_test.dart:60-130,265-310 · packages/party_host/test/live_stats_lifecycle_test.dart:30-150 (real HostServer plus ControllerClient over InProcessListener) · owner Q1 A (Nov 26): "the night controller owns pause; end AND grace timers freeze, picks kept, phones show Paused, no default for drops until resume"
changes: ChoiceRoundPausable (new class, implements NightPausable) · ChoicesMessage.paused read only
model: sonnet
turns: 50
expected-min: 25
tests-first: exempt ChoiceRound.pause/resume and the controller seam exist; the new adapter is what the test covers and the test is written with it
do:
1 New lib file packages/party_host/lib/src/night/choice_round_pausable.dart: `final class ChoiceRoundPausable implements NightPausable` with ctor `ChoiceRoundPausable({required ChoiceRound round, required NightFlowController controller})`. It calls controller.addPausable(this) in the ctor, pause()/resume() forward to round.pause()/round.resume(), and it calls controller.removePausable(this) (and cancels its subscription) when round.isClosed turns true (listen to round.changes) or on a `detach()` method. If controller.isPaused at construction and the round is started, call round.pause(). One-line doc comments. Export nothing new from party_host.dart unless an existing night export file already lists sibling night classes (then add it there).
2 New test packages/party_host/test/choice_round_pausable_test.dart with a real HostServer, a capable ControllerClient (Capability.choices) and a real ChoiceRound plus a real NightFlowController driven into a played round (see night_flow_controller_test.dart for how). Cases: night pause -> the phone's last ChoicesMessage has paused true; a phone dropped during the pause gets no default after the grace time; resume -> paused false and endsInMs is the remaining time; closing the round while paused works and the pausable is removed (a later night pause does not touch the round); a night paused first, then round closed, then roundEnded does not throw.
3 Write the NEW test first and run it, then lib, then the report.
allow: packages/party_host/lib/src/night/choice_round_pausable.dart · packages/party_host/lib/party_host.dart · packages/party_host/test/choice_round_pausable_test.dart
check: format analyze host
report: docs/briefs/m17/pausewire/pw1-report.md
