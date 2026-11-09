import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// Owner's test of m13.3 (Nov 9): carrying the boat's big sail, the worker
/// jumped about and stood off in empty space. The sail's polygon has its
/// middle (the point it is held and turned by) on its own left side, so a ray
/// cast from there to find the edge the worker stands on missed the sail on
/// that side and fell back to the shape's radius.

/// What a view first sees: P1 holding the boat's [id] at [middle], turned
/// [angle], its dot [grab] from the middle.
WorkerPose holding(Puzzle boat, String id, Offset middle, double angle, Offset grab) {
  final index = boat.pieces.indexWhere((p) => p.id == id);
  return (WorkerMoments(boat)..observe(
        MatchSnapshot(
          boards: [
            PuzzleSnapshot(
              puzzleId: boat.id,
              timeLeftMs: 60000,
              phase: PuzzlePhase.playing,
              pieces: [
                for (var i = 0; i < boat.pieces.length; i++)
                  i == index
                      ? PieceView(x: middle.dx, y: middle.dy, angle: angle, state: PieceState.held, holders: const [1])
                      : const PieceView(x: 10, y: 10, angle: 0, state: PieceState.tray),
              ],
              players: [PlayerView(number: 1, x: middle.dx + grab.dx, y: middle.dy + grab.dy, held: index)],
            ),
          ],
        ),
        1000,
      ))
      .poseOf(0, 1, 1000);
}

void main() {
  final boat = load('boat');
  const reach = PuzzleGame.pickupReach;
  const middle = Offset(60, 45);

  for (final id in ['sail', 'flag']) {
    test('held from its left, the $id has the worker on its outline at every turn, moving smoothly', () {
      final shape = boat.pieces.firstWhere((p) => p.id == id).shape;
      Offset? before;
      for (var angle = 0.0; angle < 360; angle += 5) {
        final pose = holding(boat, id, middle, angle, const Offset(-4, 0));
        final where = '$id at $angle°';
        // It stands against the piece, as a body its width slid in along its
        // side meets it: within that width of the outline, and outside it.
        expect(shape.distanceTo(pose.at, middle, angle), lessThanOrEqualTo(reach), reason: '$where: against it');
        expect(shape.contains(pose.at + pose.away * 0.01, middle, angle), isFalse, reason: '$where: outside it');
        // A 5° turn moves it a little: less than the body's radius, never
        // across the piece or off into space.
        if (before != null) expect((pose.at - before).distance, lessThan(reach), reason: '$where: no jump');
        before = pose.at;
      }
    });
  }
}
