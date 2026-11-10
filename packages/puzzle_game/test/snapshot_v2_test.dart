import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

/// Snapshot version 2 (M14 a1, design N11): the board carries its side's
/// points (`pts`), its live pop-ups with their age (`pop`) and whether the
/// round is a party night (`nt`); a phone one build older shows the update
/// text rather than a picture it would draw differently.
void main() {
  /// A board with one piece and one dot, two pop-ups and [points].
  PuzzleSnapshot board({int points = 7, bool night = true, List<PuzzlePopup> popups = const []}) => PuzzleSnapshot(
    puzzleId: 'house',
    timeLeftMs: 55000,
    phase: PuzzlePhase.playing,
    pieces: const [PieceView(x: 12.3, y: 45.6, angle: 90, state: PieceState.loose)],
    players: const [PlayerView(number: 1, x: 20, y: 30, held: null)],
    points: points,
    night: night,
    popups: popups,
  );

  final popups = [
    PuzzlePopup(side: PuzzleSide.left, place: const Offset(12.3, 45.6), amount: 2, ageMs: 0),
    PuzzlePopup(side: PuzzleSide.right, place: const Offset(100.1, 20.5), amount: 5, ageMs: 600, icon: PuzzleIcon.flag),
  ];

  test('both snapshots are version 2, and so is the module a phone asks for', () {
    expect(PuzzleSnapshot.version, 2);
    expect(MatchSnapshot.version, 2);
    expect(shapeRaceModule.snapshotVersion, 2);
  });

  test('a board round-trips with its points, its night and its pop-ups\' places and ages', () {
    final s = board(popups: popups);
    final again = PuzzleSnapshot.decode(s.encode());
    expect(again.toJson(), s.toJson());
    expect(again.points, 7);
    expect(again.night, isTrue);
    expect(again.popups, hasLength(2));
    expect(again.popups.first.place, const Offset(12.3, 45.6));
    expect(again.popups.last.amount, 5);
    expect(again.popups.last.ageMs, 600);
    expect(again.popups.last.icon, PuzzleIcon.flag);
    expect(again.popups.last.side, PuzzleSide.right);
  });

  test('a board outside a night leaves the keys out, and comes back as today\'s board', () {
    final plain = board(points: 0, night: false);
    final json = plain.toJson();
    expect(json.containsKey('pts'), isFalse);
    expect(json.containsKey('pop'), isFalse);
    expect(json.containsKey('nt'), isFalse);
    final again = PuzzleSnapshot.decode(plain.encode());
    expect(again.points, 0);
    expect(again.night, isFalse);
    expect(again.popups, isEmpty);
  });

  test('the lerp keeps the points, the night and the pop-ups as the older frame had them', () {
    final a = board(popups: popups);
    final b = board(points: 11, popups: const []);
    final between = a.lerpTo(b, 0.5);
    expect(between.points, 7);
    expect(between.night, isTrue);
    expect(between.popups, hasLength(2));
  });

  test('a match round-trips, and says each side\'s points and whether it is a night', () {
    final match = MatchSnapshot(
      boards: [
        board(points: 4, popups: popups),
        board(points: 9, night: false),
      ],
      seed: 7,
    );
    final again = MatchSnapshot.decode(match.encode());
    expect(again.toJson(), match.toJson());
    expect(again.points, {PuzzleSide.left: 4, PuzzleSide.right: 9});
    expect(again.night, isTrue, reason: 'one board of a night round makes the match one');
    expect(MatchSnapshot(boards: [board(night: false)]).night, isFalse);
  });

  testWidgets('a phone one build older shows the update text for a version 2 frame', (tester) async {
    final events = StreamController<ViewEvent>.broadcast();
    addTearDown(events.close);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FrameView(
          views: events.stream,
          registry: GameRegistry([const _VersionOneShapeRace()]),
          stats: ViewerStats(hz: 60),
          nowMs: () => 0,
          pxPerMm: 6,
        ),
      ),
    );
    expect(find.text(updateAppText), findsNothing, reason: 'nothing is drawn before a start');
    events.add(
      ViewStarted(
        ViewStartMessage(
          game: shapeRaceModule.id,
          snapshotVersion: shapeRaceModule.snapshotVersion,
          setup: const {},
          hz: 60,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(updateAppText), findsOneWidget);
  });
}

/// Shape Race as the build before a1 knows it: version 1 frames only, which a
/// version 2 frame is not.
final class _VersionOneShapeRace implements GameModule {
  const _VersionOneShapeRace();

  @override
  String get id => shapeRaceModule.id;

  @override
  int get snapshotVersion => 1;

  @override
  GameViewer createViewer(Map<String, Object?> setup) => throw StateError('a version 1 phone has no version 2 viewer');
}
