import 'dart:math';

import 'package:controller/src/providers.dart';
import 'package:controller/src/tilt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// The phone held upright with its top on the left, turned like a steering
/// wheel by [deg] degrees: gyro mode turns this into a positive x tilt
/// (gyro_mode_test's pose).
Vec3 tilted(double deg) => Vec3(cos(deg * pi / 180), sin(deg * pi / 180), 0);

void main() {
  // The puzzle files are read once, before any test runs: no test here waits
  // on their real reads while it runs (s9g).
  setUpAll(loadPuzzles);

  // m12 fix-f2, R3 finding 4: tilt is the one input that sends by itself, so
  // it follows the pad, which a host phone builds only in a round.
  testWidgets('gyro mode on the host phone sends tilt only in a round', (tester) async {
    final app = await pumpHostApp(tester, saved: {'padMode': 'gyro'});
    // The mode used last comes back at launch, after the second gyro mode
    // gives the side its settle (M3), and sends where the pad is: in
    // controller mode, as it always has.
    await tester.pump(const Duration(seconds: 1));
    app.motion.hold(tilted(0), samples: 50);
    await tester.pump(const Duration(milliseconds: 100));
    final controller = app.client.inputs.length;
    app.motion.hold(tilted(15));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.client.inputs.length, greaterThan(controller), reason: 'gyro mode is on and sending');

    // Hosting on this phone: the picker has no pad (m12-host-touch rule 1), so
    // tilt has nothing to play and the sensors go off with it.
    final host = await enterHostMode(tester);
    // From here the pad's sends go to the fake, so what it sends is counted.
    hostContainer(tester).read(ownClientProvider.notifier).set(app.client);
    await tester.pump(const Duration(milliseconds: 100));
    final picker = app.client.inputs.length;
    // A new lean, which a gyro still running would send.
    app.motion.hold(tilted(30));
    await tester.pump(const Duration(milliseconds: 500));
    expect(app.client.inputs.length, picker, reason: 'the picker has no pad');
    expect(app.motion.listening, isFalse, reason: 'no sensors outside a round');

    // The join screen is outside the round too.
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
    await tester.tap(find.byKey(const Key('random-easy')));
    await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
    await tester.pump(const Duration(milliseconds: 300));
    app.motion.hold(tilted(45));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.client.inputs.length, picker, reason: 'the join screen has no pad');
    expect(app.motion.listening, isFalse);

    // The round puts the pad up with its beat, and tilt comes back with it.
    await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
    await tester.tap(find.byKey(const Key('joinStart')));
    await untilShown(tester, find.byType(party.PuzzleScreen), 'The puzzle screen');
    await until(tester, () => hostPhase(tester) != party.RoundPhase.none, () => 'The round did not start');
    // The beat runs on the round's clock: the phone is held still through it,
    // as the sensors need a reading to come back (m12-host-touch rule 3).
    app.motion.hold(tilted(0), samples: 50);
    while (hostPhase(tester) != party.RoundPhase.playing) {
      app.motion.hold(tilted(0), samples: 2);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester);
    final beat = app.client.inputs.length;
    app.motion.hold(tilted(0), samples: 50);
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.hold(tilted(15));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.client.inputs.length, greaterThan(beat), reason: 'the round has the pad');
    expect(app.motion.listening, isTrue);

    // Start pauses the round: the pad goes away, and tilt with it.
    ownClientOf(host).sendInput({ControllerButton.start});
    await untilShown(tester, find.byKey(const Key('pauseMenu')), 'The pause menu');
    ownClientOf(host).sendInput({});
    await until(tester, () => hostPhase(tester) == party.RoundPhase.none, () => 'The phase did not stop');
    await settle(tester);
    final paused = app.client.inputs.length;
    app.motion.hold(tilted(30));
    await tester.pump(const Duration(milliseconds: 500));
    expect(app.client.inputs.length, paused, reason: 'the pause menu has no pad');
    expect(app.motion.listening, isFalse);

    // Resume brings the pad and the sensors back.
    await tester.tap(find.byKey(const Key('pauseResume')));
    await until(tester, () => hostPhase(tester) == party.RoundPhase.playing, () => 'The phase did not go on');
    await settle(tester);
    final resumed = app.client.inputs.length;
    app.motion.hold(tilted(0), samples: 50);
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.hold(tilted(60));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.client.inputs.length, greaterThan(resumed), reason: 'Resume brings tilt back');

    // The own player's board goes in at once: the results are outside the
    // round, so tilt stops again.
    final match = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match;
    final board = match.gameOf(PuzzleSide.left);
    for (var i = 0; i < board.pieces.length; i++) {
      board.pieces[i]
        ..state = PieceState.locked
        ..pos = board.targetAt(i);
    }
    await untilShown(tester, find.text('Done!'), 'The results');
    await until(tester, () => hostPhase(tester) == party.RoundPhase.none, () => 'The phase did not stop');
    await settle(tester);
    final results = app.client.inputs.length;
    app.motion.hold(tilted(45));
    await tester.pump(const Duration(milliseconds: 500));
    expect(app.client.inputs.length, results, reason: 'the results have no pad');
    expect(app.motion.listening, isFalse);
    await tester.runAsync(host.dispose);
  });
}
