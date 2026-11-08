import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';

import 'support/fake_game.dart';

/// A host whose clock the test moves, plus the elapsed time a Ticker would hand
/// the session, so no test waits for real time.
final class Clock {
  int nowMs = 0;
  Duration elapsed = Duration.zero;
  late final MemoryGameHost host = MemoryGameHost(now: () => nowMs);

  /// One drawn frame, [ms] after the last.
  void frame(GameSession session, int ms) {
    nowMs += ms;
    elapsed += Duration(milliseconds: ms);
    session.advance(elapsed);
  }

  /// [n] drawn frames of 16 ms each, as a 60 Hz display gives them.
  void frames(GameSession session, int n) {
    for (var i = 0; i < n; i++) {
      frame(session, 16);
    }
  }
}

void main() {
  test('the rules step at a fixed rate whatever the frames run at', () {
    final sixty = Clock();
    final a = CounterSession(host: sixty.host);
    sixty.frames(a, 60);
    expect(a.stepCount, 57, reason: '60 frames of 16 ms are 0.96 s: 57 steps');

    final ninety = Clock();
    final b = CounterSession(host: ninety.host);
    ninety.frames(b, 90);
    expect(b.stepCount, 86, reason: '90 frames of 16 ms are 1.44 s: 86 steps');
  });

  test('a long gap runs at most 0.1 s of steps, then steps normally again', () {
    final clock = Clock();
    final session = CounterSession(host: clock.host);
    clock.frame(session, 2000);
    expect(session.stepCount, 6, reason: '0.1 s of catch-up is six steps');
    clock.frame(session, 16);
    clock.frame(session, 16);
    expect(session.stepCount, 7, reason: '0.1 s is exactly six steps, so the seventh comes on the second 16 ms');
  });

  test('nothing steps or is sent while paused, and resuming does not catch up', () {
    final clock = Clock()..host.hasViewers = true;
    final session = CounterSession(host: clock.host)..paused = true;
    clock.frames(session, 60);
    expect(session.stepCount, 0);
    expect(clock.host.frames, isEmpty);
    session.paused = false;
    clock.frame(session, 16);
    expect(session.stepCount, 0, reason: 'the paused time is dropped, not caught up');
    clock.frame(session, 16);
    expect(session.stepCount, 1);
  });

  // m12 bug 1107e: an input that arrived while the round was paused waited
  // for the round, not for the host, so it is no received_to_drawn sample.
  test('an input that arrived while paused is no received_to_drawn sample', () {
    final clock = Clock()..host.hasViewers = true;
    clock.host.setPlayer(const GamePlayer(id: 'a', number: 1));
    final session = CounterSession(host: clock.host);
    clock.frame(session, 16);
    session.drawn();

    // A press arrives 50 ms into a 70 ms pause: short enough that the frame
    // that comes back is no stall.
    session.paused = true;
    clock.frame(session, 50);
    clock.host.setGamepad('a', const GamepadState(buttons: {GamepadButton.a}));
    clock.frame(session, 20);
    session.paused = false;
    clock.frame(session, 16);
    session.drawn();
    expect(clock.host.stages, isEmpty, reason: 'it waited out the pause, not for the host');

    // An input that arrives once the round is back is measured.
    clock.host.setGamepad('a', GamepadState.neutral);
    clock.frame(session, 16);
    session.drawn();
    expect(clock.host.stages.single, (playerId: 'a', stage: LatencyStage.receivedToDrawn, ms: 16));
  });

  test('steps run without viewers, but frames are not built', () {
    final clock = Clock();
    final session = CounterSession(host: clock.host);
    clock.frames(session, 60);
    expect(session.stepCount, 57);
    expect(clock.host.frames, isEmpty);
    clock.host.hasViewers = true;
    clock.frame(session, 16);
    expect(clock.host.frames, hasLength(1), reason: 'the first step after a viewer pairs is a frame');
    expect(clock.host.frames.single.n, session.stepCount - 1);
  });

  test('frames come at the frame rate', () {
    for (final (hz, count) in [(60, 57), (30, 29), (20, 19)]) {
      final clock = Clock()..host.hasViewers = true;
      final session = CounterSession(
        host: clock.host,
        settings: HostingSettings(frameRateHz: hz),
      );
      clock.frames(session, 60);
      expect(session.stepCount, 57);
      expect(clock.host.frames, hasLength(count), reason: '57 steps at $hz Hz');
    }
  });

  test('the steps of one long advance get evenly spaced times', () {
    final clock = Clock()..host.hasViewers = true;
    final session = CounterSession(host: clock.host);
    clock.frame(session, 100);
    expect(clock.host.frames.map((f) => f.n), [0, 1, 2, 3, 4, 5]);
    expect(clock.host.frames.map((f) => f.atMs), [17, 33, 50, 67, 83, 100]);
  });

  test('a sound played twice in one advance plays once and is carried once', () {
    final clock = Clock()..host.hasViewers = true;
    final session = CounterSession(host: clock.host, playSounds: const ['hit', 'hit']);
    clock.frame(session, 100);
    expect(session.stepCount, 6);
    expect(clock.host.sounds, ['hit'], reason: 'six steps call it, but a sound plays once an advance');
    expect(clock.host.frames.expand((f) => f.sounds), ['hit'], reason: 'the first frame carries it, the rest do not');
  });

  test('sounds from before a viewer joined are not sent to it', () {
    final clock = Clock();
    final session = CounterSession(host: clock.host, playSounds: const ['hit']);
    clock.frames(session, 600);
    expect(clock.host.sounds, hasLength(greaterThan(500)), reason: 'the TV plays them all');
    clock.host.hasViewers = true;
    clock.frame(session, 17);
    expect(clock.host.frames, hasLength(1));
    expect(clock.host.frames.single.sounds, ['hit'], reason: 'only the sound of the step the frame carries');
  });

  test('at 20 Hz a sound repeated over a frame interval is carried once', () {
    final clock = Clock()..host.hasViewers = true;
    final session = CounterSession(
      host: clock.host,
      playSounds: const ['tick'],
      settings: const HostingSettings(frameRateHz: 20),
    );
    clock.frames(session, 60);
    expect(clock.host.frames, isNotEmpty);
    for (final f in clock.host.frames) {
      expect(f.sounds, ['tick']);
    }
  });

  test('the view starts when the session is made and ends once', () {
    final clock = Clock();
    final session = CounterSession(host: clock.host);
    final start = clock.host.viewStarts.single;
    expect(start.game, 'fake');
    expect(start.snapshotVersion, 7);
    expect(start.setup, {'k': 'v'});
    expect(start.hz, 60);

    session.dispose();
    session.dispose(finished: true);
    expect(clock.host.viewEnds.single.reason, ViewEndReason.quit);

    CounterSession(host: clock.host).dispose(finished: true);
    expect(clock.host.viewEnds.last.reason, ViewEndReason.finished);
  });

  test('frames carry the acks and the roster', () {
    final clock = Clock()..host.hasViewers = true;
    clock.host
      ..setPlayer(const GamePlayer(id: 'a', number: 1, nickname: 'Phone a'))
      ..setPlayer(const GamePlayer(id: 'b', number: 2));
    clock.host.inputSeqs['a'] = 4;
    final session = CounterSession(host: clock.host);
    clock.frame(session, 100);
    final frame = clock.host.frames.first;
    expect(frame.acks, {'a': 4}, reason: 'only the player with an input has an ack');
    expect(frame.roster, {'a': (number: 1, name: 'Phone a'), 'b': (number: 2, name: '')});
  });

  test('a button pressed and released between two steps still reaches one step', () {
    final clock = Clock();
    clock.host.setPlayer(const GamePlayer(id: 'a', number: 1));
    final session = CounterSession(host: clock.host);
    clock.host.setGamepad('a', const GamepadState(buttons: {GamepadButton.a}));
    clock.frame(session, 16);
    expect(session.stepCount, 0, reason: 'the first 16 ms frame runs no step');
    clock.host.setGamepad('a', GamepadState.neutral);
    clock.frame(session, 16);
    clock.frame(session, 16);
    expect(session.seen, [
      {
        'a': {GamepadButton.a},
      },
      {'a': <GamepadButton>{}},
    ], reason: 'the press reaches the first step and the release the one after it');
  });

  test('dispose stops the loop and ends the view once', () {
    final clock = Clock()..host.hasViewers = true;
    final session = CounterSession(host: clock.host);
    clock.frames(session, 10);
    final frames = clock.host.frames.length;
    expect(frames, isPositive);
    session.dispose();
    clock.frames(session, 10);
    expect(clock.host.frames, hasLength(frames));
    expect(clock.host.viewEnds, hasLength(1));
  });

  test('an abandoned round ends the view abandoned, once, and runs no more steps', () {
    final clock = Clock()..host.hasViewers = true;
    final session = CounterSession(host: clock.host);
    clock.frames(session, 10);

    session.abandon();
    expect(session.isDisposed, isTrue);
    expect(clock.host.viewEnds.single.reason, ViewEndReason.abandoned);

    // A later dispose, finished or not, sends nothing more.
    session.dispose();
    session.dispose(finished: true);
    expect(clock.host.viewEnds, hasLength(1), reason: 'the view ended once');

    final steps = session.stepCount;
    final frames = clock.host.frames.length;
    clock.frames(session, 10);
    expect(session.stepCount, steps, reason: 'the host lost the round: no step runs after it');
    expect(clock.host.frames, hasLength(frames));
  });
}
