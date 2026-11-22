import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';

import 'support/fake_view.dart';

/// The characters a frame carries reach the viewer as `ViewContext.characters`
/// (M16 identity): a frame's `chars` keyed by player ID, and an empty map when
/// the host sent none.

/// The one character this file's frames carry: player p1 chose the fifth
/// colour with a crown.
const chosen = PlayerCharacter(colourSlot: 5, accessory: PlayerAccessory.crown);

/// The roster every frame here carries.
const players = {'p1': (number: 1, name: 'Ada')};

/// The phone's clock in ms: the test moves it, and the view draws for it.
final class Clock {
  int nowMs = 0;
}

ViewFrame frame(int n, {required int atMs, Map<String, PlayerCharacter> characters = const {}}) => ViewFrame(
  FrameMessage(
    n: n,
    atMs: atMs,
    snapshot: {'v': DotSnapshot.version, 'x': 0.5},
    roster: players,
    characters: characters,
  ),
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

  /// Mounts a [FrameView] on the test's stream, clock and stats.
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: FrameView(
        views: events.stream,
        registry: GameRegistry([const DotModule()]),
        stats: stats,
        nowMs: () => clock.nowMs,
        playerId: 'p1',
        pxPerMm: 6,
      ),
    ),
  );

  /// Delivers [event] to the view and draws the frame that follows it.
  Future<void> send(WidgetTester tester, ViewEvent event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    clock.nowMs = 1000;
    await send(
      tester,
      const ViewStarted(
        ViewStartMessage(game: 'dot', snapshotVersion: DotSnapshot.version, setup: {'start': 0}, hz: 60),
      ),
    );
  }

  testWidgets("a frame's chosen characters reach the viewer, by player ID", (tester) async {
    await mount(tester);
    await start(tester);
    await send(tester, frame(0, atMs: 1000, characters: {'p1': chosen}));

    final view = tester.widget<DotDraw>(find.byType(DotDraw)).view;
    expect(view.characters, {'p1': chosen});
    expect(view.roster, players, reason: 'the roster still comes with them');
  });

  testWidgets('a frame with no characters gives the viewer an empty map', (tester) async {
    await mount(tester);
    await start(tester);
    await send(tester, frame(0, atMs: 1000));

    final view = tester.widget<DotDraw>(find.byType(DotDraw)).view;
    expect(view.characters, isEmpty, reason: 'a missing player wears the number default, so nothing is invented');
  });
}
