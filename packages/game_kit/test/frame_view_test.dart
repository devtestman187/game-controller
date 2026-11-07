import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/fake_view.dart';

/// The phone's clock in ms: the test moves it, and the view draws for it.
final class Clock {
  int nowMs = 0;
}

/// The roster every test's frames carry.
const players = {'p1': (number: 1, name: 'Ada')};

ViewStarted startEvent({
  String game = 'dot',
  int snapshotVersion = DotSnapshot.version,
  Map<String, Object?> setup = const {'start': 0},
  int hz = 60,
}) => ViewStarted(ViewStartMessage(game: game, snapshotVersion: snapshotVersion, setup: setup, hz: hz));

/// A frame the host ran at [atMs] with the dot at [x], arriving on time.
ViewFrame frameEvent(
  int n, {
  required int atMs,
  required double x,
  Map<String, int> acks = const {},
  Map<String, ({int number, String name})> roster = const {},
}) => ViewFrame(
  FrameMessage(n: n, atMs: atMs, snapshot: {'v': DotSnapshot.version, 'x': x}, acks: acks, roster: roster),
  atMs,
);

void main() {
  late StreamController<ViewEvent> events;
  late ViewerStats stats;
  late Clock clock;

  setUp(() {
    events = StreamController<ViewEvent>.broadcast();
    stats = ViewerStats(hz: 60);
    clock = Clock();
  });

  tearDown(() => events.close());

  /// The view under test, on the test's clock and stats.
  Widget underTest({Stream<ViewEvent>? stream, String? playerId, GameRegistry? registry}) => Directionality(
    textDirection: TextDirection.ltr,
    child: FrameView(
      views: stream ?? events.stream,
      registry: registry ?? GameRegistry([const DotModule()]),
      stats: stats,
      nowMs: () => clock.nowMs,
      playerId: playerId,
    ),
  );

  /// Mounts a [FrameView] on the test's stream, clock and stats.
  Future<void> mount(WidgetTester tester, {String? playerId, GameRegistry? registry}) =>
      tester.pumpWidget(underTest(playerId: playerId, registry: registry));

  /// Delivers [event] to the view (a stream is asynchronous) and draws the
  /// frame that follows it.
  Future<void> send(WidgetTester tester, ViewEvent event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  /// One more drawn frame, [ms] (16 by default) later on both clocks.
  Future<void> tick(WidgetTester tester, [int ms = 16]) async {
    clock.nowMs += ms;
    await tester.pump(Duration(milliseconds: ms));
  }

  /// Unloads the view, so its Ticker is disposed before the test ends.
  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox.shrink());

  /// The dot the view drew, and what its viewer was given.
  DotDraw drawn(WidgetTester tester) => tester.widget<DotDraw>(find.byType(DotDraw));

  testWidgets('nothing is drawn before a start, and a frame before one is ignored', (tester) async {
    await mount(tester);
    expect(find.byType(DotDraw), findsNothing);
    expect(find.text(updateAppText), findsNothing);

    clock.nowMs = 1000;
    await send(tester, frameEvent(0, atMs: 1000, x: 0.5));
    await tick(tester);
    expect(find.byType(DotDraw), findsNothing);
    final drained = stats.drain();
    expect(drained.view.frames, 0);
    expect(drained.stages, isEmpty, reason: 'an ignored frame records no jitter either');

    await unmount(tester);
  });

  testWidgets('an unknown game, a newer version and a bad setup say update the app, and a good start draws', (
    tester,
  ) async {
    await mount(tester);
    final starts = [
      startEvent(game: 'puzzle'),
      startEvent(snapshotVersion: DotSnapshot.version + 1),
      startEvent(setup: const {}),
    ];
    for (final start in starts) {
      await send(tester, start);
      expect(find.text(updateAppText), findsOneWidget, reason: '${start.start.game} v${start.start.snapshotVersion}');
    }

    clock.nowMs = 1000;
    await send(tester, frameEvent(0, atMs: 1000, x: 0.5));
    await tick(tester);
    expect(find.byType(DotDraw), findsNothing, reason: 'frames after an update message are ignored');

    await send(tester, startEvent());
    expect(find.text(updateAppText), findsNothing);
    expect(find.byType(DotDraw), findsNothing, reason: 'nothing is drawn until the first frame');
    await send(tester, frameEvent(0, atMs: 1000, x: 0.5));
    expect(drawn(tester).snapshot.x, 0.5);

    await unmount(tester);
  });

  testWidgets('one frame is drawn, and the view never runs past the newest frame', (tester) async {
    await mount(tester);
    clock.nowMs = 1000;
    await send(tester, startEvent());
    await send(tester, frameEvent(0, atMs: 1000, x: 0.25));
    expect(drawn(tester).snapshot.x, 0.25);

    await tick(tester, 1000);
    expect(drawn(tester).snapshot.x, 0.25, reason: '1000 ms past the newest frame it is still drawn, not extrapolated');

    await unmount(tester);
  });

  testWidgets('two frames 16 ms apart are drawn halfway at a render time halfway between them', (tester) async {
    await mount(tester);
    clock.nowMs = 1000;
    await send(tester, startEvent());
    await send(tester, frameEvent(0, atMs: 1000, x: 0.2));
    await send(tester, frameEvent(1, atMs: 1016, x: 0.6));
    expect(drawn(tester).snapshot.x, 0.2, reason: 'at the first frame: 1000 is its at');

    clock.nowMs = 1008;
    await tester.pump(const Duration(milliseconds: 8));
    // Steady arrivals: base 0, playout delay 0, so r = 1008, halfway between 1000 and 1016.
    expect(drawn(tester).snapshot.x, closeTo(0.4, 1e-9));
    expect(stats.drain().stages[LatencyStage.frameJitter], [0, 0]);

    await unmount(tester);
  });

  testWidgets('a drawn frame is measured once, however many ticks draw it', (tester) async {
    await mount(tester);
    clock.nowMs = 1000;
    await send(tester, startEvent());
    for (final (n, atMs) in [(0, 1000), (1, 1016), (2, 1032)]) {
      await send(tester, frameEvent(n, atMs: atMs, x: n / 4));
    }
    for (var i = 0; i < 20; i++) {
      await tick(tester);
    }
    expect(stats.drain().view.frames, 3, reason: '3 frames drawn over 20 ticks are 3 draws');
    expect(drawn(tester).snapshot.x, 0.5, reason: 'the third frame: 2 / 4');

    await unmount(tester);
  });

  testWidgets('touch_to_frame is the draw time minus the send time of the input the frame acks', (tester) async {
    await mount(tester, playerId: 'p1');
    clock.nowMs = 1000;
    await send(tester, startEvent());
    stats.inputSent(5, 1000);
    await send(tester, frameEvent(0, atMs: 1000, x: 0.2, roster: players));
    await send(tester, frameEvent(1, atMs: 1016, x: 0.4, acks: const {'p1': 5}, roster: players));
    expect(drawn(tester).view.playerId, 'p1');
    expect(drawn(tester).view.roster, players, reason: 'the context is the frame roster and this phone player');

    expect(stats.drain().stages[LatencyStage.touchToFrame], isNull, reason: 'no ack was drawn yet');
    await tick(tester);
    expect(stats.drain().stages[LatencyStage.touchToFrame], [16], reason: 'acked 5 was sent at 1000 and drawn at 1016');

    await unmount(tester);
  });

  testWidgets('a view end clears the screen, and later frames are ignored', (tester) async {
    await mount(tester);
    clock.nowMs = 1000;
    await send(tester, startEvent());
    await send(tester, frameEvent(0, atMs: 1000, x: 0.5));
    expect(drawn(tester).snapshot.x, 0.5);
    expect(stats.drain().view.frames, 1, reason: 'the frame drawn before the end');

    await send(tester, const ViewEnded(ViewEndMessage(reason: ViewEndReason.quit)));
    expect(find.byType(DotDraw), findsNothing);

    await tick(tester);
    await send(tester, frameEvent(1, atMs: 1016, x: 0.9));
    await tick(tester);
    expect(find.byType(DotDraw), findsNothing);
    final drained = stats.drain();
    expect(drained.view.frames, 0);
    expect(drained.stages, isEmpty);

    await unmount(tester);
  });

  testWidgets('a new views stream replaces the old one', (tester) async {
    final second = StreamController<ViewEvent>.broadcast();
    addTearDown(second.close);
    await mount(tester);
    clock.nowMs = 1000;
    await send(tester, startEvent());

    await tester.pumpWidget(underTest(stream: second.stream));
    await send(tester, frameEvent(0, atMs: 1000, x: 0.5));
    expect(find.byType(DotDraw), findsNothing, reason: 'the old stream is no longer heard');

    second.add(frameEvent(0, atMs: 1000, x: 0.7));
    await tester.pump();
    await tester.pump();
    expect(drawn(tester).snapshot.x, 0.7);

    await unmount(tester);
    stats.drain();
    second.add(frameEvent(1, atMs: 1016, x: 0.9));
    await tester.pump();
    expect(stats.drain().stages, isEmpty, reason: 'the subscription is cancelled on dispose');
  });

  testWidgets('a real arenaModule frame draws without throwing', (tester) async {
    final arena = ArenaSnapshot(
      round: 1,
      roundTimeS: 30,
      phase: ArenaPhase.playing,
      walls: const [],
      goal: const Rect.fromLTRB(0.9, 0.4, 1, 0.6),
      hazards: const [],
      players: const [ArenaPlayerView(id: 'p1', x: 0.5, y: 0.5)],
    );
    await mount(tester, registry: GameRegistry([arenaModule]));
    clock.nowMs = 1000;
    await send(
      tester,
      ViewStarted(
        ViewStartMessage(game: arenaModule.id, snapshotVersion: arenaModule.snapshotVersion, setup: arenaSetup, hz: 60),
      ),
    );
    await send(tester, ViewFrame(FrameMessage(n: 0, atMs: 1000, snapshot: arena.toJson(), roster: players), 1000));
    await tick(tester);
    expect(find.byKey(const Key('arena')), findsOneWidget);

    await unmount(tester);
  });
}
