import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/choice_round_pausable.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_controller.dart';
import 'package:protocol/protocol.dart';

const _cards = [ChoiceCard(id: 'save', title: 'Save +2')];

/// The grace time of the round, in ms; short so a default that wrongly comes shows within the test.
const _graceMs = 200;

/// How long a test waits past the grace time, so an away timer left running would have fired.
const _pastGrace = Duration(milliseconds: 500);

/// The round's length, in ms; long, so only the clock the test sets can end it.
const _roundMs = 30000;

/// The fake-clock reading a test pauses at, in ms.
const _pauseAtMs = 4000;

/// The most time a test waits for a state, so a stuck test fails.
const _waitLimit = Duration(seconds: 5);

/// The gap between two polls.
const _pollStep = Duration(milliseconds: 10);

const _player = 'phone-1';

final class _Clock {
  int ms = 0;
}

final class _Setup {
  _Setup(this.server, this.client, this.round, this.controller, this.clock, this.seen);

  final HostServer server;
  final ControllerClient client;
  final ChoiceRound round;
  final NightFlowController controller;
  final _Clock clock;

  /// Every ChoicesMessage the phone got, in order.
  final List<ChoicesMessage> seen;
}

Future<void> _until(bool Function() test) async {
  final watch = Stopwatch()..start();
  while (!test()) {
    if (watch.elapsed > _waitLimit) throw TimeoutException('condition not met after $_waitLimit');
    await Future<void>.delayed(_pollStep);
  }
}

/// A real host and capable phone over the in-process link, a started round and a night in its round stage.
/// [pauseFirst]: the night is paused before the round is started and handed to the pausable.
Future<_Setup> _setup({bool pauseFirst = false}) async {
  final link = InProcessListener();
  final server = HostServer(
    hostId: 'host-1',
    hostName: 'Test TV',
    appVersion: 'test',
    listeners: [link],
    heartbeatInterval: const Duration(milliseconds: 100),
    heartbeatTimeout: const Duration(milliseconds: 1500),
    capabilities: const [Capability.choices],
  );
  await server.start();
  final client = ControllerClient(
    identity: const ControllerIdentity(
      controllerId: _player,
      name: 'Phone',
      platform: 'android',
      appVersion: 'test',
      capabilities: [Capability.choices],
    ),
    connector: InProcessConnector(link),
    heartbeatInterval: const Duration(milliseconds: 100),
    heartbeatTimeout: const Duration(milliseconds: 1500),
    retryDelays: const [Duration(minutes: 5)],
  );
  final seen = <ChoicesMessage>[];
  final sub = client.choices.listen(seen.add);
  client.connect(
    HostAddress.local(hostId: server.hostId, name: 'Test TV'),
    code: server.pairingCode,
  );
  await client.changes.firstWhere((s) => s.isConnected).timeout(_waitLimit);
  final clock = _Clock();
  final round = ChoiceRound(
    server: server,
    players: const [_player],
    setup: ChoiceRoundSetup(round: 1, title: 'Shop', cardsFor: (_) => _cards, defaultId: 'save'),
    timing: ChoiceTiming(
      duration: const Duration(milliseconds: _roundMs),
      grace: const Duration(milliseconds: _graceMs),
      nowMs: () => clock.ms,
    ),
  );
  final controller = NightFlowController(rounds: 3)..begin();
  controller.startNow();
  expect(controller.flow.stage, NightStage.round);
  addTearDown(() async {
    await sub.cancel();
    controller.dispose();
    await client.dispose();
    await round.dispose();
    await server.dispose();
  });
  if (pauseFirst) expect(controller.pause(), isTrue);
  round.start();
  await _until(() => seen.isNotEmpty);
  return _Setup(server, client, round, controller, clock, seen);
}

void main() {
  test('a night pause makes the phone get a ChoicesMessage with paused true and keeps the picks', () async {
    final s = await _setup();
    ChoiceRoundPausable(round: s.round, controller: s.controller);
    s.round.pick(_player, pickId: 'save');
    s.clock.ms = _pauseAtMs;

    expect(s.controller.pause(), isTrue);
    await _until(() => s.seen.last.paused);

    expect(s.round.isPaused, isTrue);
    expect(s.seen.last.paused, isTrue);
    expect(s.seen.last.endsInMs, _roundMs - _pauseAtMs);
    expect(s.round.lockedIds, isEmpty);
  });

  test('a phone dropped during the night pause gets no default after the grace time', () async {
    final s = await _setup();
    ChoiceRoundPausable(round: s.round, controller: s.controller);
    s.controller.pause();
    s.server.dropAllConnections();
    await _until(() => s.server.snapshot.controllers.every((c) => c.state == ControllerState.disconnected));

    await Future<void>.delayed(_pastGrace);

    expect(s.round.lockedIds, isEmpty);
    expect(s.round.isClosed, isFalse);
  });

  test('a night resume makes the phone get paused false and endsInMs the time left', () async {
    final s = await _setup();
    ChoiceRoundPausable(round: s.round, controller: s.controller);
    s.clock.ms = _pauseAtMs;
    s.controller.pause();
    await _until(() => s.seen.last.paused);
    s.clock.ms = _pauseAtMs + _roundMs ~/ 2;

    expect(s.controller.resume(), isTrue);
    await _until(() => !s.seen.last.paused);

    expect(s.round.isPaused, isFalse);
    expect(s.seen.last.endsInMs, _roundMs - _pauseAtMs);
  });

  test('a night already paused when the pausable is built pauses the started round', () async {
    final s = await _setup(pauseFirst: true);

    ChoiceRoundPausable(round: s.round, controller: s.controller);
    await _until(() => s.seen.last.paused);

    expect(s.round.isPaused, isTrue);
  });

  test('closing the round while paused removes the pausable so a later night pause leaves the round alone', () async {
    final s = await _setup();
    ChoiceRoundPausable(round: s.round, controller: s.controller);
    s.controller.pause();

    s.round.close();
    await Future<void>.delayed(Duration.zero);

    expect(s.round.isClosed, isTrue);
    expect(s.controller.resume(), isTrue);
    expect(s.controller.pause(), isTrue);
    expect(s.round.isPaused, isFalse);
  });

  test('a night paused first, then the round closed, then roundEnded does not throw', () async {
    final s = await _setup();
    ChoiceRoundPausable(round: s.round, controller: s.controller);
    s.controller.pause();
    s.round.close();
    await Future<void>.delayed(Duration.zero);

    expect(s.controller.roundEnded, returnsNormally);
    expect(s.controller.isPaused, isFalse);
  });

  test('detach takes the pausable out so a night pause does not reach the round', () async {
    final s = await _setup();
    ChoiceRoundPausable(round: s.round, controller: s.controller).detach();

    s.controller.pause();

    expect(s.round.isPaused, isFalse);
  });
}
